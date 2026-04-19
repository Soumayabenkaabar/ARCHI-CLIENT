// lib/service/client_portal_service.dart
// Utilisé côté ARCHITECTE pour créer/gérer les accès clients
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientAccess {
  final String id;
  final String projetId;
  final String clientNom;
  final String clientEmail;
  final bool actif;
  final String createdAt;
  final String? lastLogin;

  const ClientAccess({
    required this.id,
    required this.projetId,
    required this.clientNom,
    required this.clientEmail,
    required this.actif,
    required this.createdAt,
    this.lastLogin,
  });

  factory ClientAccess.fromJson(Map<String, dynamic> j) => ClientAccess(
    id: j['id'],
    projetId: j['projet_id'],
    clientNom: j['client_nom'],
    clientEmail: j['client_email'],
    actif: j['actif'] ?? true,
    createdAt: j['created_at'] ?? '',
    lastLogin: j['last_login'],
  );
}

class ClientPortalService {
  static final _supa = Supabase.instance.client;

  // ── Crée un accès portail ─────────────────────────────────────────────────
  // Le mot de passe est géré par Supabase Auth + Edge Function send-welcome-email
  static Future<ClientAccess> createAccess({
    required String projetId,
    required String clientNom,
    required String clientEmail,
  }) async {
    final trimEmail = clientEmail.trim().toLowerCase();

    // Vérifie si un accès existe déjà pour cet email sur ce projet
    final existing = await _supa
        .from('client_portal_access')
        .select('id')
        .eq('client_email', trimEmail)
        .eq('projet_id', projetId)
        .limit(1);

    if (existing.isNotEmpty) {
      // Réactive si désactivé
      await _supa
          .from('client_portal_access')
          .update({'actif': true})
          .eq('id', existing.first['id']);

      final row = await _supa
          .from('client_portal_access')
          .select()
          .eq('id', existing.first['id'])
          .single();

      return ClientAccess.fromJson(row);
    }

    // Insère le nouvel accès — password_hash géré par Supabase Auth
    final row = await _supa
        .from('client_portal_access')
        .insert({
          'projet_id':    projetId,
          'client_nom':   clientNom,
          'client_email': trimEmail,
          'password_hash': '', // champ requis en DB, vide car Auth gère
        })
        .select()
        .single();

    return ClientAccess.fromJson(row);
  }

  // ── Active / Désactive l'accès ───────────────────────────────────────────
  static Future<void> toggleAccess(String accessId, bool actif) async {
    await _supa
        .from('client_portal_access')
        .update({'actif': actif})
        .eq('id', accessId);
  }

  // ── Supprime l'accès ─────────────────────────────────────────────────────
  static Future<void> deleteAccess(String accessId) async {
    await _supa
        .from('client_portal_access')
        .delete()
        .eq('id', accessId);
  }

  // ── Liste les accès d'un projet ──────────────────────────────────────────
  static Future<List<ClientAccess>> getAccessList(String projetId) async {
    final rows = await _supa
        .from('client_portal_access')
        .select()
        .eq('projet_id', projetId)
        .order('created_at', ascending: false);

    return rows.map((r) => ClientAccess.fromJson(r)).toList();
  }

  // ── Liste tous les accès (tous projets) ──────────────────────────────────
  static Future<List<ClientAccess>> getAllAccess() async {
    final rows = await _supa
        .from('client_portal_access')
        .select()
        .order('created_at', ascending: false);

    return rows.map((r) => ClientAccess.fromJson(r)).toList();
  }
}