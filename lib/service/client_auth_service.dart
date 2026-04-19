// lib/service/client_auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientSession {
  final String id;
  final String projetId;
  final String clientNom;
  final String clientEmail;

  const ClientSession({
    required this.id,
    required this.projetId,
    required this.clientNom,
    required this.clientEmail,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'projet_id': projetId,
    'client_nom': clientNom,
    'client_email': clientEmail,
  };

  factory ClientSession.fromJson(Map<String, dynamic> j) => ClientSession(
    id: j['id'],
    projetId: j['projet_id'],
    clientNom: j['client_nom'],
    clientEmail: j['client_email'],
  );
}

class ClientAuthService {
  static final _supa = Supabase.instance.client;
  static const _sessionKey = 'client_session';

  // ── Connexion via Supabase Auth ───────────────────────────────────────────
  static Future<ClientSession> login(String email, String password) async {
    final trimEmail = email.trim().toLowerCase();

    // 1. Connexion Supabase Auth
    late AuthResponse authResponse;
    try {
      authResponse = await _supa.auth.signInWithPassword(
        email: trimEmail,
        password: password,
      );
    } catch (e) {
      throw Exception('Email ou mot de passe incorrect.');
    }

    if (authResponse.user == null) {
      throw Exception('Email ou mot de passe incorrect.');
    }

    // 2. Récupère le projet lié dans client_portal_access
    final rows = await _supa
        .from('client_portal_access')
        .select('id, projet_id, client_nom, client_email, actif')
        .eq('client_email', trimEmail)
        .eq('actif', true)
        .limit(1);

    if (rows.isEmpty) {
      await _supa.auth.signOut();
      throw Exception('Aucun accès projet trouvé pour cet email.');
    }

    final row = rows.first;

    // 3. Met à jour last_login
    await _supa
        .from('client_portal_access')
        .update({'last_login': DateTime.now().toIso8601String()})
        .eq('id', row['id']);

    final session = ClientSession(
      id: row['id'],
      projetId: row['projet_id'],
      clientNom: row['client_nom'],
      clientEmail: row['client_email'],
    );

    // 4. Persiste la session localement
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));

    return session;
  }

  // ── Session persistée ─────────────────────────────────────────────────────
  static Future<ClientSession?> getSession() async {
    try {
      // Vérifie d'abord que Supabase Auth est toujours connecté
      final user = _supa.auth.currentUser;
      if (user == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null) return null;
      return ClientSession.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // ── Déconnexion ───────────────────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      await _supa.auth.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // ── Garde pour compatibilité ──────────────────────────────────────────────
  static String hashPassword(String password) => password;
}