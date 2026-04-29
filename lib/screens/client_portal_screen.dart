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
  final String id, name, phase, lastUpdate;
  final int progress, newItems;
  const ClientProject({
    required this.id, required this.name, required this.phase,
    required this.progress, required this.lastUpdate, required this.newItems,
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



// ── Constantes ────────────────────────────────────────────────────────────────
const _kBg            = Color(0xFFF5F5F5);
const _kSurface       = Colors.white;
const _kDark          = Color(0xFF0A0E1A);
const _kAccentOrange  = Color(0xFFFF8C00);
const _kTextSecondary = Color(0xFF6B7280);

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
    // Charge les timestamps "lu jusqu'à" depuis les préférences
    final prefs = await SharedPreferences.getInstance();
    final msgTs = prefs.getString('last_msg_read_${widget.session.id}');
    final docTs = prefs.getString('last_doc_read_${widget.session.id}');
    _lastMsgRead = msgTs != null ? DateTime.tryParse(msgTs) ?? _lastMsgRead : _lastMsgRead;
    _lastDocRead = docTs != null ? DateTime.tryParse(docTs) ?? _lastDocRead : _lastDocRead;

    // Charge tous les projets accessibles par cet email
    final projetsData = await ClientPortalService
        .getProjetsForClient(widget.session.clientEmail)
        .catchError((_) => <Map<String, dynamic>>[]);

    List<Map<String, dynamic>> docsData = [];
    String? docsErr;
    try {
      docsData = await ClientPortalService.getRecentDocuments(widget.session.clientEmail);
    } catch (e) {
      docsErr = e.toString();
    }

    // Messages pour chacun des projets — enrichis avec projet_id et projet_nom
    final msgsData = <Map<String, dynamic>>[];
    for (final p in projetsData.take(5)) {
      final msgs = await ClientPortalService
          .getRecentMessages(p['id'].toString(), limit: 5)
          .catchError((_) => <Map<String, dynamic>>[]);
      for (final m in msgs) {
        msgsData.add({
          ...m,
          '_projet_id':  p['id'].toString(),
          '_projet_nom': (p['titre'] as String?) ?? '',
        });
      }
    }
    // Tri chronologique inverse (plus récent en premier)
    msgsData.sort((a, b) {
      final aD = (a['created_at'] as String?) ?? '';
      final bD = (b['created_at'] as String?) ?? '';
      return bD.compareTo(aD);
    });

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
    'en_cours':   'En cours',
    'en_attente': 'En attente',
    'termine':    'Terminé',
    'annule':     'Annulé',
  };

  ClientProject _mapProjet(Map<String, dynamic> d) {
    final statut = (d['statut'] as String?) ?? 'en_cours';
    return ClientProject(
      id:         d['id'].toString(),
      name:       (d['titre'] as String?) ?? 'Mon projet',
      phase:      _statutLabels[statut] ?? statut,
      progress:   (d['avancement'] as num?)?.toInt() ?? 0,
      lastUpdate: _relativeDate((d['created_at'] as String?) ?? ''),
      newItems:   0,
    );
  }

  String _relativeDate(String iso) {
    if (iso.isEmpty) return 'Récemment';
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inDays == 0) return 'Aujourd\'hui';
      if (diff.inDays == 1) return 'Hier';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
      if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()} semaine${(diff.inDays / 7).floor() > 1 ? 's' : ''}';
      return 'Il y a ${(diff.inDays / 30).floor()} mois';
    } catch (_) {
      return 'Récemment';
    }
  }

  static const _months = ['janv.','févr.','mars','avril','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];

  String _formatFullDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day} ${_months[d.month - 1]} ${d.year}';
    } catch (_) { return ''; }
  }

  static const _docTypeLabels = {
    'pdf': 'PDF', 'image': 'Image', 'img': 'Image',
    'jpg': 'Image', 'jpeg': 'Image', 'png': 'Image',
    'dwg': 'Plan', 'cad': 'Plan',
    'docx': 'Word', 'doc': 'Word',
    'xlsx': 'Excel', 'xls': 'Excel',
  };

  IconData _docIcon(String type) {
    final t = type.toLowerCase();
    if (['image','img','jpg','jpeg','png'].contains(t)) return LucideIcons.image;
    if (['dwg','cad'].contains(t)) return LucideIcons.fileText;
    return LucideIcons.fileText;
  }

  String _cleanDocName(String raw) {
    // Format stocké : "2||META||nom_fichier.pdf" ou variantes
    if (raw.contains('||META||')) {
      final afterMeta = raw.split('||META||').last;
      return afterMeta.split('||').first.trim();
    }
    if (raw.contains('||')) {
      return raw.split('||').last.trim();
    }
    return raw;
  }

  ClientDocument _mapDocument(Map<String, dynamic> d) {
    final type = (d['type'] as String?) ?? 'pdf';
    final rawNom = (d['nom'] as String?) ?? 'Document';
    final uploadedIso = (d['uploaded_at'] as String?) ?? '';
    int uploadedMs = 0;
    try { uploadedMs = DateTime.parse(uploadedIso).millisecondsSinceEpoch; } catch (_) {}
    return ClientDocument(
      name:         _cleanDocName(rawNom),
      category:     _docTypeLabels[type.toLowerCase()] ?? type.toUpperCase(),
      date:         _formatFullDate(uploadedIso.isNotEmpty ? uploadedIso : null),
      icon:         _docIcon(type),
      uploadedAtMs: uploadedMs,
      isNew:        uploadedMs > 0 && uploadedMs > _lastDocRead.millisecondsSinceEpoch,
    );
  }

  static const _roleLabels = {
    'architecte': 'Architecte', 'client': 'Client',
    'chef_projet': 'Chef de projet', 'chef': 'Chef de projet',
  };

  static const _avatarColors = [
    Color(0xFFFF8C00), Color(0xFF3B82F6), Color(0xFF10B981),
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
    final auteur    = (d['auteur'] as String?) ?? 'Inconnu';
    final role      = (d['role']   as String?) ?? 'client';
    final createdIso = (d['created_at'] as String?) ?? '';
    int createdMs = 0;
    try { createdMs = DateTime.parse(createdIso).millisecondsSinceEpoch; } catch (_) {}
    return ClientMessage(
      senderName:  auteur,
      senderRole:  _roleLabels[role.toLowerCase()] ?? role,
      initials:    _initials(auteur),
      preview:     (d['contenu'] as String?) ?? '',
      time:        _relativeDate(createdIso),
      isUnread:    createdMs > 0 && createdMs > _lastMsgRead.millisecondsSinceEpoch,
      avatarColor: _avatarColor(auteur),
      projetId:    (d['_projet_id']  as String?) ?? '',
      projetNom:   (d['_projet_nom'] as String?) ?? '',
      createdAtMs: createdMs,
    );
  }

  final List<(IconData, String)> _navItems = const [
    (LucideIcons.layoutDashboard, 'Tableau de bord'),
    (LucideIcons.folderOpen, 'Mes Projets'),
    (LucideIcons.fileText, 'Documents'),
    (LucideIcons.messageSquare, 'Messages'),
    (LucideIcons.userCircle, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    // ── GARDE : aucun projet trouvé après chargement ─────────────────────────
    if (!_loading && _projects.isEmpty) {
      return _buildNoProjectScreen();
    }

    final size = MediaQuery.of(context).size;
    final isWide = size.width > 860;
    return Scaffold(
      backgroundColor: _kBg,
      body: isWide ? _buildDesktop() : _buildMobile(),
    );
  }

  // ── Écran "projet non encore assigné" ────────────────────────────────────
  Widget _buildNoProjectScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _kAccentOrange,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: _kAccentOrange.withOpacity(0.4), blurRadius: 16)],
                  ),
                  child: const Icon(LucideIcons.building2, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 32),
                // Icône état
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(LucideIcons.clock, size: 32, color: _kAccentOrange.withOpacity(0.8)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Projet en cours d\'assignation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Votre compte a bien été créé.\nVotre architecte va associer votre compte à votre projet.\n\nContactez-le pour plus d\'informations.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    height: 1.7,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Info client
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.user, size: 13, color: Colors.white.withOpacity(0.4)),
                    const SizedBox(width: 8),
                    Text(
                      widget.session.clientNom,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
                const SizedBox(height: 40),
                // Bouton déconnexion
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: Icon(LucideIcons.logOut, size: 14, color: Colors.white.withOpacity(0.5)),
                  label: Text('Se déconnecter',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  // ── Sélecteur de contenu selon l'onglet actif ─────────────────────────────
  Widget _buildContent({required bool isWide}) {
    switch (_selectedIndex) {
      case 1: return _buildProjectsTab();
      case 2: return _buildDocumentsTab();
      case 3: return _buildMessagesTab();
      case 4: return _buildProfileTab();
      default: return _buildDashboardContent(isWide: isWide);
    }
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 64,
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: _kAccentOrange, borderRadius: BorderRadius.circular(8)),
          child: const Icon(LucideIcons.building2, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Portail Client', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kDark)),
          const Text("Cabinet d'Architecture", style: TextStyle(fontSize: 10, color: _kTextSecondary)),
        ]),
        const SizedBox(width: 40),
        Expanded(
          child: Row(
            children: List.generate(_navItems.length, (i) {
              final (icon, label) = _navItems[i];
              final isSelected = i == _selectedIndex;
              final badge = i == 3 ? _unreadMsgCount : (i == 2 ? _newDocCount : 0);
              return GestureDetector(
                onTap: () => _onTabSelected(i),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _kAccentOrange : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(icon, size: 14, color: isSelected ? Colors.white : _kTextSecondary),
                      const SizedBox(width: 6),
                      Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : _kTextSecondary)),
                    ]),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -4, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(8)),
                        child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
              );
            }),
          ),
        ),
        // Logout
        GestureDetector(
          onTap: _logout,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(LucideIcons.logOut, size: 14, color: _kTextSecondary),
              const SizedBox(width: 6),
              const Text('Déconnexion', style: TextStyle(fontSize: 12, color: _kTextSecondary, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Mobile header ─────────────────────────────────────────────────────────
 Widget _buildMobileHeader() {
  return Container(
    decoration: const BoxDecoration(
      color: _kSurface,
      boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 8,
      left: 20, right: 20, bottom: 14,
    ),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: _kAccentOrange,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: _kAccentOrange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: const Icon(LucideIcons.building2, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 10),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Portail Client', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kDark, letterSpacing: -0.3)),
        Text("Cabinet d'Architecture", style: TextStyle(fontSize: 10, color: _kTextSecondary, letterSpacing: 0.2)),
      ]),
      const Spacer(),
      // Avatar utilisateur (initiales) — ouvre l'onglet Profil
      GestureDetector(
        onTap: () => _onTabSelected(4),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C00), Color(0xFFFF6B00)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              _initials(widget.session.clientNom),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    ]),
  );
}
  // ── Bottom nav ───── 
  Widget _buildBottomNav() {
  return Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.topCenter,
    children: [
      // Barre blanche flottante avec encoche
      Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: MediaQuery.of(context).padding.bottom + 64,
        child: ClipPath(
          clipper: _BottomNavClipper(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) {
                final (icon, label) = _navItems[i];
                final isSelected = i == _selectedIndex;
                final badge = i == 3 ? _unreadMsgCount : (i == 2 ? _newDocCount : 0);
                // Espace vide pour le bouton central surélevé
                if (i == 2) return const SizedBox(width: 64);
                return GestureDetector(
                  onTap: () => _onTabSelected(i),
                  child: Stack(clipBehavior: Clip.none, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        AnimatedScale(
                          scale: isSelected ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          child: Icon(icon, size: 22,
                              color: isSelected ? _kAccentOrange : const Color(0xFFBDBDBD)),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected ? _kAccentOrange : const Color(0xFFBDBDBD),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          ),
                          child: Text(label.replaceAll('Tableau de bord', 'Dashboard')),
                        ),
                      ]),
                    ),
                    if (badge > 0)
                      Positioned(
                        top: 2, right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('$badge',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ]),
                );
              }),
            ),
          ),
        ),
      ),

      // Bouton central surélevé animé
      Positioned(
        top: -22,
        child: GestureDetector(
          onTap: () => _onTabSelected(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            width: _selectedIndex == 2 ? 62 : 56,
            height: _selectedIndex == 2 ? 62 : 56,
            decoration: BoxDecoration(
              color: _selectedIndex == 2 ? _kAccentOrange : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: _kAccentOrange.withOpacity(_selectedIndex == 2 ? 0.0 : 0.25),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kAccentOrange.withOpacity(_selectedIndex == 2 ? 0.45 : 0.20),
                  blurRadius: _selectedIndex == 2 ? 20 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedScale(
              scale: _selectedIndex == 2 ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(
                _navItems[2].$1,
                size: 24,
                color: _selectedIndex == 2 ? Colors.white : _kAccentOrange,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
  Widget _buildDashboardContent({required bool isWide}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 32 : 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!isWide) ...[
          _buildWelcomeHeader(),
          const SizedBox(height: 20),
          _buildStatCards(),
          const SizedBox(height: 24),
        ],
        _buildSectionHeader('Mes Projets', onTap: () {}),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(color: _kAccentOrange, strokeWidth: 2),
          ))
        else if (_projects.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('Aucun projet trouvé', style: TextStyle(color: _kTextSecondary))),
          )
        else
          ..._projects.map(_buildProjectCard),
        const SizedBox(height: 24),
        if (isWide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _buildRecentDocuments()),
            const SizedBox(width: 24),
            Expanded(child: _buildRecentMessages()),
          ])
        else ...[
          _buildRecentDocuments(),
          const SizedBox(height: 24),
          _buildRecentMessages(),
        ],
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildWelcomeHeader() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Bienvenue,', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _kDark, height: 1.1)),
    Text(widget.session.clientNom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kDark, height: 1.1)),
    const SizedBox(height: 6),
    const Text('Voici un aperçu de vos projets en cours', style: TextStyle(fontSize: 13, color: _kTextSecondary)),
  ]);

  Widget _buildStatCards() {
    final stats = [
      (_kAccentOrange, LucideIcons.folderOpen, '${_projects.length}', 'Projets actifs'),
      (const Color(0xFF10B981), LucideIcons.fileText, '${_documents.length}', 'Documents'),
      (const Color(0xFFEF4444), LucideIcons.messageSquare, '${_messages.length}', 'Messages'),
    ];
    return Column(children: stats.map((s) {
      final (color, icon, count, label) = s;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 20)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(count, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kDark)),
            Text(label, style: const TextStyle(fontSize: 12, color: _kTextSecondary)),
          ]),
        ]),
      );
    }).toList());
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onTap}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
      if (onTap != null)
        GestureDetector(onTap: onTap, child: const Row(children: [
          Text('Voir tout', style: TextStyle(fontSize: 13, color: _kAccentOrange, fontWeight: FontWeight.w600)),
          SizedBox(width: 4),
          Icon(LucideIcons.arrowRight, size: 14, color: _kAccentOrange),
        ])),
    ],
  );

  Widget _buildProjectCard(ClientProject project) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientProjectDetailScreen(
            projetId:    project.id,
            projetNom:   project.name,
            clientEmail: widget.session.clientEmail,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(project.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kDark)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(5)),
              child: Text(project.phase,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kTextSecondary)),
            ),
            if (project.newItems > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20)),
                child: Text('${project.newItems} nouveau${project.newItems > 1 ? 'x' : ''}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
            const SizedBox(width: 8),
            // Chevron → indique que la carte est cliquable
            const Icon(LucideIcons.chevronRight, size: 16, color: _kTextSecondary),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(LucideIcons.clock, size: 12, color: _kTextSecondary),
            const SizedBox(width: 4),
            Text(project.lastUpdate, style: const TextStyle(fontSize: 12, color: _kTextSecondary)),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Avancement', style: TextStyle(fontSize: 12, color: _kTextSecondary)),
            Text('${project.progress}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kAccentOrange)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: project.progress / 100,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(_kAccentOrange),
              minHeight: 8,
            ),
          ),
        ]),
      ),
    );
  }
  Widget _buildRecentDocuments() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader('Documents récents', onTap: () {}),
      const SizedBox(height: 16),
      if (_loading)
        const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: CircularProgressIndicator(color: _kAccentOrange, strokeWidth: 2)))
      else if (_docsError != null)
        Text('Erreur: $_docsError', style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)))
      else if (_documents.isEmpty)
        const Text('Aucun document disponible', style: TextStyle(fontSize: 13, color: _kTextSecondary))
      else
        ..._documents.map((doc) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)), child: Icon(doc.icon, size: 16, color: _kAccentOrange)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark), maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)), child: Text(doc.category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kTextSecondary))),
                const SizedBox(width: 6),
                Text(doc.date, style: const TextStyle(fontSize: 11, color: _kTextSecondary)),
              ]),
            ])),
          ]),
        )),
    ]),
  );

  Widget _buildRecentMessages() {
    final preview = _messages.take(2).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionHeader(
          'Messages récents',
          onTap: _messages.isNotEmpty ? _showAllMessages : null,
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: CircularProgressIndicator(color: _kAccentOrange, strokeWidth: 2)))
        else if (preview.isEmpty)
          const Text('Aucun message disponible', style: TextStyle(fontSize: 13, color: _kTextSecondary))
        else
          ...preview.map((msg) => _buildMessageTile(msg)),
      ]),
    );
  }

  Widget _buildMessageTile(ClientMessage msg) => GestureDetector(
    onTap: () => _openComments(msg.projetId, msg.projetNom),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: msg.isUnread ? const Color(0xFFFFF7ED) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: msg.isUnread ? Border.all(color: _kAccentOrange.withOpacity(0.25)) : null,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: msg.avatarColor, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(msg.initials, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
          ),
          if (msg.isUnread)
            Positioned(
              top: -2, right: -2,
              child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(msg.senderName, style: TextStyle(fontSize: 13, fontWeight: msg.isUnread ? FontWeight.w800 : FontWeight.w700, color: _kDark))),
            if (msg.isUnread)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(6)),
                child: const Text('NOUVEAU', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
              )
            else if (msg.projetNom.isNotEmpty)
              Text(msg.projetNom, style: const TextStyle(fontSize: 10, color: _kAccentOrange, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
          if (msg.projetNom.isNotEmpty && msg.isUnread)
            Text(msg.projetNom, style: const TextStyle(fontSize: 10, color: _kAccentOrange, fontWeight: FontWeight.w600)),
          Text(msg.senderRole, style: const TextStyle(fontSize: 10, color: _kTextSecondary)),
          const SizedBox(height: 4),
          Text(msg.preview, style: TextStyle(fontSize: 12, color: msg.isUnread ? const Color(0xFF111827) : const Color(0xFF374151), fontWeight: msg.isUnread ? FontWeight.w500 : FontWeight.w400), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(msg.time, style: const TextStyle(fontSize: 10, color: _kTextSecondary)),
        ])),
        const SizedBox(width: 6),
        const Icon(LucideIcons.chevronRight, size: 14, color: _kTextSecondary),
      ]),
    ),
  );

  void _showAllMessages() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                const Text('Tous les messages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _kAccentOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('${_messages.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kAccentOrange)),
                ),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            // Liste complète
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _buildMessageTile(_messages[i]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Onglet Mes Projets ────────────────────────────────────────────────────
  Widget _buildProjectsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildTabTitle('Mes Projets', '${_projects.length}', _kAccentOrange),
      const SizedBox(height: 16),
      if (_loading)
        _tabLoading()
      else if (_projects.isEmpty)
        _tabEmpty('Aucun projet assigné', LucideIcons.folderOpen)
      else
        ..._projects.map(_buildProjectCard),
      const SizedBox(height: 24),
    ]),
  );

  // ── Onglet Documents ──────────────────────────────────────────────────────
  Widget _buildDocumentsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildTabTitle('Documents', '${_documents.length}', const Color(0xFF10B981)),
      const SizedBox(height: 16),
      if (_loading)
        _tabLoading()
      else if (_docsError != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('Erreur : $_docsError', style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
        )
      else if (_documents.isEmpty)
        _tabEmpty('Aucun document disponible', LucideIcons.fileText)
      else
        ..._documents.map(_buildDocumentTile),
      const SizedBox(height: 24),
    ]),
  );

  // ── Onglet Messages ───────────────────────────────────────────────────────
  Widget _buildMessagesTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildTabTitle('Messages', '${_messages.length}', const Color(0xFFEF4444)),
      const SizedBox(height: 16),
      if (_loading)
        _tabLoading()
      else if (_messages.isEmpty)
        _tabEmpty('Aucun message disponible', LucideIcons.messageSquare)
      else
        ..._messages.map(_buildMessageTile),
      const SizedBox(height: 24),
    ]),
  );

  // ── Onglet Profil ─────────────────────────────────────────────────────────
  Widget _buildProfileTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const SizedBox(height: 16),
      // Avatar
      Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8C00), Color(0xFFFF6B00)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _kAccentOrange.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: Text(
            _initials(widget.session.clientNom),
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(widget.session.clientNom,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kDark)),
      const SizedBox(height: 4),
      Text(widget.session.clientEmail,
          style: const TextStyle(fontSize: 14, color: _kTextSecondary)),
      const SizedBox(height: 32),
      // Info card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Informations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextSecondary)),
          const SizedBox(height: 16),
          _profileRow(LucideIcons.user, 'Nom', widget.session.clientNom),
          const Divider(height: 24),
          _profileRow(LucideIcons.mail, 'Email', widget.session.clientEmail),
          const Divider(height: 24),
          _profileRow(LucideIcons.folderOpen, 'Projets', '${_projects.length} projet${_projects.length > 1 ? 's' : ''}'),
        ]),
      ),
      const SizedBox(height: 20),
      // Actions
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          _profileAction(
            icon: LucideIcons.lock,
            label: 'Changer le mot de passe',
            color: _kAccentOrange,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ClientChangePasswordScreen(session: widget.session),
            )),
          ),
          const Divider(height: 24),
          _profileAction(
            icon: LucideIcons.logOut,
            label: 'Se déconnecter',
            color: const Color(0xFFEF4444),
            onTap: _logout,
          ),
        ]),
      ),
      const SizedBox(height: 32),
    ]),
  );

  Widget _profileRow(IconData icon, String label, String value) => Row(children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 16, color: _kTextSecondary),
    ),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _kTextSecondary, fontWeight: FontWeight.w500)),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kDark)),
    ]),
  ]);

  Widget _profileAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color))),
        Icon(LucideIcons.chevronRight, size: 16, color: color.withOpacity(0.5)),
      ]),
    );

  // ── Titre d'onglet avec badge ─────────────────────────────────────────────
  Widget _buildTabTitle(String title, String count, Color color) => Row(children: [
    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kDark)),
    const SizedBox(width: 10),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(count, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ),
  ]);

  Widget _tabLoading() => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: CircularProgressIndicator(color: _kAccentOrange, strokeWidth: 2),
    ),
  );

  Widget _tabEmpty(String msg, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, size: 28, color: _kTextSecondary),
        ),
        const SizedBox(height: 12),
        Text(msg, style: const TextStyle(fontSize: 14, color: _kTextSecondary, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  // ── Tuile document (réutilisée dans l'onglet Documents) ───────────────────
  Widget _buildDocumentTile(ClientDocument doc) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: doc.isNew ? const Color(0xFFF0FDF4) : _kSurface,
      borderRadius: BorderRadius.circular(14),
      border: doc.isNew ? Border.all(color: const Color(0xFF10B981).withOpacity(0.3)) : null,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: doc.isNew ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(doc.icon, size: 18, color: doc.isNew ? const Color(0xFF10B981) : _kAccentOrange),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(doc.name,
          style: TextStyle(fontSize: 13, fontWeight: doc.isNew ? FontWeight.w700 : FontWeight.w600, color: _kDark),
          maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
            child: Text(doc.category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kTextSecondary)),
          ),
          if (doc.isNew) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
              child: const Text('NOUVEAU', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
            ),
          ] else if (doc.date.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(doc.date, style: const TextStyle(fontSize: 11, color: _kTextSecondary)),
          ],
        ]),
      ])),
    ]),
  );

  void _openComments(String projetId, String projetNom) {
    if (projetId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClientProjectDetailScreen(
        projetId:        projetId,
        projetNom:       projetNom,
        clientEmail:     widget.session.clientEmail,
        initialTabIndex: 2,
      ),
    ));
  }

  Future<void> _onTabSelected(int index) async {
    setState(() => _selectedIndex = index);
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    if (index == 3) {
      // Messages → marquer tous comme lus
      await prefs.setString('last_msg_read_${widget.session.id}', now.toIso8601String());
      if (!mounted) return;
      setState(() {
        _lastMsgRead = now;
        _messages = _messages.map((m) => ClientMessage(
          senderName: m.senderName, senderRole: m.senderRole, initials: m.initials,
          preview: m.preview, time: m.time, isUnread: false,
          avatarColor: m.avatarColor, projetId: m.projetId, projetNom: m.projetNom,
          createdAtMs: m.createdAtMs,
        )).toList();
      });
    } else if (index == 2) {
      // Documents → marquer tous comme vus
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
class _BottomNavClipper extends CustomClipper<Path> {
  const _BottomNavClipper();

  @override
  Path getClip(Size size) {
    const notchRadius = 32.0;
    const notchWidth = 64.0;
    final centerX = size.width / 2;
    final path = Path();
    final radius = 32.0; // border radius de la barre

    path.moveTo(radius, 0);
    // Côté gauche → jusqu'à l'encoche
    path.lineTo(centerX - notchWidth / 2, 0);
    // Encoche (arc vers le haut)
    path.arcToPoint(
      Offset(centerX + notchWidth / 2, 0),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    // Côté droit
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_BottomNavClipper old) => false;
}