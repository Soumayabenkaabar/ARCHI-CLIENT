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

  const ClientSession({
    required this.id,
    this.projetId,
    required this.clientNom,
    required this.clientEmail,
    this.passwordChanged = false,
  });

  Map<String, dynamic> toJson() => {
    'id':               id,
    'projet_id':        projetId,
    'client_nom':       clientNom,
    'client_email':     clientEmail,
    'password_changed': passwordChanged,
  };

  factory ClientSession.fromJson(Map<String, dynamic> j) => ClientSession(
    id:              j['id']               as String,
    projetId:        j['projet_id']        as String?,
    clientNom:       j['client_nom']       as String,
    clientEmail:     j['client_email']     as String,
    passwordChanged: j['password_changed'] as bool? ?? false,
  );
}

class ClientAuthService {
  static final _supa = Supabase.instance.client;
  static const _sessionKey = 'client_session';

  static Future<ClientSession> login(String email, String password) async {
    final trimEmail    = email.trim().toLowerCase();
    final trimPassword = password.trim();

    // 1. Récupère l'accès client (sans filtre actif pour distinguer les cas)
    final List<dynamic> rows;
    try {
      rows = await _supa
          .from('client_portal_access')
          .select('id, projet_id, client_nom, client_email, actif, password_changed, password_raw')
          .eq('client_email', trimEmail)
          .order('created_at', ascending: false)
          .limit(1);
    } catch (e) {
        throw Exception('Erreur de connexion. Vérifiez votre connexion internet.');
    }

    if (rows.isEmpty) {
      throw Exception('Aucun compte trouvé pour cet email.');
    }

    final row    = Map<String, dynamic>.from(rows.first as Map);
    final actif  = row['actif'] as bool? ?? false;
    final stored = (row['password_raw'] as String?) ?? '';

    if (!actif) {
      throw Exception('Votre compte est désactivé. Contactez votre architecte.');
    }

    // 2a. Vérification directe password_raw
    bool authenticated = stored.isNotEmpty && stored == trimPassword;

    // 2b. Fallback Supabase Auth (clients créés via Auth ou ancienne méthode)
    if (!authenticated) {
      try {
        await _supa.auth.signInWithPassword(email: trimEmail, password: trimPassword);
        authenticated = true;
      } catch (_) {}
    }

    if (!authenticated) {
      if (stored.isEmpty) {
        throw Exception('Mot de passe non configuré. Demandez à votre architecte de réinitialiser votre accès.');
      }
      throw Exception('Mot de passe incorrect.');
    }

    // 3. Si projet_id est null → cherche dans projets
    if (row['projet_id'] == null) {
      final projetId = await _findProjetIdForClient(
        email: trimEmail,
        nom:   row['client_nom'] as String,
      );
      if (projetId != null) {
        await _supa
            .from('client_portal_access')
            .update({'projet_id': projetId})
            .eq('id', row['id']);
        row['projet_id'] = projetId;
      }
    }

    // 4. Met à jour last_login
    await _supa
        .from('client_portal_access')
        .update({'last_login': DateTime.now().toIso8601String()})
        .eq('id', row['id']);

    final session = ClientSession.fromJson(row);
    await saveSession(session);
    return session;
  }

  /// Cherche un projet dont portail_client=true et dont le champ `client`
  /// correspond à l'email OU au nom du client.
  static Future<String?> _findProjetIdForClient({
    required String email,
    required String nom,
  }) async {
    // Tentative 1 : match sur l'email (champ texte `client`)
    final byEmail = await _supa
        .from('projets')
        .select('id')
        .ilike('client', email)
        .eq('portail_client', true)
        .limit(1);

    if ((byEmail as List).isNotEmpty) {
      return byEmail.first['id'] as String;
    }

    // Tentative 2 : match sur le nom du client
    final byNom = await _supa
        .from('projets')
        .select('id')
        .ilike('client', nom)
        .eq('portail_client', true)
        .limit(1);

    if ((byNom as List).isNotEmpty) {
      return byNom.first['id'] as String;
    }

    return null;
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

      // Si la session sauvegardée n'a pas de projet_id, on re-tente le lookup
      if (saved.projetId == null) {
        final projetId = await _findProjetIdForClient(
          email: saved.clientEmail,
          nom: saved.clientNom,
        );
        if (projetId != null) {
          // Met à jour en DB
          await _supa
              .from('client_portal_access')
              .update({'projet_id': projetId})
              .eq('id', saved.id);

          // Met à jour la session locale
          final updated = ClientSession(
            id:              saved.id,
            projetId:        projetId,
            clientNom:       saved.clientNom,
            clientEmail:     saved.clientEmail,
            passwordChanged: saved.passwordChanged,
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