// lib/service/client_auth_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientSession {
  final String  id;
  final String? projetId;
  final String  clientNom;
  final String  clientEmail;
  final bool    passwordChanged;
  final String? telephone;
  final String? clientsId; // clients.id dans la table clients

  const ClientSession({
    required this.id,
    this.projetId,
    required this.clientNom,
    required this.clientEmail,
    this.passwordChanged = false,
    this.telephone,
    this.clientsId,
  });

  Map<String, dynamic> toJson() => {
    'id':               id,
    'projet_id':        projetId,
    'client_nom':       clientNom,
    'client_email':     clientEmail,
    'password_changed': passwordChanged,
    'telephone':        telephone,
    'clients_id':       clientsId,
  };

  factory ClientSession.fromJson(Map<String, dynamic> j) => ClientSession(
    id:              j['id']               as String,
    projetId:        j['projet_id']        as String?,
    clientNom:       j['client_nom']       as String,
    clientEmail:     j['client_email']     as String,
    passwordChanged: j['password_changed'] as bool? ?? false,
    telephone:       j['telephone']        as String?,
    clientsId:       j['clients_id']       as String?,
  );
}

class ClientAuthService {
  static final _supa = Supabase.instance.client;
  static const _sessionKey = 'client_session';

  static Future<ClientSession> login(String email, String password) async {
    final trimEmail    = email.trim().toLowerCase();
    final trimPassword = password.trim();

    // 1. Récupère tous les accès via RPC SECURITY DEFINER (contourne le RLS
    //    qui masquerait password_raw pour les utilisateurs anonymes)
    final List<dynamic> rows;
    try {
      rows = await _supa
          .rpc('get_client_login_rows', params: {'p_email': trimEmail});
    } catch (e) {
      throw Exception('Erreur de connexion. Vérifiez votre connexion internet.');
    }

    if (rows.isEmpty) {
      throw Exception('Aucun compte trouvé pour cet email.');
    }

    // 2. Cherche une ligne avec password_raw défini (connexions après 1er changement)
    final authCandidates = rows.where((r) =>
        ((r['password_raw'] as String?) ?? '').isNotEmpty).toList();

    // Ligne active à utiliser pour la session (avec ou sans password_raw)
    final activeRows = rows.where((r) => (r['actif'] as bool?) ?? false).toList();
    if (activeRows.isEmpty) {
      throw Exception('Votre compte est désactivé. Contactez votre architecte.');
    }

    late Map<String, dynamic> row;
    bool authenticated = false;

    if (authCandidates.isNotEmpty) {
      // Cas normal : password_raw présent → vérification directe
      row = Map<String, dynamic>.from(authCandidates.first as Map);
      final stored = (row['password_raw'] as String?) ?? '';
      authenticated = stored == trimPassword;
    }

    // Fallback Supabase Auth : première connexion (password_raw non encore défini)
    // ou si la vérification directe a échoué
    if (!authenticated) {
      try {
        await _supa.auth.signInWithPassword(email: trimEmail, password: trimPassword);
        authenticated = true;
        // Utilise la première ligne active (password_raw sera défini après changement)
        if (authCandidates.isEmpty) {
          row = Map<String, dynamic>.from(activeRows.first as Map);
          row['password_changed'] = false; // Force l'écran de changement de mot de passe
        }
      } catch (_) {}
    }

    if (!authenticated) {
      throw Exception('Mot de passe incorrect.');
    }

    // 4. Vérifie acces_portail + récupère clients.id pour les requêtes projets
    bool accesPortail = true;
    String? clientsId;
    try {
      final clientRows = await _supa
          .from('clients')
          .select('id, acces_portail')
          .ilike('email', trimEmail)
          .limit(1);
      if ((clientRows as List).isNotEmpty) {
        final cr = clientRows.first as Map;
        accesPortail = cr['acces_portail'] as bool? ?? true;
        clientsId    = cr['id'] as String?;
      }
    } catch (_) {}

    if (!accesPortail) {
      throw Exception('Votre accès au portail est désactivé. Contactez votre architecte.');
    }

    // 5. Met à jour last_login
    await _supa
        .from('client_portal_access')
        .update({'last_login': DateTime.now().toIso8601String()})
        .eq('id', row['id']);

    final session = ClientSession.fromJson({...row, 'clients_id': clientsId});
    await saveSession(session);
    return session;
  }

  static Future<void> saveSession(ClientSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  static Future<ClientSession?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null) return null;

      final saved = ClientSession.fromJson(jsonDecode(raw));

      // Si la session locale n'a pas de projet_id, on relit la DB
      if (saved.projetId == null) {
        final row = await _supa
            .from('client_portal_access')
            .select('projet_id')
            .eq('id', saved.id)
            .maybeSingle();
        final projetId = row?['projet_id'] as String?;
        if (projetId != null) {
          final updated = ClientSession(
            id:              saved.id,
            projetId:        projetId,
            clientNom:       saved.clientNom,
            clientEmail:     saved.clientEmail,
            passwordChanged: saved.passwordChanged,
            telephone:       saved.telephone,
          );
          await saveSession(updated);
          return updated;
        }
      }

      return saved;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    try { await _supa.auth.signOut(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  static String hashPassword(String password) => password;
}