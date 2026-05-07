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

  /// Documents d'un projet spécifique
  static Future<List<Map<String, dynamic>>> getDocumentsForProjet(String projetId) async {
    // RPC SECURITY DEFINER — contourne le RLS pour les clients anonymes
    try {
      final rows = await _supa.rpc(
        'get_project_documents',
        params: {'p_projet_id': projetId},
      );
      final result = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      if (result.isNotEmpty) return result;
    } catch (_) {}

    // Fallback direct (fonctionne si la table a une politique de lecture anon)
    try {
      final res = await _supa
          .from('documents')
          .select()
          .eq('projet_id', projetId)
          .order('uploaded_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
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

  // ── Documents de tous les projets du client (par email) ─────────────────
  static Future<List<Map<String, dynamic>>> getRecentDocuments(String clientEmail) async {
    // 1. RPC get_client_documents (SECURITY DEFINER)
    try {
      final rows = await _supa.rpc(
        'get_client_documents',
        params: {'p_client_email': clientEmail.trim().toLowerCase()},
      );
      final result = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      if (result.isNotEmpty) return result;
    } catch (_) {}

    // 2. Résout les projets du client
    final projets = await getProjetsForClient(clientEmail);
    if (projets.isEmpty) return [];
    final ids = projets
        .map((p) => p['id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();
    if (ids.isEmpty) return [];

    // 3. Requête directe (fonctionne si la table a une politique anon)
    try {
      final rows = await _supa
          .from('documents')
          .select()
          .inFilter('projet_id', ids)
          .order('uploaded_at', ascending: false)
          .limit(50);
      final result = List<Map<String, dynamic>>.from(rows as List);
      if (result.isNotEmpty) return result;
    } catch (_) {}

    // 4. Fallback : get_project_documents RPC (SECURITY DEFINER) par projet
    final allDocs = <Map<String, dynamic>>[];
    for (final id in ids.take(10)) {
      final docs = await getDocumentsForProjet(id);
      allDocs.addAll(docs);
    }
    allDocs.sort((a, b) =>
        ((b['uploaded_at'] as String?) ?? '')
            .compareTo((a['uploaded_at'] as String?) ?? ''));
    return allDocs.take(50).toList();
  }

  // ── Commentaires d'un projet via RPC (bypasse le RLS) ───────────────────
  static Future<List<Map<String, dynamic>>> getRecentMessages(String projetId, {int limit = 50}) async {
    // 1. RPC SECURITY DEFINER
    try {
      final rows = await _supa.rpc('get_project_commentaires', params: {
        'p_projet_id': projetId,
        'p_limit':     limit,
      });
      final result = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      if (result.isNotEmpty) return result;
    } catch (_) {}

    // 2. Fallback direct (fonctionne si la table a une politique anon)
    try {
      final rows = await _supa
          .from('commentaires')
          .select()
          .eq('projet_id', projetId)
          .order('created_at', ascending: true)
          .limit(limit);
      return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Liste tous les projets accessibles par un client ─────────────────────
  static Future<List<Map<String, dynamic>>> getProjetsForClient(String clientEmail) async {
    final trimEmail = clientEmail.trim().toLowerCase();

    // RPC et fallback en parallèle — fusionne les résultats par ID.
    // Nécessaire car la RPC peut manquer des projets liés seulement par texte,
    // et le fallback peut manquer des projets si la RPC échoue.
    final results = await Future.wait([
      _supa
          .rpc('get_client_projets', params: {'p_email': trimEmail})
          .then((r) => (r as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList())
          .catchError((_) => <Map<String, dynamic>>[]),
      _getProjetsDirectFallback(trimEmail),
    ]);

    final seenIds = <String>{};
    final merged  = <Map<String, dynamic>>[];
    for (final proj in [...results[0], ...results[1]]) {
      final id = proj['id'] as String?;
      if (id != null && seenIds.add(id)) merged.add(proj);
    }
    return merged;
  }

  static Future<List<Map<String, dynamic>>> _getProjetsDirectFallback(String trimEmail) async {
    try {
      final accesses = await _supa
          .from('client_portal_access')
          .select('id, projet_id, client_nom')
          .eq('client_email', trimEmail)
          .eq('actif', true);

      final accessList = accesses as List;
      final linkedIds  = <String>{};

      // Niveau 1 : projet_id direct (FK)
      for (final access in accessList) {
        final pid = access['projet_id'] as String?;
        if (pid != null) linkedIds.add(pid);
      }

      // Niveau 2 : clients.email → projets.client_id
      linkedIds.addAll(await _findAllProjetsByClientTable(trimEmail));

      // Niveau 3 : champ texte projets.client
      final nom = accessList.isNotEmpty
          ? (accessList.first['client_nom'] as String?) ?? ''
          : '';
      final textIds = await _findAllProjetsByText(email: trimEmail, nom: nom);
      linkedIds.addAll(textIds);

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

  /// Persiste via RPC (SECURITY DEFINER) les projets trouvés par texte comme
  /// liens FK explicites. À appeler AVANT un changement de nom.
  /// Requiert la fonction SQL `consolidate_client_project_links` dans Supabase.
  static Future<void> consolidateProjectLinks({
    required String clientEmail,
    required String clientNom,
  }) async {
    try {
      await _supa.rpc('consolidate_client_project_links', params: {
        'p_email': clientEmail,
        'p_nom':   clientNom,
      });
    } catch (_) {}
  }

  // clients.email → clients.id → projets.client_id
  static Future<Set<String>> _findAllProjetsByClientTable(String email) async {
    try {
      final clientRows = await _supa
          .from('clients').select('id').eq('email', email);
      if ((clientRows as List).isEmpty) return {};
      final clientIds = (clientRows as List).map((r) => r['id'] as String).toList();
      final projetRows = await _supa
          .from('projets').select('id').inFilter('client_id', clientIds);
      return (projetRows as List).map((r) => r['id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  // Champ texte projets.client — retourne tous les projets correspondants
  static Future<Set<String>> _findAllProjetsByText({required String email, required String nom}) async {
    final ids = <String>{};
    try {
      if (email.isNotEmpty) {
        final r = await _supa.from('projets').select('id')
            .ilike('client', '%$email%').eq('portail_client', true);
        ids.addAll((r as List).map((e) => e['id'] as String));
      }
      if (nom.isNotEmpty) {
        final r = await _supa.from('projets').select('id')
            .ilike('client', '%$nom%').eq('portail_client', true);
        ids.addAll((r as List).map((e) => e['id'] as String));
      }
    } catch (_) {}
    return ids;
  }
}