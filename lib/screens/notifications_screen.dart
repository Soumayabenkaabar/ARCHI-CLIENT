// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../service/ai_client_service.dart';
import '../service/client_auth_service.dart';
import '../service/client_portal_service.dart';

// ── Couleurs (cohérentes avec le portail) ─────────────────────────────────────
const _kNavy    = Color(0xFF0B1437);
const _kOrange  = Color(0xFFF97316);
const _kBg      = Color(0xFFF1F5FF);
const _kSurface = Colors.white;
const _kText    = Color(0xFF0B1437);
const _kMuted   = Color(0xFF64748B);
const _kBorder  = Color(0xFFE2E8F0);
const _kGreen   = Color(0xFF10B981);
const _kRed     = Color(0xFFEF4444);

const _kFaqQuestions = [
  'Combien de temps dure une construction R+1 ?',
  'Quels sont les matériaux les plus utilisés en Tunisie ?',
  'Comment se déroule la réception des travaux ?',
  'Quelles sont les étapes d\'une construction ?',
  'Qu\'est-ce qu\'un permis de construire en Tunisie ?',
  'Comment est calculé le coût d\'une construction ?',
  'Qu\'est-ce que la réception provisoire ?',
  'Quelle est la durée de garantie après construction ?',
  'Comment choisir ses matériaux de finition ?',
  'Qu\'est-ce que le gros œuvre ?',
];

// ── Modèle local ──────────────────────────────────────────────────────────────
class _Notif {
  final String type, contenu, auteur, date, projetId, projetTitre;
  final Map<String, dynamic> projetData;
  const _Notif({
    required this.type,
    required this.contenu,
    required this.auteur,
    required this.date,
    required this.projetId,
    required this.projetTitre,
    required this.projetData,
  });
}

// ── Écran principal ───────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  final ClientSession session;
  final List<Map<String, dynamic>> projets;

  const NotificationsScreen({
    super.key,
    required this.session,
    required this.projets,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<_Notif> _notifs = [];
  bool _loadingNotifs = true;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final Map<String, String> _faqAnswers   = {};
  final Map<String, bool>   _faqLoading   = {};
  final Map<String, bool>   _faqExpanded  = {};

  final Map<String, String> _alerteAnswers = {};
  final Map<String, bool>   _alerteLoading = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Chargement des notifications ──────────────────────────────────────────

  Future<void> _loadNotifications() async {
    final all = <_Notif>[];
    for (final p in widget.projets.take(5)) {
      final projetId = p['id']?.toString() ?? '';
      if (projetId.isEmpty) continue;
      final titre = (p['titre'] as String?) ?? 'Projet';
      try {
        final rows = await ClientPortalService.getActualitesChantier(projetId);
        for (final a in rows) {
          all.add(_Notif(
            type:        (a['type']    as String?) ?? 'Info',
            contenu:     (a['contenu'] as String?) ?? '',
            auteur:      (a['auteur']  as String?) ?? '',
            date:        (a['created_at'] as String?) ?? '',
            projetId:    projetId,
            projetTitre: titre,
            projetData:  p,
          ));
        }
      } catch (_) {}
    }
    all.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() { _notifs = all; _loadingNotifs = false; });
  }

  bool _isAlerte(_Notif n) {
    final t = n.type.toLowerCase();
    return t == 'problème' || t == 'probleme' || t == 'retard' || t == 'alerte';
  }

  // ── Explication alerte ────────────────────────────────────────────────────

  Future<void> _onComprendreAlerte(_Notif notif) async {
    final key = '${notif.projetId}_${notif.date}';
    if (_alerteAnswers.containsKey(key)) {
      _showAlerteDialog(_alerteAnswers[key]!, notif);
      return;
    }
    if (_alerteLoading[key] == true) return;
    setState(() => _alerteLoading[key] = true);
    try {
      final texte = await AiClientService.alerteExplication(notif.projetData);
      if (!mounted) return;
      setState(() {
        _alerteAnswers[key] = texte;
        _alerteLoading[key] = false;
      });
      _showAlerteDialog(texte, notif);
    } catch (_) {
      if (mounted) setState(() => _alerteLoading[key] = false);
    }
  }

  void _showAlerteDialog(String explication, _Notif notif) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _kOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.shield, size: 17, color: _kOrange),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Explication de l\'alerte',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kText)),
          ),
        ]),
        content: Text(explication,
          style: const TextStyle(fontSize: 13, color: _kText, height: 1.65)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris',
              style: TextStyle(color: _kOrange, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ── FAQ ───────────────────────────────────────────────────────────────────

  Future<void> _askFaq(String question) async {
    if (_faqLoading[question] == true) return;
    setState(() {
      _faqLoading[question]  = true;
      _faqExpanded[question] = true;
    });
    if (!_faqAnswers.containsKey(question)) {
      try {
        final answer = await AiClientService.faqConstruction(question);
        if (mounted) setState(() { _faqAnswers[question] = answer; _faqLoading[question] = false; });
      } catch (_) {
        if (mounted) setState(() => _faqLoading[question] = false);
      }
    } else {
      setState(() => _faqLoading[question] = false);
    }
  }

  List<String> get _filteredQuestions {
    if (_searchQuery.isEmpty) return _kFaqQuestions;
    return _kFaqQuestions
        .where((q) => q.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -20),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildNotificationsSection(),
                  const SizedBox(height: 28),
                  _buildFaqSection(),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    color: _kNavy,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20, right: 20, bottom: 32,
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 18),
        ),
      ),
      const SizedBox(width: 14),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Alertes & FAQ',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: -0.4)),
          SizedBox(height: 2),
          Text('Notifications et questions fréquentes',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ]),
      ),
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(LucideIcons.bell, color: Colors.white, size: 17),
      ),
      const SizedBox(width: 8),
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(LucideIcons.userCircle, color: Colors.white, size: 17),
      ),
    ]),
  );

  // ── Section Notifications ─────────────────────────────────────────────────

  Widget _buildNotificationsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Alertes chantier', LucideIcons.alertTriangle, _kRed),
      const SizedBox(height: 12),
      if (_loadingNotifs)
        _loadingCard()
      else if (_notifs.isEmpty)
        _emptyCard('Aucune alerte pour vos projets', LucideIcons.checkCircle, _kGreen)
      else
        ..._notifs.map(_buildNotifCard),
    ],
  );

  Widget _buildNotifCard(_Notif notif) {
    final alerte = _isAlerte(notif);
    final t = notif.type.toLowerCase();
    final color = alerte
        ? _kRed
        : (t == 'progrès' || t == 'progres' ? _kGreen
            : t == 'livraison' ? const Color(0xFF3B82F6)
            : _kOrange);
    final key = '${notif.projetId}_${notif.date}';
    final loading = _alerteLoading[key] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: alerte ? Border.all(color: _kRed.withOpacity(0.15)) : null,
        boxShadow: [
          if (alerte)
            BoxShadow(color: _kRed.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
          const BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Ligne type + projet + date
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(notif.type,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(notif.projetTitre,
            style: const TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(_relativeDate(notif.date),
            style: const TextStyle(fontSize: 10, color: _kMuted)),
        ]),
        const SizedBox(height: 8),
        Text(notif.contenu,
          style: const TextStyle(fontSize: 13, color: _kText, height: 1.5)),
        if (notif.auteur.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(LucideIcons.user, size: 11, color: _kMuted),
            const SizedBox(width: 4),
            Text(notif.auteur,
              style: const TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w500)),
          ]),
        ],
        if (alerte) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: loading ? null : () => _onComprendreAlerte(notif),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: loading ? _kBg : _kOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kOrange.withOpacity(0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (loading)
                  const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2))
                else
                  const Icon(LucideIcons.helpCircle, size: 14, color: _kOrange),
                const SizedBox(width: 7),
                Text(
                  loading ? 'Analyse en cours...' : 'Comprendre cette alerte',
                  style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: _kOrange),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Section FAQ ───────────────────────────────────────────────────────────

  Widget _buildFaqSection() {
    final filtered = _filteredQuestions;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Questions fréquentes', LucideIcons.helpCircle, _kOrange),
      const SizedBox(height: 14),

      // Barre de recherche
      Container(
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(fontSize: 13, color: _kText),
          decoration: InputDecoration(
            hintText: 'Chercher ou poser une question...',
            hintStyle: TextStyle(color: _kMuted.withOpacity(0.6), fontSize: 13),
            prefixIcon: const Icon(LucideIcons.search, size: 16, color: _kMuted),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                    child: const Icon(LucideIcons.x, size: 16, color: _kMuted),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          ),
        ),
      ),

      // Bouton "Poser cette question" pour saisie libre
      if (_searchQuery.trim().isNotEmpty &&
          !_kFaqQuestions.any((q) =>
              q.toLowerCase() == _searchQuery.trim().toLowerCase())) ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _askFaq(_searchQuery.trim()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kOrange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kOrange.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(LucideIcons.send, size: 14, color: _kOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Poser : "${_searchQuery.trim()}"',
                  style: const TextStyle(fontSize: 12, color: _kOrange, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),
        if (_faqAnswers.containsKey(_searchQuery.trim())) ...[
          const SizedBox(height: 10),
          _buildFreeAnswer(_searchQuery.trim()),
        ],
      ],
      const SizedBox(height: 14),
      ...filtered.map(_buildFaqItem),
    ]);
  }

  Widget _buildFaqItem(String question) {
    final expanded = _faqExpanded[question] == true;
    final loading  = _faqLoading[question] == true;
    final answer   = _faqAnswers[question];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => _askFaq(question),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _kOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.helpCircle, size: 13, color: _kOrange),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(question,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText))),
              if (loading)
                const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2))
              else
                Icon(
                  expanded && answer != null ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16, color: _kMuted,
                ),
            ]),
          ),
        ),
        if (expanded && answer != null) ...[
          const Divider(height: 1, color: _kBorder, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Text(answer,
              style: const TextStyle(fontSize: 13, color: _kText, height: 1.65)),
          ),
        ],
      ]),
    );
  }

  Widget _buildFreeAnswer(String question) {
    final answer = _faqAnswers[question];
    if (answer == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kOrange.withOpacity(0.15)),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(answer,
        style: const TextStyle(fontSize: 13, color: _kText, height: 1.65)),
    );
  }

  // ── Widgets utilitaires ───────────────────────────────────────────────────

  Widget _sectionTitle(String title, IconData icon, Color color) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 15, color: color),
    ),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
        color: _kText, letterSpacing: -0.4)),
  ]);

  Widget _loadingCard() => Container(
    height: 80,
    decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14)),
    child: const Center(child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2)),
  );

  Widget _emptyCard(String msg, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(msg,
        style: const TextStyle(fontSize: 13, color: _kMuted, fontWeight: FontWeight.w500))),
    ]),
  );

  String _relativeDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inDays == 0) return 'Aujourd\'hui';
      if (diff.inDays == 1) return 'Hier';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
      return 'Il y a ${(diff.inDays / 7).floor()}sem.';
    } catch (_) { return ''; }
  }
}
