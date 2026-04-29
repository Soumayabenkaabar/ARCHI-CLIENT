// lib/screens/client_portal_screen.dart
import 'package:archi_client/screens/client_project_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/client_auth_service.dart';
import '../service/client_portal_service.dart';
import 'client_change_password_screen.dart';
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
  final IconData icon;
  final bool isNew;
  final int uploadedAtMs;
  const ClientDocument({
    required this.name, required this.category, required this.date, required this.icon,
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
const _kOrange  = Color(0xFFF97316);
const _kBg      = Color(0xFFF1F5FF);
const _kSurface = Colors.white;
const _kText    = Color(0xFF0B1437);
const _kMuted   = Color(0xFF64748B);
const _kBorder  = Color(0xFFE2E8F0);

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
  int _selectedIndex = 0;
  List<ClientProject> _projects  = [];
  List<ClientDocument> _documents = [];
  List<ClientMessage>  _messages  = [];
  bool _loading = true;
  String? _docsError;
  DateTime _lastMsgRead = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDocRead = DateTime.fromMillisecondsSinceEpoch(0);

  int get _unreadMsgCount => _messages.where((m) => m.isUnread).length;
  int get _newDocCount    => _documents.where((d) => d.isNew).length;

  @override
  void initState() {
    super.initState();
    _loadPortalData();
  }

  Future<void> _loadPortalData() async {
    final prefs = await SharedPreferences.getInstance();
    final msgTs = prefs.getString('last_msg_read_${widget.session.id}');
    final docTs = prefs.getString('last_doc_read_${widget.session.id}');
    _lastMsgRead = msgTs != null ? DateTime.tryParse(msgTs) ?? _lastMsgRead : _lastMsgRead;
    _lastDocRead = docTs != null ? DateTime.tryParse(docTs) ?? _lastDocRead : _lastDocRead;

    final projetsData = await ClientPortalService
        .getProjetsForClient(widget.session.clientEmail)
        .catchError((_) => <Map<String, dynamic>>[]);

    List<Map<String, dynamic>> docsData = [];
    String? docsErr;
    try {
      docsData = await ClientPortalService.getRecentDocuments(widget.session.clientEmail);
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
    msgsData.sort((a, b) => ((b['created_at'] as String?) ?? '').compareTo((a['created_at'] as String?) ?? ''));

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

  static const _months = ['janv.','févr.','mars','avril','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
  String _formatFullDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try { final d = DateTime.parse(iso); return '${d.day} ${_months[d.month - 1]}'; } catch (_) { return ''; }
  }

  static const _docTypeLabels = {
    'pdf': 'PDF', 'image': 'Image', 'img': 'Image', 'jpg': 'Image', 'jpeg': 'Image', 'png': 'Image',
    'dwg': 'Plan', 'cad': 'Plan', 'docx': 'Word', 'doc': 'Word', 'xlsx': 'Excel', 'xls': 'Excel',
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
      isNew: uploadedMs > 0 && uploadedMs > _lastDocRead.millisecondsSinceEpoch,
    );
  }

  static const _roleLabels = {
    'architecte': 'Architecte', 'client': 'Client',
    'chef_projet': 'Chef de projet', 'chef': 'Chef de projet',
  };
  static const _avatarColors = [
    Color(0xFFF97316), Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFEF4444),
  ];

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
  Color _avatarColor(String name) =>
      _avatarColors[name.codeUnits.fold(0, (a, b) => a + b) % _avatarColors.length];

  ClientMessage _mapMessage(Map<String, dynamic> d) {
    final auteur = (d['auteur'] as String?) ?? 'Inconnu';
    final role   = (d['role']   as String?) ?? 'client';
    final createdIso = (d['created_at'] as String?) ?? '';
    int createdMs = 0;
    try { createdMs = DateTime.parse(createdIso).millisecondsSinceEpoch; } catch (_) {}
    return ClientMessage(
      senderName: auteur, senderRole: _roleLabels[role.toLowerCase()] ?? role,
      initials: _initials(auteur), preview: (d['contenu'] as String?) ?? '',
      time: _relativeDate(createdIso),
      isUnread: createdMs > 0 && createdMs > _lastMsgRead.millisecondsSinceEpoch,
      avatarColor: _avatarColor(auteur),
      projetId: (d['_projet_id'] as String?) ?? '', projetNom: (d['_projet_nom'] as String?) ?? '',
      createdAtMs: createdMs,
    );
  }

  final List<(IconData, String)> _navItems = const [
    (LucideIcons.layoutDashboard, 'Accueil'),
    (LucideIcons.folderOpen, 'Projets'),
    (LucideIcons.fileText, 'Documents'),
    (LucideIcons.messageSquare, 'Messages'),
    (LucideIcons.userCircle, 'Profil'),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_loading && _projects.isEmpty) return _buildNoProjectScreen();
    final isWide = MediaQuery.of(context).size.width > 860;
    return Scaffold(
      backgroundColor: _kBg,
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
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Votre architecte va associer votre projet.\nContactez-le pour plus d\'informations.',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.7),
          textAlign: TextAlign.center),
        const SizedBox(height: 44),
        TextButton.icon(
          onPressed: _logout,
          icon: Icon(LucideIcons.logOut, size: 14, color: Colors.white.withOpacity(0.4)),
          label: Text('Déconnexion', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
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

  // ── Top bar desktop ───────────────────────────────────────────────────────
  Widget _buildTopBar() => Container(
    height: 62,
    color: _kNavy,
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Row(children: [
      // Logo
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _kOrange, borderRadius: BorderRadius.circular(9)),
          child: const Icon(LucideIcons.building2, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 10),
        const Text('Portail Client', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
      const SizedBox(width: 40),
      // Nav
      Expanded(child: Row(children: List.generate(_navItems.length, (i) {
        final (icon, label) = _navItems[i];
        final sel = i == _selectedIndex;
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
                Icon(icon, size: 14, color: sel ? _kOrange : Colors.white.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    color: sel ? _kOrange : Colors.white.withOpacity(0.5))),
              ]),
            ),
            if (badge > 0) Positioned(top: -4, right: -2,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                child: Center(child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
              )),
          ]),
        );
      }))),
      // Logout
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
            Text('Déconnexion', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    ]),
  );

  // ── Mobile header ─────────────────────────────────────────────────────────
  Widget _buildMobileHeader() => Container(
    decoration: BoxDecoration(
      color: _kNavy,
      boxShadow: [BoxShadow(color: _kNavy.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20, bottom: 14),
    child: Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: _kOrange, borderRadius: BorderRadius.circular(10)),
        child: const Icon(LucideIcons.building2, color: Colors.white, size: 17),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Text('Portail Client',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
      GestureDetector(
        onTap: () => _onTabSelected(4),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kOrange,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _kOrange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Center(child: Text(_initials(widget.session.clientNom),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
        ),
      ),
    ]),
  );

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, -4))],
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(children: List.generate(_navItems.length, (i) {
        final (icon, label) = _navItems[i];
        final sel = i == _selectedIndex;
        final badge = i == 3 ? _unreadMsgCount : (i == 2 ? _newDocCount : 0);
        return Expanded(
          child: GestureDetector(
            onTap: () => _onTabSelected(i),
            behavior: HitTestBehavior.opaque,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: sel ? 44 : 40,
                  height: sel ? 32 : 28,
                  decoration: BoxDecoration(
                    color: sel ? _kOrange.withOpacity(0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: sel ? _kOrange : Colors.white.withOpacity(0.38)),
                ),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(
                  fontSize: 9, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  color: sel ? _kOrange : Colors.white.withOpacity(0.35),
                )),
              ]),
              if (badge > 0) Positioned(top: 0, right: (MediaQuery.of(context).size.width / _navItems.length - 44) / 2 + 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(8)),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                )),
            ]),
          ),
        );
      })),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DASHBOARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboard({required bool isWide}) => SingleChildScrollView(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHero(),
      Padding(
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
    ]),
  );

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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [_kOrange.withOpacity(0.15), _kOrange.withOpacity(0)]),
        ),
      )),
      Positioned(left: -50, bottom: -20, child: Container(
        width: 180, height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [const Color(0xFF3B82F6).withOpacity(0.12), const Color(0xFF3B82F6).withOpacity(0)]),
        ),
      )),
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bonjour,', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w400)),
                const SizedBox(height: 3),
                Text(widget.session.clientNom,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.6, height: 1.1),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              GestureDetector(
                onTap: () => _onTabSelected(4),
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: _kOrange,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: _kOrange.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 5))],
                  ),
                  child: Center(child: Text(_initials(widget.session.clientNom),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              _heroChip('${_projects.length}', 'Projets', LucideIcons.folderOpen, _kOrange, () => _onTabSelected(1)),
              const SizedBox(width: 10),
              _heroChip('${_documents.length}', 'Documents', LucideIcons.fileText, const Color(0xFF60A5FA), () => _onTabSelected(2)),
              const SizedBox(width: 10),
              _heroChip(
                _unreadMsgCount > 0 ? '$_unreadMsgCount' : '${_messages.length}',
                _unreadMsgCount > 0 ? 'Non lus' : 'Messages',
                LucideIcons.messageSquare, const Color(0xFFA78BFA), () => _onTabSelected(3)),
            ]),
          ]),
        ),
      ),
    ]),
  );

  Widget _heroChip(String count, String label, IconData icon, Color color, VoidCallback onTap) =>
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
            decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 10),
          Text(count, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.45), fontWeight: FontWeight.w500)),
        ]),
      ),
    ));

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, [VoidCallback? onTap]) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kText, letterSpacing: -0.4)),
      if (onTap != null)
        GestureDetector(
          onTap: onTap,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Voir tout', style: TextStyle(fontSize: 13, color: _kOrange.withOpacity(0.9), fontWeight: FontWeight.w600)),
            const SizedBox(width: 3),
            Icon(LucideIcons.arrowRight, size: 13, color: _kOrange.withOpacity(0.9)),
          ]),
        ),
    ],
  );

  // ── Project card ──────────────────────────────────────────────────────────
  Widget _buildProjectCard(ClientProject project) {
    final sc = _kStatutColors[project.statut] ?? _kOrange;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientProjectDetailScreen(
        projetId: project.id, projetNom: project.name, clientEmail: widget.session.clientEmail,
      ))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: sc.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 6)),
            const BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(project.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kText, letterSpacing: -0.3),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(project.phase, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
              ]),
            ),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            Icon(LucideIcons.clock, size: 11, color: _kMuted.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text(project.lastUpdate, style: TextStyle(fontSize: 11, color: _kMuted.withOpacity(0.7))),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Avancement', style: TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w500)),
            Text('${project.progress}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: sc)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: project.progress / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5FF),
              valueColor: AlwaysStoppedAnimation<Color>(sc),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Recent docs card ──────────────────────────────────────────────────────
  Widget _buildRecentDocs() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Documents récents', () => _onTabSelected(2)),
      const SizedBox(height: 16),
      if (_loading) _loadingWidget()
      else if (_docsError != null) Text('Erreur', style: TextStyle(fontSize: 12, color: Colors.red.shade400))
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
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: cc.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(doc.icon, size: 17, color: cc),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(doc.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: cc.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
            child: Text(doc.category, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: cc)),
          ),
          if (doc.isNew) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(5)),
              child: const Text('NOUVEAU', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
            ),
          ] else if (doc.date.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(doc.date, style: const TextStyle(fontSize: 10, color: _kMuted)),
          ],
        ]),
      ])),
    ]);
  }

  // ── Recent messages card ──────────────────────────────────────────────────
  Widget _buildRecentMsgs() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Messages récents', _messages.isNotEmpty ? () => _onTabSelected(3) : null),
      const SizedBox(height: 16),
      if (_loading) _loadingWidget()
      else if (_messages.isEmpty) _emptyInline('Aucun message')
      else ..._messages.take(3).toList().asMap().entries.map((e) => Column(children: [
        if (e.key > 0) const Divider(height: 16, color: _kBorder),
        _msgRow(e.value),
      ])),
    ]),
  );

  Widget _msgRow(ClientMessage msg) => GestureDetector(
    onTap: () => _openComments(msg.projetId, msg.projetNom),
    child: Row(children: [
      Stack(clipBehavior: Clip.none, children: [
        CircleAvatar(radius: 18, backgroundColor: msg.avatarColor,
          child: Text(msg.initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
        if (msg.isUnread) Positioned(bottom: 0, right: 0,
          child: Container(width: 9, height: 9, decoration: BoxDecoration(
            color: const Color(0xFFEF4444), shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5)))),
      ]),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(msg.senderName, style: TextStyle(fontSize: 12, fontWeight: msg.isUnread ? FontWeight.w800 : FontWeight.w600, color: _kText), maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (msg.isUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(6)),
              child: const Text('NOUVEAU', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800)),
            )
          else
            Text(msg.time, style: const TextStyle(fontSize: 10, color: _kMuted)),
        ]),
        const SizedBox(height: 2),
        Text(msg.preview, style: TextStyle(fontSize: 11, color: _kMuted, fontWeight: msg.isUnread ? FontWeight.w500 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      const SizedBox(width: 4),
      Icon(LucideIcons.chevronRight, size: 13, color: _kMuted.withOpacity(0.4)),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TABS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildProjectsTab() => Column(children: [
    _tabHeader('Mes Projets', '${_projects.length} projet${_projects.length > 1 ? 's' : ''}', _kOrange, LucideIcons.folderOpen),
    Expanded(child: _loading ? _loadingWidget()
      : _projects.isEmpty ? _emptyState('Aucun projet assigné', LucideIcons.folderOpen)
      : ListView.builder(padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          itemCount: _projects.length, itemBuilder: (_, i) => _buildProjectCard(_projects[i]))),
  ]);

  Widget _buildDocumentsTab() => Column(children: [
    _tabHeader('Documents', '${_documents.length} fichier${_documents.length > 1 ? 's' : ''}', const Color(0xFF3B82F6), LucideIcons.fileText),
    Expanded(child: _loading ? _loadingWidget()
      : _docsError != null ? Center(child: Text('Erreur : $_docsError', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)))
      : _documents.isEmpty ? _emptyState('Aucun document', LucideIcons.fileText)
      : ListView.builder(padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          itemCount: _documents.length, itemBuilder: (_, i) => _buildDocumentTile(_documents[i]))),
  ]);

  Widget _buildMessagesTab() => Column(children: [
    _tabHeader('Messages',
      _unreadMsgCount > 0 ? '$_unreadMsgCount non lu${_unreadMsgCount > 1 ? 's' : ''}' : '${_messages.length} message${_messages.length > 1 ? 's' : ''}',
      const Color(0xFFEF4444), LucideIcons.messageSquare),
    Expanded(child: _loading ? _loadingWidget()
      : _messages.isEmpty ? _emptyState('Aucun message', LucideIcons.messageSquare)
      : ListView.builder(padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          itemCount: _messages.length, itemBuilder: (_, i) => _buildMessageTile(_messages[i]))),
  ]);

  Widget _tabHeader(String title, String sub, Color color, IconData icon) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: BoxDecoration(
      color: _kNavy,
      boxShadow: [BoxShadow(color: _kNavy.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 3))],
    ),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Icon(icon, size: 20, color: color),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    ]),
  );

  // ── Document tile ─────────────────────────────────────────────────────────
  Widget _buildDocumentTile(ClientDocument doc) {
    final cc = _kDocColors[doc.category] ?? _kOrange;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface, borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: cc.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(doc.icon, size: 20, color: cc),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc.name, style: TextStyle(fontSize: 13, fontWeight: doc.isNew ? FontWeight.w700 : FontWeight.w600, color: _kText), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: cc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(doc.category, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: cc)),
            ),
            if (doc.isNew) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                child: const Text('NOUVEAU', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
              ),
            ] else if (doc.date.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(doc.date, style: const TextStyle(fontSize: 10, color: _kMuted)),
            ],
          ]),
        ])),
      ]),
    );
  }

  // ── Message tile ──────────────────────────────────────────────────────────
  Widget _buildMessageTile(ClientMessage msg) => GestureDetector(
    onTap: () => _openComments(msg.projetId, msg.projetNom),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: msg.isUnread ? Border.all(color: _kOrange.withOpacity(0.2)) : null,
        boxShadow: [
          if (msg.isUnread) BoxShadow(color: _kOrange.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
          const BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(radius: 20, backgroundColor: msg.avatarColor,
            child: Text(msg.initials, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
          if (msg.isUnread) Positioned(bottom: 0, right: 0,
            child: Container(width: 11, height: 11,
              decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5)))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(msg.senderName, style: TextStyle(fontSize: 13, fontWeight: msg.isUnread ? FontWeight.w800 : FontWeight.w600, color: _kText), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (msg.isUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _kOrange, borderRadius: BorderRadius.circular(8)),
                child: const Text('NOUVEAU', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
              )
            else
              Text(msg.time, style: const TextStyle(fontSize: 10, color: _kMuted)),
          ]),
          if (msg.projetNom.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(msg.projetNom, style: TextStyle(fontSize: 10, color: _kOrange.withOpacity(0.8), fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 4),
          Text(msg.preview, style: TextStyle(fontSize: 12, color: msg.isUnread ? const Color(0xFF1E293B) : _kMuted,
              fontWeight: msg.isUnread ? FontWeight.w500 : FontWeight.w400), maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _buildProfileTab() => SingleChildScrollView(
    child: Column(children: [
      // Banner navy
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 56),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B1437), Color(0xFF162050)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Column(children: [
          Container(
            width: 78, height: 78,
            decoration: BoxDecoration(
              color: _kOrange, borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: _kOrange.withOpacity(0.45), blurRadius: 22, offset: const Offset(0, 6))],
            ),
            child: Center(child: Text(_initials(widget.session.clientNom),
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(height: 14),
          Text(widget.session.clientNom,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text(widget.session.clientEmail, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _pStat('${_projects.length}', 'Projets'),
            Container(width: 1, height: 30, color: Colors.white.withOpacity(0.12), margin: const EdgeInsets.symmetric(horizontal: 22)),
            _pStat('${_documents.length}', 'Documents'),
            Container(width: 1, height: 30, color: Colors.white.withOpacity(0.12), margin: const EdgeInsets.symmetric(horizontal: 22)),
            _pStat('${_messages.length}', 'Messages'),
          ]),
        ]),
      ),
      // Floating cards
      Transform.translate(
        offset: const Offset(0, -24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(children: [
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('INFORMATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kMuted.withOpacity(0.6), letterSpacing: 1.0)),
              const SizedBox(height: 16),
              _pRow(LucideIcons.user, 'Nom', widget.session.clientNom),
              const Divider(height: 20, color: _kBorder),
              _pRow(LucideIcons.mail, 'Email', widget.session.clientEmail),
            ])),
            const SizedBox(height: 12),
            _card(child: Column(children: [
              _pAction(LucideIcons.lock, 'Changer le mot de passe', _kOrange,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientChangePasswordScreen(session: widget.session)))),
              const Divider(height: 1, color: _kBorder, indent: 52),
              _pAction(LucideIcons.logOut, 'Se déconnecter', const Color(0xFFEF4444), _logout),
            ])),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    ]),
  );

  Widget _pStat(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
    const SizedBox(height: 2),
    Text(l, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.45), fontWeight: FontWeight.w500)),
  ]);

  Widget _pRow(IconData icon, String label, String value) => Row(children: [
    Container(width: 36, height: 36, decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 16, color: _kMuted)),
    const SizedBox(width: 13),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kText), maxLines: 1, overflow: TextOverflow.ellipsis),
    ])),
  ]);

  Widget _pAction(IconData icon, String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: color)),
          const SizedBox(width: 13),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color))),
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
      color: _kSurface,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 14, offset: Offset(0, 4))],
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
      Text(msg, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kMuted)),
    ]),
  ));

  void _openComments(String projetId, String projetNom) {
    if (projetId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClientProjectDetailScreen(
        projetId: projetId, projetNom: projetNom,
        clientEmail: widget.session.clientEmail, initialTabIndex: 2,
      ),
    ));
  }

  Future<void> _onTabSelected(int index) async {
    setState(() => _selectedIndex = index);
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    if (index == 3) {
      await prefs.setString('last_msg_read_${widget.session.id}', now.toIso8601String());
      if (!mounted) return;
      setState(() {
        _lastMsgRead = now;
        _messages = _messages.map((m) => ClientMessage(
          senderName: m.senderName, senderRole: m.senderRole, initials: m.initials,
          preview: m.preview, time: m.time, isUnread: false,
          avatarColor: m.avatarColor, projetId: m.projetId, projetNom: m.projetNom, createdAtMs: m.createdAtMs,
        )).toList();
      });
    } else if (index == 2) {
      await prefs.setString('last_doc_read_${widget.session.id}', now.toIso8601String());
      if (!mounted) return;
      setState(() {
        _lastDocRead = now;
        _documents = _documents.map((d) => ClientDocument(
          name: d.name, category: d.category, date: d.date, icon: d.icon,
          isNew: false, uploadedAtMs: d.uploadedAtMs,
        )).toList();
      });
    }
  }

  Future<void> _logout() async {
    try { await ClientAuthService.logout(); } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ClientLoginScreen()));
  }
}
