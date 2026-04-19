// lib/screens/client_portal_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../constants/colors.dart';
import '../service/client_auth_service.dart';
import 'client_login_screen.dart';

class ClientPortalScreen extends StatefulWidget {
  final ClientSession session;
  const ClientPortalScreen({super.key, required this.session});
  @override State<ClientPortalScreen> createState() => _ClientPortalScreenState();
}

class _ClientPortalScreenState extends State<ClientPortalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _projet;
  bool _loadingProjet = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadProjet();
  }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadProjet() async {
    try {
      final rows = await Supabase.instance.client
          .from('projets')
          .select()
          .eq('id', widget.session.projetId)
          .single();
      if (mounted) setState(() { _projet = rows; _loadingProjet = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingProjet = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Se déconnecter ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('Vous devrez vous reconnecter avec votre mot de passe.', style: TextStyle(color: kTextSub, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Se déconnecter', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (confirm != true) return;
    await ClientAuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ClientLoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: kBg,
      body: _loadingProjet
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : NestedScrollView(
              headerSliverBuilder: (ctx, _) => [
                SliverToBoxAdapter(child: _buildHeader(isMobile)),
              ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  _TachesClientTab(projetId: widget.session.projetId),
                  _PhotosClientTab(projetId: widget.session.projetId),
                  _Modele3DClientTab(projet: _projet),
                  _CommentairesClientTab(session: widget.session),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final p = _projet;
    final pad = isMobile ? 16.0 : 28.0;
    return Material(
      color: kCardBg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, isMobile ? 50 : 24, pad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top bar
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(9)), child: const Icon(LucideIcons.building2, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            const Text('ArchiManager', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextMain)),
            const Spacer(),
            // Badge client
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.user, size: 12, color: kAccent),
                const SizedBox(width: 5),
                Text(widget.session.clientNom, style: const TextStyle(color: kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 8),
            GestureDetector(onTap: _logout, child: const Icon(LucideIcons.logOut, size: 18, color: kTextSub)),
          ]),

          const SizedBox(height: 20),

          if (p != null) ...[
            // Titre projet
            Text(p['titre'] ?? '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextMain)),
            const SizedBox(height: 6),
            // Info bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip(LucideIcons.mapPin, p['localisation'] ?? '—'),
                const SizedBox(width: 10),
                _chip(LucideIcons.user, p['chef_projet'] ?? p['chef'] ?? '—'),
                const SizedBox(width: 10),
                _chip(LucideIcons.calendar, '${p['date_debut'] ?? '—'} → ${p['date_fin'] ?? '—'}'),
              ]),
            ),
            const SizedBox(height: 14),
            // Progression
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Progression du projet', style: TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w500)),
              Text('${p['avancement'] ?? 0}%', style: const TextStyle(fontWeight: FontWeight.w700, color: kTextMain, fontSize: 12)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: ((p['avancement'] ?? 0) as num) / 100,
                minHeight: 7,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(kAccent),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Badge "Lecture seule"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.eye, size: 12, color: Color(0xFF3B82F6)),
              SizedBox(width: 5),
              Text('Mode consultation — accès client', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 14),

          // TabBar
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: kTextMain,
            unselectedLabelColor: kTextSub,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            indicatorColor: kAccent,
            indicatorWeight: 3,
            dividerColor: const Color(0xFFE5E7EB),
            tabs: const [
              Tab(text: 'Tâches'),
              Tab(text: 'Photos'),
              Tab(text: 'Modèle 3D'),
              Tab(text: 'Commentaires'),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: kTextSub), const SizedBox(width: 4),
    Text(text, style: const TextStyle(color: kTextSub, fontSize: 11)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET TÂCHES (lecture seule)
// ══════════════════════════════════════════════════════════════════════════════
class _TachesClientTab extends StatefulWidget {
  final String projetId;
  const _TachesClientTab({required this.projetId});
  @override State<_TachesClientTab> createState() => _TachesClientTabState();
}
class _TachesClientTabState extends State<_TachesClientTab> {
  List<Map<String, dynamic>> taches = [];
  List<Map<String, dynamic>> phases = [];
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Supabase.instance.client.from('taches').select().eq('projet_id', widget.projetId).order('created_at'),
        Supabase.instance.client.from('phases').select().eq('projet_id', widget.projetId).order('ordre'),
      ]);
      if (!mounted) return;
      setState(() {
        taches  = List<Map<String, dynamic>>.from(results[0]);
        phases  = List<Map<String, dynamic>>.from(results[1]);
        loading = false;
      });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  Color _color(String s) { switch (s) { case 'en_cours': return kAccent; case 'termine': return kGreen; default: return const Color(0xFF9CA3AF); } }
  String _label(String s) { switch (s) { case 'en_cours': return 'En cours'; case 'termine': return 'Terminé'; default: return 'Planifié'; } }

  int get _total     => taches.length;
  int get _terminees => taches.where((t) => t['statut'] == 'termine').length;
  int get _enCours   => taches.where((t) => t['statut'] == 'en_cours').length;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).size.width < 800 ? 16.0 : 28.0;
    if (loading) return const Center(child: CircularProgressIndicator(color: kAccent));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Planning & Tâches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 4),
        const Text('Avancement de votre projet', style: TextStyle(color: kTextSub, fontSize: 12)),
        const SizedBox(height: 16),

        // KPIs
        Row(children: [
          _kpi('Total',      '$_total',     kAccent,  LucideIcons.listChecks),
          const SizedBox(width: 10),
          _kpi('En cours',   '$_enCours',   kBlue,    LucideIcons.activity),
          const SizedBox(width: 10),
          _kpi('Terminées',  '$_terminees', kGreen,   LucideIcons.checkCircle),
        ]),
        const SizedBox(height: 16),

        // Barre progression globale
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Progression des tâches', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kTextMain)),
              Text('${_total == 0 ? 0 : (_terminees / _total * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kAccent)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
              value: _total == 0 ? 0 : _terminees / _total,
              minHeight: 9, backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(kAccent),
            )),
          ]),
        ),
        const SizedBox(height: 20),

        // Liste tâches par phase
        if (taches.isEmpty)
          _empty(LucideIcons.listChecks, 'Aucune tâche pour l\'instant')
        else ...[
          ...phases.map((ph) {
            final phTaches = taches.where((t) => t['phase_id'] == ph['id']).toList();
            if (phTaches.isEmpty) return const SizedBox.shrink();
            final done = phTaches.where((t) => t['statut'] == 'termine').length;
            final prog = phTaches.isEmpty ? 0.0 : done / phTaches.length;
            return _phaseSection(ph['nom'], phTaches, prog);
          }),
          // Tâches sans phase
          ...() {
            final sans = taches.where((t) => t['phase_id'] == null || (t['phase_id'] as String).isEmpty).toList();
            if (sans.isEmpty || phases.isNotEmpty) return <Widget>[];
            return sans.map((t) => _tacheCard(t)).toList();
          }(),
        ],
      ]),
    );
  }

  Widget _phaseSection(String nom, List phTaches, double prog) {
    final pct = (prog * 100).round();
    final color = pct == 100 ? kGreen : pct > 0 ? kAccent : const Color(0xFF9CA3AF);
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)), child: Column(children: [
        Row(children: [const Icon(LucideIcons.layers, size: 13, color: kTextSub), const SizedBox(width: 8), Expanded(child: Text(nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextMain))), Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: prog, minHeight: 5, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(color))),
      ])),
      const SizedBox(height: 8),
      ...phTaches.map((t) => _tacheCard(t)),
    ]));
  }

  Widget _tacheCard(Map t) {
    final color = _color(t['statut'] ?? '');
    final pct = t['statut'] == 'termine' ? 100 : t['statut'] == 'en_cours' ? 65 : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0F0F0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t['titre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5), Text(_label(t['statut'] ?? ''), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))])),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct / 100, minHeight: 4, backgroundColor: const Color(0xFFE5E7EB), valueColor: AlwaysStoppedAnimation<Color>(color))),
        if ((t['description'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(t['description'], style: const TextStyle(color: kTextSub, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        if (t['date_debut'] != null || t['date_fin'] != null) ...[
          const SizedBox(height: 8),
          Row(children: [const Icon(LucideIcons.calendar, size: 12, color: kTextSub), const SizedBox(width: 5), Text('${t['date_debut'] ?? '?'} → ${t['date_fin'] ?? '?'}', style: const TextStyle(color: kTextSub, fontSize: 11))]),
        ],
      ]),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 15)),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: kTextMain)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: kTextSub, fontSize: 11)),
    ]),
  ));
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET PHOTOS (lecture seule)
// ══════════════════════════════════════════════════════════════════════════════
class _PhotosClientTab extends StatefulWidget {
  final String projetId;
  const _PhotosClientTab({required this.projetId});
  @override State<_PhotosClientTab> createState() => _PhotosClientTabState();
}
class _PhotosClientTabState extends State<_PhotosClientTab> {
  List<Map<String, dynamic>> photos = [];
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      // Charge les documents de type image
      final rows = await Supabase.instance.client
          .from('documents')
          .select()
          .eq('projet_id', widget.projetId)
          .eq('type', 'image')
          .order('uploaded_at', ascending: false);
      if (!mounted) return;
      setState(() { photos = List<Map<String, dynamic>>.from(rows); loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).size.width < 800 ? 16.0 : 28.0;
    if (loading) return const Center(child: CircularProgressIndicator(color: kAccent));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Photos du chantier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 4),
        const Text('Galerie de suivi visuel du projet', style: TextStyle(color: kTextSub, fontSize: 12)),
        const SizedBox(height: 20),
        if (photos.isEmpty)
          _empty(LucideIcons.image, 'Aucune photo disponible pour l\'instant')
        else
          LayoutBuilder(builder: (ctx, cs) {
            final cols = cs.maxWidth > 600 ? 3 : 2;
            final rows = <Widget>[];
            for (int i = 0; i < photos.length; i += cols) {
              final row = photos.skip(i).take(cols).toList();
              rows.add(Row(children: [
                for (int j = 0; j < row.length; j++) ...[
                  if (j > 0) const SizedBox(width: 10),
                  Expanded(child: _photoCard(row[j])),
                ],
                if (row.length < cols) ...[const SizedBox(width: 10), const Expanded(child: SizedBox())],
              ]));
              if (i + cols < photos.length) rows.add(const SizedBox(height: 10));
            }
            return Column(children: rows);
          }),
      ]),
    );
  }

  Widget _photoCard(Map<String, dynamic> doc) {
    final url = doc['url'] ?? '';
    return Container(
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(aspectRatio: 4 / 3, child: url.startsWith('http')
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF3F4F6), child: const Icon(LucideIcons.image, color: kTextSub, size: 28)))
          : Container(color: const Color(0xFFF3F4F6), child: const Icon(LucideIcons.image, color: kTextSub, size: 28))),
        Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc['nom']?.split('||META||').first ?? doc['nom'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextMain), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text((doc['uploaded_at'] ?? '').toString().substring(0, 10), style: const TextStyle(fontSize: 10, color: kTextSub)),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET MODÈLE 3D (lecture seule)
// ══════════════════════════════════════════════════════════════════════════════
class _Modele3DClientTab extends StatelessWidget {
  final Map<String, dynamic>? projet;
  const _Modele3DClientTab({this.projet});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).size.width < 800 ? 16.0 : 28.0;
    final url3d = projet?['modele_3d_url'] as String?;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Modèle 3D', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextMain)),
        const SizedBox(height: 4),
        const Text('Visualisez la maquette numérique de votre projet', style: TextStyle(color: kTextSub, fontSize: 12)),
        const SizedBox(height: 20),

        if (url3d != null && url3d.isNotEmpty)
          Container(
            decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Column(children: [
              Container(padding: const EdgeInsets.all(16), child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.box, size: 16, color: kAccent)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Maquette numérique', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain)), Text('Cliquez pour ouvrir dans votre navigateur', style: TextStyle(fontSize: 11, color: kTextSub))])),
                GestureDetector(onTap: () async { final uri = Uri.tryParse(url3d); if (uri != null) try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {} }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)), child: const Text('Ouvrir', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))),
              ])),
              Container(height: 220, decoration: BoxDecoration(color: kDark, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(LucideIcons.box, size: 36, color: Colors.white70)),
                const SizedBox(height: 14),
                const Text('Modèle 3D disponible', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Touchez "Ouvrir" pour visualiser', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ])),
            ]),
          )
        else
          _empty(LucideIcons.box, 'Aucun modèle 3D disponible pour l\'instant\nVotre architecte l\'ajoutera prochainement.'),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ONGLET COMMENTAIRES (lecture + écriture client)
// ══════════════════════════════════════════════════════════════════════════════
class _CommentairesClientTab extends StatefulWidget {
  final ClientSession session;
  const _CommentairesClientTab({required this.session});
  @override State<_CommentairesClientTab> createState() => _CommentairesClientTabState();
}
class _CommentairesClientTabState extends State<_CommentairesClientTab> {
  List<Map<String, dynamic>> comments = [];
  bool loading = true;
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('commentaires')
          .select()
          .eq('projet_id', widget.session.projetId)
          .order('created_at');
      if (!mounted) return;
      setState(() { comments = List<Map<String, dynamic>>.from(rows); loading = false; });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    try {
      await Supabase.instance.client.from('commentaires').insert({
        'projet_id':  widget.session.projetId,
        'auteur':     widget.session.clientNom,
        'role':       'client',
        'contenu':    text,
        'created_at': DateTime.now().toIso8601String(),
        'client_portal_id': widget.session.id,
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: kRed, behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).size.width < 800 ? 16.0 : 28.0;
    if (loading) return const Center(child: CircularProgressIndicator(color: kAccent));

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
      child: Column(children: [
        // Fil
        Expanded(child: Container(
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Row(children: [
              const Icon(LucideIcons.messageSquare, size: 16, color: kTextSub),
              const SizedBox(width: 8),
              const Text('Échanges avec votre architecte', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain)),
              const Spacer(),
              Text('${comments.length} message(s)', style: const TextStyle(color: kTextSub, fontSize: 12)),
            ])),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            Expanded(child: comments.isEmpty
              ? _empty(LucideIcons.messageCircle, 'Aucun message\nCommencez la conversation !')
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (_, i) => _bubble(comments[i]),
                )),
          ]),
        )),
        const SizedBox(height: 12),
        // Saisie
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              onSubmitted: (_) => _send(),
              style: const TextStyle(fontSize: 13, color: kTextMain),
              decoration: const InputDecoration(
                hintText: 'Écrivez un message à votre architecte...',
                hintStyle: TextStyle(color: kTextSub, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            )),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _bubble(Map<String, dynamic> c) {
    final isClient = c['role'] == 'client';
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(
      crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isClient ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(c['auteur'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kTextMain)),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
              child: Text(isClient ? 'CLIENT' : 'ARCHITECTE', style: const TextStyle(color: kTextSub, fontSize: 9, fontWeight: FontWeight.w700))),
            const SizedBox(width: 6),
            Text((c['created_at'] ?? '').toString().length > 10 ? (c['created_at'] as String).substring(0, 10) : '', style: const TextStyle(color: kTextSub, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isClient ? kAccent : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isClient ? 14 : 0),
              bottomRight: Radius.circular(isClient ? 0 : 14),
            ),
          ),
          child: Text(c['contenu'] ?? '', style: TextStyle(color: isClient ? Colors.white : kTextMain, fontSize: 13, height: 1.4)),
        ),
      ],
    ));
  }
}

// ── Widget réutilisable état vide ─────────────────────────────────────────────
Widget _empty(IconData icon, String message) => Center(child: Padding(
  padding: const EdgeInsets.symmetric(vertical: 40),
  child: Column(children: [
    Icon(icon, size: 42, color: kTextSub.withOpacity(0.35)),
    const SizedBox(height: 14),
    Text(message, style: TextStyle(color: kTextSub.withOpacity(0.7), fontSize: 13), textAlign: TextAlign.center),
  ]),
));
