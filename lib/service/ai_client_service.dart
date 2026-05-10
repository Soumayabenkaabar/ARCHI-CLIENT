// lib/service/ai_client_service.dart
// Utilise la même Edge Function Supabase "ai-proxy" que l'app architecte.
// La clé Groq est stockée côté serveur dans les variables d'environnement Supabase.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'client_portal_service.dart';

class AiClientService {
  static const _modelFast = 'claude-haiku-4-5-20251001'; // mappé → llama-3.1-8b-instant
  static final _supa = Supabase.instance.client;

  static const _hors_domaine =
      'Désolé, je suis spécialisé uniquement dans la gestion des projets '
      'et services de la plateforme.';

  // ── Appel via Edge Function ───────────────────────────────────────────────
  static Future<String> _call(
    String system,
    String prompt, {
    int maxTokens = 512,
  }) async {
    try {
      final res = await _supa.functions
          .invoke(
            'ai-proxy',
            body: {
              'model':      _modelFast,
              'max_tokens': maxTokens,
              'system':     system,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            },
          )
          .timeout(const Duration(seconds: 60));

      final data = res.data;
      if (data == null) return 'Service temporairement indisponible.';
      if (data['error'] != null) return 'Service temporairement indisponible.';

      return ((data['content'] as List).first['text'] as String).trim();
    } catch (_) {
      return 'Impossible de joindre l\'assistant pour le moment.';
    }
  }

  // ── Contexte d'un seul projet (avec ses données DB) ─────────────────────
  static Future<void> _appendProjetContext(
      Map<String, dynamic> projet, StringBuffer ctx, int index) async {
    final projetId   = projet['id']?.toString() ?? '';
    final titre      = projet['titre'] ?? projet['name'] ?? 'Projet';
    final avancement = projet['avancement'] ?? projet['progress'] ?? 0;
    final statut     = projet['statut'] ?? 'en_cours';
    final budget     = projet['budget_total'] ?? projet['budget'];
    final budgetDep  = projet['budget_depense'];
    final dateDebut  = projet['date_debut'];
    final dateFin    = projet['date_fin'] ?? projet['date_livraison'];
    final localisa   = projet['localisation'];
    final client     = projet['client'];

    ctx.writeln('\n=== PROJET $index : $titre ===');
    ctx.writeln('Avancement : $avancement%');
    ctx.writeln('Statut : $statut');
    if (client != null)    ctx.writeln('Client : $client');
    if (localisa != null)  ctx.writeln('Localisation : $localisa');
    if (budget != null)    ctx.writeln('Budget total : $budget DT');
    if (budgetDep != null) ctx.writeln('Budget dépensé : $budgetDep DT');
    if (dateDebut != null) ctx.writeln('Date début : $dateDebut');
    if (dateFin != null)   ctx.writeln('Livraison prévue : $dateFin');

    if (projetId.isEmpty) return;

    // Actualités
    try {
      final rows = await ClientPortalService.getActualitesChantier(projetId);
      if (rows.isNotEmpty) {
        ctx.writeln('Actualités (${rows.length}) :');
        for (final a in rows.take(4)) {
          final date = (a['created_at'] as String?)?.substring(0, 10) ?? '';
          ctx.writeln('  • [${a['type']}] ${a['contenu']} — ${a['auteur']} ($date)');
        }
      }
    } catch (_) {}

    // Documents
    try {
      final rows = await ClientPortalService.getDocumentsForProjet(projetId);
      if (rows.isNotEmpty) {
        ctx.writeln('Documents (${rows.length}) :');
        for (final d in rows.take(4)) {
          final date = (d['uploaded_at'] as String?)?.substring(0, 10) ?? '';
          ctx.writeln('  • ${d['nom']} (${d['type']}) — $date');
        }
      }
    } catch (_) {}

    // Messages récents
    try {
      final rows = await ClientPortalService.getRecentMessages(projetId, limit: 6);
      if (rows.isNotEmpty) {
        ctx.writeln('Messages récents :');
        for (final m in rows.take(4)) {
          final date    = (m['created_at'] as String?)?.substring(0, 10) ?? '';
          final contenu = (m['contenu'] as String?) ?? '';
          final preview = contenu.length > 100 ? '${contenu.substring(0, 100)}…' : contenu;
          ctx.writeln('  • ${m['auteur']} (${m['role']}) [$date] : $preview');
        }
      }
    } catch (_) {}
  }

  // ── Contexte de tous les projets du client ────────────────────────────────
  static Future<String> _buildAllProjectsContext(
      List<Map<String, dynamic>> projets) async {
    final ctx = StringBuffer();
    ctx.writeln('Le client a ${projets.length} projet(s) :');
    for (int i = 0; i < projets.length; i++) {
      await _appendProjetContext(projets[i], ctx, i + 1);
    }
    return ctx.toString();
  }

  // Compat : contexte d'un seul projet (utilisé par resumeSimple / alerteExplication)
  static Future<String> _buildProjectContext(
      Map<String, dynamic> projet) async {
    final ctx = StringBuffer();
    await _appendProjetContext(projet, ctx, 1);
    return ctx.toString();
  }

  static const _noSignature =
      'NE termine JAMAIS ta réponse par une formule de politesse, une signature, '
      '"Cordialement", "[votre nom]" ou tout autre pied de lettre.';

  // ── Prompt système strict ─────────────────────────────────────────────────
  static String _systemChatbot(String context) =>
      'Tu es l\'assistant personnel du client pour son projet de construction en Tunisie. '
      'Tu as accès aux données réelles du projet listées ci-dessous.\n\n'
      'RÈGLES ABSOLUES :\n'
      '1. Réponds UNIQUEMENT aux questions liées à ce projet ou à la construction/architecture en général.\n'
      '2. Si la question concerne un projet, document, message, paiement ou actualité, '
      'utilise les données réelles du contexte pour répondre avec précision.\n'
      '3. Sois court (3-4 phrases max), professionnel et rassurant.\n'
      '4. Si la question est hors domaine (politique, sport, médecine, cuisine, '
      'sujets aléatoires, etc.), réponds EXACTEMENT : "$_hors_domaine"\n'
      '5. N\'invente jamais d\'informations absentes du contexte.\n'
      '6. $_noSignature\n\n'
      'DONNÉES DU PROJET :\n$context';

  // ── API publique ──────────────────────────────────────────────────────────

  /// Résumé global de tous les projets du client (carte "Mon projet en résumé").
  static Future<String> resumeTousLesProjets(List<Map<String, dynamic>> projets) async {
    final ctx = await _buildAllProjectsContext(projets);
    return _call(
      'Tu es le conseiller de confiance du client pour ses projets de construction en Tunisie. '
      'Résume en 3-4 phrases courtes, chaleureuses et claires l\'état global de tous ses projets. '
      'Mentionne chaque projet par son nom, son avancement et sa date de livraison si disponible. '
      'Exemple : "Votre villa à Tunis avance bien à 60% ! Votre appartement à Sfax est à 30%, livraison prévue en juin." '
      'Réponds UNIQUEMENT en français. $_noSignature',
      'Données réelles de tous les projets :\n$ctx\n\nRédige un résumé global chaleureux pour le client.',
      maxTokens: 600,
    );
  }

  /// Résumé d'un seul projet (gardé pour compatibilité).
  static Future<String> resumeSimple(Map<String, dynamic> projet) async {
    final ctx = await _buildProjectContext(projet);
    return _call(
      'Tu es le conseiller de confiance du client pour son projet de construction en Tunisie. '
      'Résume l\'état du projet en 2-3 phrases courtes en langage simple et chaleureux. '
      'Réponds UNIQUEMENT en français. $_noSignature',
      'Données réelles du projet :\n$ctx\n\nRédige un résumé chaleureux pour le client.',
    );
  }

  /// Chatbot avec contexte réel de tous les projets du client.
  static Future<String> chatClient(
      String question, List<Map<String, dynamic>> projets) async {
    final ctx    = await _buildAllProjectsContext(projets);
    final system = _systemChatbot(ctx);
    return _call(system, question, maxTokens: 500);
  }

  /// Si retard ou dépassement budget : explication rassurante avec cause probable.
  static Future<String> alerteExplication(Map<String, dynamic> projet) async {
    final ctx = await _buildProjectContext(projet);
    return _call(
      'Tu es le conseiller de confiance du client pour son projet de construction en Tunisie. '
      'Explique une situation de retard ou d\'anomalie de façon RASSURANTE et POSITIVE, '
      'en t\'appuyant sur les données réelles. '
      'Donne une cause probable réaliste et la prochaine étape concrète. '
      'Ton professionnel et bienveillant. Réponds en français. Maximum 3 phrases. $_noSignature',
      'Données du projet :\n$ctx\n\nExplique cette situation de façon rassurante au client.',
    );
  }

  /// Répond aux questions générales sur la construction en Tunisie (sans contexte projet).
  static Future<String> faqConstruction(String question) {
    return _call(
      'Tu es un expert en construction en Tunisie. '
      'Réponds aux questions générales sur : matériaux locaux, normes tunisiennes, '
      'délais typiques, permis de construire, réception des travaux, gros œuvre, '
      'finitions, garanties légales, coûts indicatifs, etc. '
      'Si la question est hors domaine (politique, sport, médecine, etc.), réponds EXACTEMENT : '
      '"$_hors_domaine" '
      'Sinon, réponds en français, de façon claire et accessible. Maximum 4 phrases. $_noSignature',
      question,
      maxTokens: 500,
    );
  }
}
