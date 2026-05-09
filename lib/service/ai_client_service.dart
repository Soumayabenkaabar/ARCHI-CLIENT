// lib/service/ai_client_service.dart
// Utilise la même Edge Function Supabase "ai-proxy" que l'app architecte.
// La clé Groq est stockée côté serveur dans les variables d'environnement Supabase.
import 'package:supabase_flutter/supabase_flutter.dart';

class AiClientService {
  static const _modelFast = 'claude-haiku-4-5-20251001'; // mappé → llama-3.1-8b-instant
  static final _supa = Supabase.instance.client;

  // ── Appel via Edge Function (même proxy que l'app architecte) ─────────────
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

  /// Résumé en 2-3 phrases en langage courant de l'état du projet.
  static Future<String> resumeSimple(Map<String, dynamic> projet) {
    final titre      = projet['titre'] ?? projet['name'] ?? 'Votre projet';
    final avancement = projet['avancement'] ?? projet['progress'] ?? 0;
    final statut     = projet['statut'] ?? 'en_cours';
    final dateFin    = projet['date_fin'] ?? projet['date_livraison'];

    final ctx = StringBuffer();
    ctx.writeln('Titre : $titre');
    ctx.writeln('Avancement : $avancement%');
    ctx.writeln('Statut : $statut');
    if (dateFin != null) ctx.writeln('Date de livraison prévue : $dateFin');

    return _call(
      'Tu es le conseiller de confiance du client pour son projet de construction en Tunisie. '
      'Résume l\'état du projet en 2-3 phrases courtes en langage simple et chaleureux. '
      'Exemple : "Votre villa avance bien ! Les travaux sont à 60%, la livraison est prévue dans environ 3 mois." '
      'Réponds UNIQUEMENT en français.',
      'Donne un résumé chaleureux de ce projet :\n$ctx',
    );
  }

  /// Chatbot limité au contexte du projet du client.
  static Future<String> chatClient(
      String question, Map<String, dynamic> projet) {
    final titre      = projet['titre'] ?? projet['name'] ?? 'Votre projet';
    final avancement = projet['avancement'] ?? projet['progress'] ?? 0;
    final statut     = projet['statut'] ?? 'en_cours';

    return _call(
      'Tu es l\'assistant personnel du client pour son projet de construction "$titre" en Tunisie. '
      'Contexte : avancement $avancement%, statut $statut. '
      'Rôle : conseiller de confiance. Réponds SEULEMENT aux questions liées à CE projet '
      'ou à la construction en général. N\'invente jamais d\'informations précises. '
      'Si tu ne sais pas, dis-le simplement. Réponds en français, de façon simple et rassurante. '
      'Maximum 3-4 phrases.',
      question,
      maxTokens: 400,
    );
  }

  /// Si retard ou dépassement budget : explication rassurante avec cause probable.
  static Future<String> alerteExplication(Map<String, dynamic> projet) {
    final titre       = projet['titre'] ?? projet['name'] ?? 'Votre projet';
    final avancement  = projet['avancement'] ?? projet['progress'] ?? 0;
    final statut      = projet['statut'] ?? 'en_cours';
    final retard      = projet['retard_jours'];
    final depassement = projet['depassement_budget'];

    final ctx = StringBuffer();
    ctx.writeln('Projet : $titre');
    ctx.writeln('Avancement : $avancement%');
    ctx.writeln('Statut : $statut');
    if (retard != null) ctx.writeln('Retard constaté : $retard jours');
    if (depassement != null) ctx.writeln('Dépassement budgétaire : $depassement');

    return _call(
      'Tu es le conseiller de confiance du client pour son projet de construction en Tunisie. '
      'Explique une situation de retard ou d\'anomalie de façon RASSURANTE et POSITIVE. '
      'Donne une cause probable réaliste (intempéries, délais fournisseurs, etc.) '
      'et la prochaine étape concrète. Ton professionnel et bienveillant. '
      'Réponds en français. Maximum 3 phrases.',
      'Explique cette situation de façon rassurante :\n$ctx',
    );
  }

  /// Répond aux questions générales sur la construction en Tunisie.
  static Future<String> faqConstruction(String question) {
    return _call(
      'Tu es un expert en construction en Tunisie. '
      'Réponds aux questions générales sur : matériaux locaux, normes tunisiennes, '
      'délais typiques, permis de construire, réception des travaux, gros œuvre, '
      'finitions, garanties légales, coûts indicatifs, etc. '
      'Réponds en français, de façon claire, pratique et accessible. Maximum 4 phrases.',
      question,
      maxTokens: 500,
    );
  }
}
