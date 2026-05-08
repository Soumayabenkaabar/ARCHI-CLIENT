// lib/screens/client_portal_screen.dart
import 'package:archi_client/screens/client_project_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../service/client_auth_service.dart';
import '../service/client_portal_service.dart';
import 'client_login_screen.dart';

// ── Modèles ───────────────────────────────────────────────────────────────────
class ClientProject {
  final String id, name, phase, lastUpdate, statut;
  final int progress, newItems;
  const ClientProject({
    required this.id, required this.name, required this.phase,
    required this.progress, required this.lastUpdate, required this.newItems,
    this.statut = 'en_cours',
  });
}

class ClientDocument {
  final String name, category, date;
  final String projetId, projetNom;
  final IconData icon;
  final bool isNew;
  final int uploadedAtMs;
  const ClientDocument({
    required this.name, required this.category, required this.date, required this.icon,
    this.projetId = '', this.projetNom = '',
    this.isNew = false, this.uploadedAtMs = 0,
  });
}

class ClientMessage {
  final String senderName, senderRole, initials, preview, time;
  final String projetId, projetNom;
  final bool isUnread;
  final Color avatarColor;
  final int createdAtMs;
  const ClientMessage({
    required this.senderName, required this.senderRole, required this.initials,
    required this.preview, required this.time, required this.isUnread,
    required this.avatarColor, required this.projetId, required this.projetNom,
    this.createdAtMs = 0,
  });
}

// ── Design System ─────────────────────────────────────────────────────────────
const _kNavy    = Color(0xFF0B1437);
const _kNavBar  = Color(0xFF0D1535);
const _kOrange  = Color(0xFFF97316);
const _kBg      = Color(0xFFF1F5FF);
const _kSurface = Colors.white;
const _kText    = Color(0xFF0B1437);
const _kMuted   = Color(0xFF64748B);
const _kBorder  = Color(0xFFE2E8F0);
const _kSheetRadius = Radius.circular(28);

const _kStatutColors = {
  'en_cours':   Color(0xFF3B82F6),
  'en_attente': Color(0xFFF59E0B),
  'termine':    Color(0xFF10B981),
  'annule':     Color(0xFFEF4444),
};

const _kDocColors = {
  'PDF':   Color(0xFFEF4444),
  'Image': Color(0xFF8B5CF6),
  'Plan':  Color(0xFF3B82F6),
  'Word':  Color(0xFF3B82F6),
  'Excel': Color(0xFF10B981),
};

// ── Écran principal ───────────────────────────────────────────────────────────
class ClientPortalScreen extends StatefulWidget {
  final ClientSession session;
  const ClientPortalScreen({super.key, required this.session});
  @override
  State<ClientPortalScreen> createState() => _ClientPortalScreenState();
}

class _ClientPortalScreenState extends State<ClientPortalScreen> {
  late ClientSession _session;
  int _selectedIndex = 0;
  List<ClientProject>  _projects  = [];
  List<ClientDocument> _documents = [];
  List<ClientMessage>  _messages  = [];
  bool _loading = true;
  String? _docsError;
  DateTime _lastMsgRead = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDocRead = DateTime.fromMillisecondsSinceEpoch(0);

  int get _unreadMsgCount => _messages.where((m) => m.isUnread).length;
  int get _newDocCount    => _documents.where((d) => d.isNew).length;

  static const _navLabels        = ['Accueil', 'Projets', 'Docs', 'Messages', 'Profil'];
  static const _navLabelsDesktop = ['Accueil', 'Projets', 'Documents', 'Messages', 'Profil'];
  static const _navIcons = [
    LucideIcons.layoutDashboard,
    LucideIcons.folderOpen,
    LucideIcons.fileText,
    LucideIcons.messageSquare,
    LucideIcons.userCircle,
  ];

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _loadPortalData();
  }

  Future<void> _loadPortalData() async {
    final prefs = await SharedPreferences.getInstance();
    final msgTs = prefs.getString('last_msg_read_${widget.session.id}');
    final docTs = prefs.getString('last_doc_read_${widget.session.id}');
    _lastMsgRead = msgTs != null ? DateTime.tryParse(msgTs) ?? _lastMsgRead : _lastMsgRead;
    _lastDocRead = docTs != null ? DateTime.tryParse(docTs) ?? _lastDocRead : _lastDocRead;

    final projetsData = await ClientPortalService
        .getProjetsForClient(_session.clientEmail)
        .catchError((_) => <Map<String, dynamic>>[]);

    List<Map<String, dynamic>> docsData = [];
    String? docsErr;
    try {
      docsData = await ClientPortalService.getRecentDocuments(_session.clientEmail);
      final projetNomMap = { for (final p in projetsData) p['id'].toString(): (p['titre'] as String?) ?? '' };
      docsData = docsData.map((d) => {
        ...d,
        '_projet_nom': projetNomMap[(d['projet_id'] as String?) ?? ''] ?? '',
      }).toList();
    } catch (e) { docsErr = e.toString(); }

    final msgsData = <Map<String, dynamic>>[];
    for (final p in projetsData.take(5)) {
      final msgs = await ClientPortalService
          .getRecentMessages(p['id'].toString(), limit: 5)
          .catchError((_) => <Map<String, dynamic>>[]);
      for (final m in msgs) {
        msgsData.add({ ...m, '_projet_id': p['id'].toString(), '_projet_nom': (p['titre'] as String?) ?? '' });
      }
    }
    msgsData.sort((a, b) =>
        ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? ''));

    if (!mounted) return;
    setState(() {
      _projects  = projetsData.map(_mapProjet).toList();
      _documents = docsData.map(_mapDocument).toList();
      _messages  = msgsData.map(_mapMessage).toList().take(30).toList();
      _docsError = docsErr;
      _loading   = false;
    });
  }

  static const _statutLabels = {
    'en_cours': 'En cours', 'en_attente': 'En attente',
    'termine': 'Terminé', 'annule': 'Annulé',
  };

  ClientProject _mapProjet(Map<String, dynamic> d) {
    final statut = (d['statut'] as String?) ?? 'en_cours';
    return ClientProject(
      id: d['id'].toString(), name: (d['titre'] as String?) ?? 'Mon projet',
      phase: _statutLabels[statut] ?? statut, statut: statut,
      progress: (d['avancement'] as num?)?.toInt() ?? 0,
      lastUpdate: _relativeDate((d['created_at'] as String?) ?? ''), newItems: 0,
    );
  }

  String _relativeDate(String iso) {
    if (iso.isEmpty) return 'Récemment';
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inDays == 0) return 'Aujourd\'hui';
      if (diff.inDays == 1) return 'Hier';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
      if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()}sem.';
      return 'Il y a ${(diff.inDays / 30).floor()} mois';
    } catch (_) { return 'Récemment'; }
  }

  static const _months = ['janv.','févr.','mars','avril','mai','juin',
      'juil.','août','sept.','oct.','nov.','déc.'];

  String _formatFullDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try { final d = DateTime.parse(iso); return '${d.day} ${_months[d.month - 1]}'; }
    catch (_) { return ''; }
  }

  static const _docTypeLabels = {
    'pdf': 'PDF', 'image': 'Image', 'img': 'Image', 'jpg': 'Image',
    'jpeg': 'Image', 'png': 'Image', 'dwg': 'Plan', 'cad': 'Plan',
    'docx': 'Word', 'doc': 'Word', 'xlsx': 'Excel', 'xls': 'Excel',
  };

  IconData _docIcon(String type) {
    final t = type.toLowerCase();
    if (['image','img','jpg','jpeg','png'].contains(t)) return LucideIcons.image;
    return LucideIcons.fileText;
  }

  String _cleanDocName(String raw) {
    if (raw.contains('||META||')) return raw.split('||META||').last.split('||').first.trim();
    if (raw.contains('||')) return raw.split('||').last.trim();
    return raw;
  }

  ClientDocument _mapDocument(Map<String, dynamic> d) {
    final type = (d['type'] as String?) ?? 'pdf';
    final uploadedIso = (d['uploaded_at'] as String?) ?? '';
    int uploadedMs = 0;
    try { uploadedMs = DateTime.parse(uploadedIso).millisecondsSinceEpoch; } catch (_) {}
    return ClientDocument(
      name: _cleanDocName((d['nom'] as String?) ?? 'Document'),
      category: _docTypeLabels[type.toLowerCase()] ?? type.toUpperCase(),
      date: _formatFullDate(uploadedIso.isNotEmpty ? uploadedIso : null),
      icon: _docIcon(type), uploadedAtMs: uploadedMs,
      projetId: (d['projet_id'] as String?) ?? '',
      projetNom: (d['_projet_nom'] as String?) ?? '',
      isNew: uploadedMs > 0 && uploadedMs > _lastDocRead.millisecondsSinceEpoch,
    );
  }

  static const _roleLabels = {
    'architecte': 'Architecte', 'client': 'Client',
    'chef_projet': 'Chef de projet', 'chef': 'Chef de projet',
  };
  static const _avatarColors = [
    Color(0xFFF97316), Color(0xFF3B82F6), Color(0xFF10B981),
    Color(0xFF8B5CF6), Color(0xFFEF4444),
  ];

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _avatarColor(String name) =>
      _avatarColors[name.codeUnits.fold(0, (a, b) => a + b) % _avatarColors.length];

  ClientMessage _mapMessage(Map<String, dynamic> d) {
    final auteur     = (d['auteur'] as String?) ?? 'Inconnu';
    final role       = (d['role']   as String?) ?? 'client';
    final createdIso = (d['created_at'] as String?) ?? '';
    int createdMs = 0;
    try { createdMs = DateTime.parse(createdIso).millisecondsSinceEpoch; } catch (_) {}
    return ClientMessage(
      senderName: auteur, senderRole: _roleLabels[role.toLowerCase()] ?? role,
      initials: _initials(auteur), preview: (d['contenu'] as String?) ?? '',
      time: _relativeDate(createdIso),
      isUnread: createdMs > 0 && createdMs > _lastMsgRead.millisecondsSinceEpoch,
      avatarColor: _avatarColor(auteur),
      projetId: (d['_projet_id'] as String?) ?? '',
      projetNom: (d['_projet_nom'] as String?) ?? '',
      createdAtMs: createdMs,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 860;
    return Scaffold(
      backgroundColor: _kNavy,
      body: isWide ? _buildDesktop() : _buildMobile(),
    );
  }

  // ── No project ────────────────────────────────────────────────────────────
  Widget _buildNoProjectScreen() => Scaffold(
    backgroundColor: _kNavy,
    body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: _kOrange, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _kOrange.withOpacity(0.4), blurRadius: 20)]),
          child: const Icon(LucideIcons.building2, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 36),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(LucideIcons.clock, size: 36, color: _kOrange.withOpacity(0.9)),
        ),
        const SizedBox(height: 28),
        const Text('Projet en cours d\'assignation',
          style: TextStyle(color: Colors.white, fontSize: 22,
              fontWeight: FontWeight.w800, letterSpacing: -0.5),
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Votre architecte va associer votre projet.\nContactez-le pour plus d\'informations.',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.7),
          textAlign: TextAlign.center),
        const SizedBox(height: 44),
        TextButton.icon(
          onPressed: _logout,
          icon: Icon(LucideIcons.logOut, size: 14, color: Colors.white.withOpacity(0.4)),
          label: Text('Déconnexion',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
        ),
      ]),
    ))),
  );

  // ── Desktop ───────────────────────────────────────────────────────────────
  Widget _buildDesktop() => Column(children: [
    _buildTopBar(),
    Expanded(child: _buildContent(isWide: true)),
  ]);

  // ── Mobile ────────────────────────────────────────────────────────────────
  Widget _buildMobile() => Column(children: [
    _buildMobileHeader(),
    Expanded(child: _buildContent(isWide: false)),
    _buildBottomNav(),
  ]);

  Widget _buildContent({required bool isWide}) {
    switch (_selectedIndex) {
      case 1: return _buildProjectsTab();
      case 2: return _buildDocumentsTab();
      case 3: return _buildMessagesTab();
      case 4: return _buildProfileTab();
      default: return _buildDashboard(isWide: isWide);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTopBar() => Container(
    height: 62, color: _kNavy,
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Row(children: [
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _kOrange, borderRadius: BorderRadius.circular(9)),
          child: const Icon(LucideIcons.building2, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 10),
        const Text('Portail Client',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
      const SizedBox(width: 40),
      Expanded(child: Row(children: List.generate(_navIcons.length, (i) {
        final sel   = i == _selectedIndex;
        final badge = i == 3 ? _unreadMsgCount : (i == 2 ? _newDocCount : 0);
        return GestureDetector(
          onTap: () => _onTabSelected(i),
          child: Stack(clipBehavior: Clip.none, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _kOrange.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: sel ? Border.all(color: _kOrange.withOpacity(0.3)) : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_navIcons[i], size: 14,
                    color: sel ? _kOrange : Colors.white.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(_navLabelsDesktop[i], style: TextStyle(fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    color: sel ? _kOrange : Colors.white.withOpacity(0.5))),
              ]),
            ),
            if (badge > 0) Positioned(top: -5, right: -5,
              child: _NavBadge(count: badge)),
          ]),
        );
      }))),
      GestureDetector(
        onTap: _logout,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(children: [
            Icon(LucideIcons.logOut, size: 14, color: Colors.white.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text('Déconnexion', style: TextStyle(fontSize: 12,
                color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    ]),
  );

  Widget _buildMobileHeader() => Container(
    decoration: BoxDecoration(
      color: _kNavy,
      boxShadow: [BoxShadow(color: _kNavy.withOpacity(0.3),
          blurRadius: 12, offset: const Offset(0, 4))],
    ),
    padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20, right: 20, bottom: 14),
    child: Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: _kOrange, borderRadius: BorderRadius.circular(10)),
        child: const Icon(LucideIcons.building2, color: Colors.white, size: 17),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Text('Portail Client',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
    ]),
  );

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() => Container(
    decoration: const BoxDecoration(
      color: _kNavBar,
      boxShadow: [BoxShadow(color: Color(0x30000000),
          blurRadius: 16, offset: Offset(0, -2))],
    ),
    padding: EdgeInsets.only(
        top: 10, bottom: MediaQuery.of(context).padding.bottom + 8),
    child: Row(
      children: List.generate(_navIcons.length, (i) {
        final sel   = i == _selectedIndex;
        final badge = i == 3 ? _unreadMsgCount : (i == 2 ? _newDocCount : 0);
        return Expanded(
          child: GestureDetector(
            onTap: () => _onTabSelected(i),
            behavior: HitTestBehavior.opaque,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Icône + badge dans un Stack local
              Stack(clipBehavior: Clip.none, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: 44, height: 32,
                  decoration: BoxDecoration(
                    color: sel ? _kOrange.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_navIcons[i], size: 20,
                      color: sel ? _kOrange : Colors.white.withOpacity(0.30)),
                ),
                if (badge > 0)
                  Positioned(
                    top: -5, right: -5,
                    child: _NavBadge(count: badge),
                  ),
              ]),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  color: sel ? _kOrange : Colors.white.withOpacity(0.30),
                ),
                child: Text(_navLabels[i]),
              ),
            ]),
          ),
        );
      }),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // DASHBOARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboard({required bool isWide}) {
    if (!_loading && _projects.isEmpty) return _buildNoProjectScreen();
    return SingleChildScrollView(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHero(),
      // ✅ Transform.translate au lieu de margin négative
      Transform.translate(
        offset: const Offset(0, -20),
        child: Container(
          decoration: const BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.vertical(top: _kSheetRadius),
          ),
          padding: EdgeInsets.fromLTRB(isWide ? 32 : 18, 24, isWide ? 32 : 18, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionHeader('Mes Projets', () => _onTabSelected(1)),
            const SizedBox(height: 14),
            if (_loading)
              _loadingWidget()
            else if (_projects.isEmpty)
              _emptyInline('Aucun projet trouvé')
            else
              ..._projects.map(_buildProjectCard),
            const SizedBox(height: 28),
            if (isWide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _buildRecentDocs()),
                const SizedBox(width: 18),
                Expanded(child: _buildRecentMsgs()),
              ])
            else ...[
              _buildRecentDocs(),
              const SizedBox(height: 18),
              _buildRecentMsgs(),
            ],
          ]),
        ),
      ),
    ]),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0B1437), Color(0xFF162050), Color(0xFF0B1437)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Stack(children: [
      Positioned(right: -30, top: -30, child: Container(
        width: 160, height: 160,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [_kOrange.withOpacity(0.15), _kOrange.withOpacity(0)])),
      )),
      Positioned(left: -50, bottom: -20, child: Container(
        width: 180, height: 180,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            const Color(0xFF3B82F6).withOpacity(0.12),
            const Color(0xFF3B82F6).withOpacity(0),
          ])),
      )),
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 44),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bonjour,', style: TextStyle(fontSize: 13,
                  color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w400)),
              const SizedBox(height: 3),
              Text(_session.clientNom,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -0.6, height: 1.1),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              _heroChip('${_projects.length}', 'Projets',
                  LucideIcons.folderOpen, _kOrange, () => _onTabSelected(1)),
              const SizedBox(width: 10),
              _heroChip('${_documents.length}', 'Documents',
                  LucideIcons.fileText, const Color(0xFF60A5FA), () => _onTabSelected(2)),
              const SizedBox(width: 10),
              _heroChip(
                _unreadMsgCount > 0 ? '$_unreadMsgCount' : '${_messages.length}',
                _unreadMsgCount > 0 ? 'Non lus' : 'Messages',
                LucideIcons.messageSquare, const Color(0xFFA78BFA), () => _onTabSelected(3),
              ),
            ]),
          ]),
        ),
      ),
    ]),
  );

  Widget _heroChip(String count, String label, IconData icon,
      Color color, VoidCallback onTap) =>
      Expanded(child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.09)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(height: 10),
            Text(count, style: const TextStyle(fontSize: 22,
                fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10,
                color: Colors.white.withOpacity(0.45), fontWeight: FontWeight.w500)),
          ]),
        ),
      ));

  Widget _sectionHeader(String title, [VoidCallback? onTap]) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
          color: _kText, letterSpacing: -0.4)),
      if (onTap != null)
        GestureDetector(
          onTap: onTap,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Voir tout', style: TextStyle(fontSize: 13,
                color: _kOrange.withOpacity(0.9), fontWeight: FontWeight.w600)),
            const SizedBox(width: 3),
            Icon(LucideIcons.arrowRight, size: 13, color: _kOrange.withOpacity(0.9)),
          ]),
        ),
    ],
  );

  Widget _buildProjectCard(ClientProject project) {
    final sc = _kStatutColors[project.statut] ?? _kOrange;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ClientProjectDetailScreen(
            projetId: project.id, projetNom: project.name,
            clientEmail: _session.clientEmail,
          ))).then((_) { if (mounted) _loadPortalData(); }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kSurface, borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: sc.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 6)),
            const BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(project.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: _kText, letterSpacing: -0.3),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: sc.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(project.phase, style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700, color: sc)),
              ]),
            ),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            Icon(LucideIcons.clock, size: 11, color: _kMuted.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text(project.lastUpdate,
                style: TextStyle(fontSize: 11, color: _kMuted.withOpacity(0.7))),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Avancement', style: TextStyle(fontSize: 11,
                color: _kMuted, fontWeight: FontWeight.w500)),
            Text('${project.progress}%', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w900, color: sc)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: project.progress / 100, minHeight: 7,
              backgroundColor: const Color(0xFFF1F5FF),
              valueColor: AlwaysStoppedAnimation<Color>(sc),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRecentDocs() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Documents récents', () => _onTabSelected(2)),
      const SizedBox(height: 16),
      if (_loading) _loadingWidget()
      else if (_docsError != null)
        Text('Erreur', style: TextStyle(fontSize: 12, color: Colors.red.shade400))
      else if (_documents.isEmpty) _emptyInline('Aucun document')
      else ..._documents.take(4).toList().asMap().entries.map((e) => Column(children: [
        if (e.key > 0) const Divider(height: 16, color: _kBorder),
        _docRow(e.value),
      ])),
    ]),
  );

  Widget _docRow(ClientDocument doc) {
    final cc = _kDocColors[doc.category] ?? _kOrange;
    return Row(children: [
      Container(width: 38, height: 38,
          decoration: BoxDecoration(color: cc.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(doc.icon, size: 17, color: cc)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(doc.name, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600, color: _kText),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: cc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5)),
            child: Text(doc.category, style: TextStyle(fontSize: 9,
                fontWeight: FontWeight.w700, color: cc)),
          ),
          if (doc.isNew) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(5)),
              child: const Text('NOUVEAU', style: TextStyle(color: Colors.white,
                  fontSize: 8, fontWeight: FontWeight.w800)),
            ),
          ] else if (doc.date.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(doc.date, style: const TextStyle(fontSize: 10, color: _kMuted)),
          ],
        ]),
      ])),
    ]);
  }

  Widget _buildRecentMsgs() {
    final unread = _loading ? <ClientMessage>[] : _messages.where((m) => m.isUnread).toList();
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text('Messages',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: _kText, letterSpacing: -0.4)),
            if (unread.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unread.length > 9 ? '9+' : '${unread.length}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ]),
          if (_messages.isNotEmpty)
            GestureDetector(
              onTap: () => _onTabSelected(3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Voir tout', style: TextStyle(fontSize: 13,
                    color: _kOrange.withOpacity(0.9), fontWeight: FontWeight.w600)),
                const SizedBox(width: 3),
                Icon(LucideIcons.arrowRight, size: 13,
                    color: _kOrange.withOpacity(0.9)),
              ]),
            ),
        ]),
        const SizedBox(height: 16),
        if (_loading) _loadingWidget()
        else if (unread.isEmpty)
          _emptyInline('Tous les messages lus ✓')
        else ...unread.take(3).toList().asMap().entries.map((e) => Column(children: [
          if (e.key > 0) const Divider(height: 16, color: _kBorder),
          _msgRow(e.value),
        ])),
      ]),
    );
  }

  Widget _msgRow(ClientMessage msg) => GestureDetector(
    onTap: () => _openComments(msg.projetId, msg.projetNom),
    child: Row(children: [
      Stack(clipBehavior: Clip.none, children: [
        CircleAvatar(radius: 18, backgroundColor: msg.avatarColor,
          child: Text(msg.initials, style: const TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w700))),
        if (msg.isUnread) Positioned(bottom: 0, right: 0,
          child: Container(width: 9, height: 9,
            decoration: BoxDecoration(color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5)))),
      ]),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(msg.senderName, style: TextStyle(fontSize: 12,
              fontWeight: msg.isUnread ? FontWeight.w800 : FontWeight.w600, color: _kText),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (msg.isUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('NOUVEAU', style: TextStyle(color: Colors.white,
                  fontSize: 7, fontWeight: FontWeight.w800)),
            )
          else
            Text(msg.time, style: const TextStyle(fontSize: 10, color: _kMuted)),
        ]),
        const SizedBox(height: 2),
        Text(msg.preview, style: TextStyle(fontSize: 11, color: _kMuted,
            fontWeight: msg.isUnread ? FontWeight.w500 : FontWeight.w400),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      const SizedBox(width: 4),
      Icon(LucideIcons.chevronRight, size: 13, color: _kMuted.withOpacity(0.4)),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TABS — style "sheet arrondie" identique au dashboard
  // ══════════════════════════════════════════════════════════════════════════

  // ── Tab header navy ───────────────────────────────────────────────────────
  Widget _tabHeader(String title, String sub, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        color: _kNavy,
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 11, color: color,
                fontWeight: FontWeight.w600)),
          ]),
        ]),
      );

  // ── Sheet commune ─────────────────────────────────────────────────────────
  // ✅ Transform.translate — pas de margin négative (interdit par Flutter)
  Widget _tabSheetContent(Widget child) => Expanded(
    child: Transform.translate(
      offset: const Offset(0, -24),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: _kSheetRadius),
        ),
        child: child,
      ),
    ),
  );

  // ── Projets ───────────────────────────────────────────────────────────────
  Widget _buildProjectsTab() => Column(children: [
    _tabHeader('Mes Projets',
        '${_projects.length} projet${_projects.length > 1 ? 's' : ''}',
        _kOrange, LucideIcons.folderOpen),
    _tabSheetContent(
      _loading
          ? _loadingWidget()
          : _projects.isEmpty
              ? _emptyState('Aucun projet assigné', LucideIcons.folderOpen)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
                  itemCount: _projects.length,
                  itemBuilder: (_, i) => _buildProjectCard(_projects[i])),
    ),
  ]);

  // ── Documents ─────────────────────────────────────────────────────────────
  Widget _buildDocumentsTab() {
    final newDocs = _documents.where((d) => d.isNew).toList();
    final subtitle = _newDocCount > 0
        ? '$_newDocCount nouveau${_newDocCount > 1 ? 'x' : ''}'
        : 'Aucun nouveau document';

    return Column(children: [
      _tabHeader('Documents', subtitle,
          _newDocCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
          LucideIcons.fileText),
      _tabSheetContent(
        _loading
            ? _loadingWidget()
            : _docsError != null
                ? Center(child: Text('Erreur : $_docsError',
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)))
                : newDocs.isEmpty
                    ? _emptyState('Aucun nouveau document', LucideIcons.fileText)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
                        children: [
                          _docsSection(
                            label: 'Nouveaux',
                            count: newDocs.length,
                            color: const Color(0xFFEF4444),
                          ),
                          const SizedBox(height: 10),
                          ...newDocs.map(_buildDocumentTile),
                        ],
                      ),
      ),
    ]);
  }

  Widget _docsSection({required String label, required int count, required Color color}) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(LucideIcons.fileText, size: 13, color: color),
      ),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800,
          color: color, letterSpacing: -0.2)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      ),
    ]);
  }

  // ── Messages ──────────────────────────────────────────────────────────────
  Widget _buildMessagesTab() {
    final newMessages = _messages.where((m) => m.isUnread).toList();
    return Column(children: [
      _tabHeader(
        'Messages',
        _unreadMsgCount > 0
            ? '$_unreadMsgCount non lu${_unreadMsgCount > 1 ? 's' : ''}'
            : 'Aucun nouveau message',
        const Color(0xFFEF4444), LucideIcons.messageSquare,
      ),
      _tabSheetContent(
        _loading
            ? _loadingWidget()
            : newMessages.isEmpty
                ? _emptyState('Aucun nouveau message', LucideIcons.messageSquare)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
                    itemCount: newMessages.length,
                    itemBuilder: (_, i) => _buildMessageTile(newMessages[i])),
      ),
    ]);
  }

  // ── Document tile ─────────────────────────────────────────────────────────
  void _openDocumentProjet(ClientDocument doc) {
    if (doc.projetId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClientProjectDetailScreen(
        projetId: doc.projetId, projetNom: doc.projetNom,
        clientEmail: _session.clientEmail, initialTabIndex: 1,
      ),
    )).then((_) { if (mounted) _loadPortalData(); });
  }

  Widget _buildDocumentTile(ClientDocument doc) {
    final cc = _kDocColors[doc.category] ?? _kOrange;
    return GestureDetector(
      onTap: () => _openDocumentProjet(doc),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: doc.isNew
            ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.25))
            : null,
        boxShadow: [
          if (doc.isNew)
            BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.07),
                blurRadius: 12, offset: const Offset(0, 4)),
          const BoxShadow(color: Color(0x07000000),
              blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: cc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(doc.icon, size: 20, color: cc),
          ),
          if (doc.isNew)
            Positioned(
              top: -4, right: -4,
              child: Container(
                width: 12, height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x44EF4444), blurRadius: 4)],
                ),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc.name, style: TextStyle(fontSize: 13,
              fontWeight: doc.isNew ? FontWeight.w700 : FontWeight.w600,
              color: _kText),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: cc.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(doc.category, style: TextStyle(fontSize: 9,
                  fontWeight: FontWeight.w800, color: cc)),
            ),
            if (doc.isNew) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('NOUVEAU', style: TextStyle(color: Colors.white,
                    fontSize: 8, fontWeight: FontWeight.w800)),
              ),
            ] else if (doc.date.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(doc.date, style: const TextStyle(fontSize: 10, color: _kMuted)),
            ],
          ]),
        ])),
        const SizedBox(width: 8),
        Icon(LucideIcons.chevronRight, size: 14,
            color: doc.isNew
                ? const Color(0xFFEF4444).withOpacity(0.5)
                : _kMuted.withOpacity(0.3)),
      ]),
      ),
    );
  }

  // ── Message tile ──────────────────────────────────────────────────────────
  Widget _buildMessageTile(ClientMessage msg) => GestureDetector(
    onTap: () => _openComments(msg.projetId, msg.projetNom),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface, borderRadius: BorderRadius.circular(16),
        border: msg.isUnread ? Border.all(color: _kOrange.withOpacity(0.2)) : null,
        boxShadow: [
          if (msg.isUnread) BoxShadow(color: _kOrange.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4)),
          const BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(radius: 20, backgroundColor: msg.avatarColor,
            child: Text(msg.initials, style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w800))),
          if (msg.isUnread) Positioned(bottom: 0, right: 0,
            child: Container(width: 11, height: 11,
              decoration: BoxDecoration(color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(msg.senderName, style: TextStyle(fontSize: 13,
                fontWeight: msg.isUnread ? FontWeight.w800 : FontWeight.w600, color: _kText),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (msg.isUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _kOrange,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('NOUVEAU', style: TextStyle(color: Colors.white,
                    fontSize: 8, fontWeight: FontWeight.w800)),
              )
            else
              Text(msg.time, style: const TextStyle(fontSize: 10, color: _kMuted)),
          ]),
          if (msg.projetNom.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(msg.projetNom, style: TextStyle(fontSize: 10,
                color: _kOrange.withOpacity(0.8), fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 4),
          Text(msg.preview, style: TextStyle(fontSize: 12,
              color: msg.isUnread ? const Color(0xFF1E293B) : _kMuted,
              fontWeight: msg.isUnread ? FontWeight.w500 : FontWeight.w400),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (msg.isUnread) ...[
            const SizedBox(height: 4),
            Text(msg.time, style: const TextStyle(fontSize: 10, color: _kMuted)),
          ],
        ])),
        const SizedBox(width: 4),
        Icon(LucideIcons.chevronRight, size: 14, color: _kMuted.withOpacity(0.4)),
      ]),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // PROFILE TAB
  // ══════════════════════════════════════════════════════════════════════════

  void _showChangePasswordDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(
        session: _session,
        onSuccess: (updated) {
          setState(() => _session = updated);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Mot de passe mis à jour'),
            backgroundColor: _kOrange,
          ));
        },
      ),
    );
  }

  Widget _buildProfileTab() => SingleChildScrollView(
    child: Column(children: [
      // Bannière navy
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
        color: _kNavy,
        child: Column(children: [
          Container(
            width: 78, height: 78,
            decoration: BoxDecoration(
              color: _kOrange, borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: _kOrange.withOpacity(0.45),
                  blurRadius: 22, offset: const Offset(0, 6))],
            ),
            child: Center(child: Text(_initials(_session.clientNom),
                style: const TextStyle(color: Colors.white, fontSize: 26,
                    fontWeight: FontWeight.w900))),
          ),
          const SizedBox(height: 14),
          Text(_session.clientNom, style: const TextStyle(fontSize: 20,
              fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text(_session.clientEmail,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _pStat('${_projects.length}', 'Projets'),
            Container(width: 1, height: 30, color: Colors.white.withOpacity(0.12),
                margin: const EdgeInsets.symmetric(horizontal: 22)),
            _pStat('${_documents.length}', 'Documents'),
            Container(width: 1, height: 30, color: Colors.white.withOpacity(0.12),
                margin: const EdgeInsets.symmetric(horizontal: 22)),
            _pStat('${_messages.length}', 'Messages'),
          ]),
        ]),
      ),

      Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.vertical(top: _kSheetRadius),
          ),
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
          child: Column(children: [
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('INFORMATIONS', style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _kMuted.withOpacity(0.6), letterSpacing: 1.0)),
              const SizedBox(height: 16),
              _pRow(LucideIcons.user, 'Nom', _session.clientNom),
              const Divider(height: 20, color: _kBorder),
              _pRow(LucideIcons.mail, 'Email', _session.clientEmail),
              const Divider(height: 20, color: _kBorder),
              _pRow(LucideIcons.phone, 'Téléphone',
                  _session.telephone?.isNotEmpty == true ? _session.telephone! : '—'),
            ])),
            const SizedBox(height: 12),
            _card(child: Column(children: [
              _pAction(LucideIcons.lock, 'Changer le mot de passe', _kOrange,
                  _showChangePasswordDialog),
              const Divider(height: 1, color: _kBorder, indent: 52),
              _pAction(LucideIcons.logOut, 'Se déconnecter',
                  const Color(0xFFEF4444), _logout),
            ])),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    ]),
  );

  Widget _pStat(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
        color: Colors.white)),
    const SizedBox(height: 2),
    Text(l, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.45),
        fontWeight: FontWeight.w500)),
  ]);

  Widget _pRow(IconData icon, String label, String value) => Row(children: [
    Container(width: 36, height: 36,
        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 16, color: _kMuted)),
    const SizedBox(width: 13),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: _kMuted,
          fontWeight: FontWeight.w600, letterSpacing: 0.2)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
          color: _kText), maxLines: 1, overflow: TextOverflow.ellipsis),
    ])),
  ]);

  Widget _pAction(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 17, color: color)),
            const SizedBox(width: 13),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w600, color: color))),
            Icon(LucideIcons.chevronRight, size: 15, color: color.withOpacity(0.35)),
          ]),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _kSurface, borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x09000000),
          blurRadius: 14, offset: Offset(0, 4))],
    ),
    child: child,
  );

  Widget _loadingWidget() => const Center(child: Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2.5),
  ));

  Widget _emptyInline(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(msg, style: const TextStyle(fontSize: 13, color: _kMuted)),
  );

  Widget _emptyState(String msg, IconData icon) => Center(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 70, height: 70,
        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, size: 28, color: _kMuted.withOpacity(0.45)),
      ),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
          color: _kMuted)),
    ]),
  ));

  void _openComments(String projetId, String projetNom) {
    if (projetId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClientProjectDetailScreen(
        projetId: projetId, projetNom: projetNom,
        clientEmail: _session.clientEmail, initialTabIndex: 2,
      ),
    )).then((_) { if (mounted) _loadPortalData(); });
  }

  Future<void> _onTabSelected(int index) async {
    setState(() => _selectedIndex = index);
    final now   = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    // Save timestamp for next session without resetting isNew/isUnread in current session
    if (index == 3) {
      await prefs.setString('last_msg_read_${_session.id}', now.toIso8601String());
    } else if (index == 2) {
      await prefs.setString('last_doc_read_${_session.id}', now.toIso8601String());
    }
  }

  Future<void> _logout() async {
    try { await ClientAuthService.logout(); } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientLoginScreen()));
  }
}

// ── Change Password Bottom Sheet ──────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  final ClientSession session;
  final void Function(ClientSession) onSuccess;
  const _ChangePasswordSheet({required this.session, required this.onSuccess});
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showNew     = false;
  bool _showConfirm = false;
  bool _loading     = false;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (newPass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs.');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client
          .from('client_portal_access')
          .update({'password_raw': newPass, 'password_changed': true})
          .eq('id', widget.session.id);

      final updated = ClientSession(
        id: widget.session.id,
        projetId: widget.session.projetId,
        clientNom: widget.session.clientNom,
        clientEmail: widget.session.clientEmail,
        passwordChanged: true,
        telephone: widget.session.telephone,
      );
      await ClientAuthService.saveSession(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur : ${e.toString().replaceAll('Exception: ', '')}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _SheetHandle(),
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.lock, size: 18, color: Color(0xFFF97316)),
          ),
          const SizedBox(width: 12),
          const Text('Changer le mot de passe',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: Color(0xFF0B1437))),
        ]),
        const SizedBox(height: 20),
        _SheetField(
          ctrl: _newCtrl,
          label: 'Nouveau mot de passe',
          hint: 'Minimum 8 caractères',
          obscure: !_showNew,
          showToggle: true,
          onToggle: () => setState(() => _showNew = !_showNew),
        ),
        const SizedBox(height: 12),
        _SheetField(
          ctrl: _confirmCtrl,
          label: 'Confirmer le mot de passe',
          hint: 'Répétez le mot de passe',
          obscure: !_showConfirm,
          showToggle: true,
          onToggle: () => setState(() => _showConfirm = !_showConfirm),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _SheetError(_error!),
        ],
        const SizedBox(height: 20),
        _SheetButton(label: 'Confirmer', loading: _loading, onTap: _submit),
      ]),
    );
  }
}

// ── Shared sheet widgets ──────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 38, height: 4,
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: const Color(0xFFE2E8F0),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool obscure, showToggle;
  final VoidCallback? onToggle;
  final TextInputType? keyboardType;
  const _SheetField({
    required this.ctrl, required this.label, required this.hint,
    this.obscure = false, this.showToggle = false, this.onToggle,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: Color(0xFF64748B), letterSpacing: 0.2)),
      const SizedBox(height: 7),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0B1437)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
          suffixIcon: showToggle && onToggle != null
              ? GestureDetector(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(
                      obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 18, color: const Color(0xFF64748B),
                    ),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF97316), width: 2)),
        ),
      ),
    ]);
  }
}

class _SheetError extends StatelessWidget {
  final String message;
  const _SheetError(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(LucideIcons.alertCircle, size: 14, color: Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
      ]),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _SheetButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF97316),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Badge de navigation ───────────────────────────────────────────────────────
class _NavBadge extends StatelessWidget {
  final int count;
  const _NavBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count > 9 ? '9+' : '$count';
    final wide  = count > 9;
    return Container(
      width:  wide ? null : 18,
      height: 18,
      padding: wide ? const EdgeInsets.symmetric(horizontal: 5) : null,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _kNavBar, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.55),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              height: 1.0,
            )),
      ),
    );
  }
}