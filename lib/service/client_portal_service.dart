// lib/service/client_portal_service.dart
// Utilisé côté ARCHITECTE pour créer/gérer les accès clients
import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_service.dart';

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

  // ── Génère un mot de passe aléatoire ────────────────────────────────────
  static String _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // ── Crée un accès portail et envoie les identifiants par email ────────────
  static Future<ClientAccess> createAccess({
    required String projetId,
    required String projetTitre,
    required String clientNom,
    required String clientEmail,
    required String architecteNom,
  }) async {
    final trimEmail = clientEmail.trim().toLowerCase();
    final password  = _generatePassword();

    // Vérifie si un accès existe déjà pour cet email sur ce projet
    final existing = await _supa
        .from('client_portal_access')
        .select('id')
        .eq('client_email', trimEmail)
        .eq('projet_id', projetId)
        .limit(1);

    late ClientAccess access;

    if (existing.isNotEmpty) {
      // Réactive et réinitialise le mot de passe
      await _supa
          .from('client_portal_access')
          .update({
            'actif':            true,
            'password_raw':     password,
            'password_changed': false,
          })
          .eq('id', existing.first['id']);

      final row = await _supa
          .from('client_portal_access')
          .select()
          .eq('id', existing.first['id'])
          .single();

      access = ClientAccess.fromJson(row);
    } else {
      final row = await _supa
          .from('client_portal_access')
          .insert({
            'projet_id':        projetId,
            'client_nom':       clientNom,
            'client_email':     trimEmail,
            'password_hash':    '',
            'password_raw':     password,
            'password_changed': false,
          })
          .select()
          .single();

      access = ClientAccess.fromJson(row);
    }

    // Envoie l'email avec les identifiants
    await EmailService.sendClientPassword(
      toEmail:       trimEmail,
      clientNom:     clientNom,
      motDePasse:    password,
      projetTitre:   projetTitre,
      architecteNom: architecteNom,
    );

    return access;
  }

  // ── Réinitialise le mot de passe et renvoie un email ─────────────────────
  static Future<void> resetPassword({
    required String accessId,
    required String clientEmail,
    required String clientNom,
    required String projetTitre,
    required String architecteNom,
  }) async {
    final password = _generatePassword();

    await _supa
        .from('client_portal_access')
        .update({
          'password_raw':     password,
          'password_changed': false,
        })
        .eq('id', accessId);

    await EmailService.sendClientPassword(
      toEmail:       clientEmail,
      clientNom:     clientNom,
      motDePasse:    password,
      projetTitre:   projetTitre,
      architecteNom: architecteNom,
    );
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

  /// Actualités du chantier pour un projet
  static Future<List<Map<String, dynamic>>> getActualitesChantier(String projetId) async {
    final res = await Supabase.instance.client
        .from('actualites_chantier')
        .select()
        .eq('projet_id', projetId)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(res as List);
  }
 
  /// Photos du chantier pour un projet
  static Future<List<Map<String, dynamic>>> getPhotosChantier(String projetId) async {
    final res = await Supabase.instance.client
        .from('photos_chantier')
        .select()
        .eq('projet_id', projetId)
        .order('uploaded_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(res as List);
  }
 
  /// Upload d'un fichier dans Supabase Storage (essaie plusieurs buckets)
  static Future<String> uploadCommentFile({
    required String projetId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '$projetId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    for (final bucket in ['commentaires', 'documents', 'public']) {
      try {
        await _supa.storage.from(bucket).uploadBinary(
          path, bytes,
          fileOptions: const FileOptions(upsert: true),
        );
        return _supa.storage.from(bucket).getPublicUrl(path);
      } catch (_) {
        continue;
      }
    }
    throw Exception('Aucun bucket Storage disponible. Créez le bucket "commentaires" dans Supabase.');
  }

  /// Ajouter un commentaire (avec ou sans fichier joint)
  /// Le fichier est encodé dans contenu via ||ATTACH||url||nom (même format que l'app architecte)
  static Future<void> addComment({
    required String projetId,
    required String contenu,
    String auteur = 'Client',
    String role   = 'client',
    String? fichierUrl,
    String? fichierNom,
  }) async {
    String finalContenu = contenu;
    if (fichierUrl != null && fichierUrl.isNotEmpty) {
      final nom = (fichierNom?.isNotEmpty ?? false) ? fichierNom! : fichierUrl.split('/').last.split('?').first;
      final attachTag = '||ATTACH||$fichierUrl||$nom';
      finalContenu = contenu.isNotEmpty ? '$contenu\n$attachTag' : attachTag;
    }
    await _supa.rpc('add_client_commentaire', params: {
      'p_projet_id': projetId,
      'p_contenu':   finalContenu,
      'p_auteur':    auteur,
      'p_role':      role,
    });
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

  // ── Récupère un projet par son ID (pour le portail client) ────────────────
  static Future<Map<String, dynamic>?> getProjetById(String projetId) async {
    final rows = await _supa
        .from('projets')
        .select()
        .eq('id', projetId)
        .limit(1);

    if ((rows as List).isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  // ── Documents de tous les projets du client (par email, contourne le RLS) ─
  static Future<List<Map<String, dynamic>>> getRecentDocuments(String clientEmail) async {
    try {
      final rows = await _supa.rpc(
        'get_client_documents',
        params: {'p_client_email': clientEmail.trim().toLowerCase()},
      );
      return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[ClientPortalService] getRecentDocuments error: $e');
      rethrow;
    }
  }

  // ── Commentaires d'un projet via RPC (bypasse le RLS) ───────────────────
  static Future<List<Map<String, dynamic>>> getRecentMessages(String projetId, {int limit = 50}) async {
    try {
      final rows = await _supa.rpc('get_project_commentaires', params: {
        'p_projet_id': projetId,
        'p_limit':     limit,
      });
      return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (_) {
      // Fallback direct
      final rows = await _supa
          .from('commentaires')
          .select()
          .eq('projet_id', projetId)
          .order('created_at', ascending: true)
          .limit(limit);
      return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    }
  }

  // ── Liste tous les projets accessibles par un client ─────────────────────
  // Utilise la fonction RPC get_client_projets (SECURITY DEFINER) pour contourner le RLS
  static Future<List<Map<String, dynamic>>> getProjetsForClient(String clientEmail) async {
    final trimEmail = clientEmail.trim().toLowerCase();
    try {
      final rows = await _supa.rpc(
        'get_client_projets',
        params: {'p_email': trimEmail},
      );
      return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (_) {
      return _getProjetsDirectFallback(trimEmail);
    }
  }

  // Fallback direct si la fonction RPC n'est pas encore créée
  static Future<List<Map<String, dynamic>>> _getProjetsDirectFallback(String trimEmail) async {
    try {
      final accesses = await _supa
          .from('client_portal_access')
          .select('id, projet_id, client_nom')
          .eq('client_email', trimEmail)
          .eq('actif', true);

      final accessList = accesses as List;
      final linkedIds  = <String>{};

      for (final access in accessList) {
        final pid = access['projet_id'] as String?;
        if (pid != null) { linkedIds.add(pid); continue; }

        final nom      = (access['client_nom'] as String?) ?? '';
        final accessId = access['id'] as String;
        String? found;
        try { found = await _findProjetId(email: trimEmail, nom: nom); } catch (_) {}
        if (found != null) {
          linkedIds.add(found);
          _supa.from('client_portal_access')
              .update({'projet_id': found}).eq('id', accessId)
              .then((_) {}).catchError((_) {});
        }
      }

      if (linkedIds.isEmpty) return [];

      final rows = await _supa
          .from('projets')
          .select()
          .inFilter('id', linkedIds.toList())
          .order('created_at', ascending: false);
      return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> _findProjetId({required String email, required String nom}) async {
    final byEmail = await _supa.from('projets').select('id').ilike('client', '%$email%').limit(1);
    if ((byEmail as List).isNotEmpty) return byEmail.first['id'] as String;
    if (nom.isEmpty) return null;
    final byClient = await _supa.from('projets').select('id').ilike('client', '%$nom%').limit(1);
    if ((byClient as List).isNotEmpty) return byClient.first['id'] as String;
    final byTitre = await _supa.from('projets').select('id').ilike('titre', '%$nom%').limit(1);
    if ((byTitre as List).isNotEmpty) return byTitre.first['id'] as String;
    return null;
  }
}