// lib/screens/client_project_detail_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../service/client_portal_service.dart';

// ── Constantes (cohérentes avec client_portal_screen.dart) ───────────────────
const _kBg            = Color(0xFFF5F5F5);
const _kSurface       = Colors.white;
const _kNavy          = Color(0xFF0B1437);
const _kDark          = Color(0xFF0A0E1A);
const _kAccentOrange  = Color(0xFFFF8C00);
const _kTextSecondary = Color(0xFF6B7280);
const _kGreen         = Color(0xFF10B981);
const _kRed           = Color(0xFFEF4444);
const _kBlue          = Color(0xFF3B82F6);

// ── Modèles locaux ────────────────────────────────────────────────────────────
class _Actualite {
  final String type, contenu, auteur, date;
  const _Actualite({required this.type, required this.contenu, required this.auteur, required this.date});
}

class _Photo {
  final String nom, url, description, date;
  const _Photo({required this.nom, required this.url, required this.description, required this.date});
}

class _Document {
  final String id, nom, type, date, url, version;
  final IconData icon;
  final int uploadedAtMs;
  const _Document({required this.id, required this.nom, required this.type, required this.date, required this.url, required this.icon, this.version = '', this.uploadedAtMs = 0});
}

class _Commentaire {
  final String auteur, role, contenu, date, initials;
  final Color avatarColor;
  final String? fichierUrl, fichierNom;
  const _Commentaire({
    required this.auteur, required this.role, required this.contenu,
    required this.date, required this.initials, required this.avatarColor,
    this.fichierUrl, this.fichierNom,
  });
}

// ── Écran principal ───────────────────────────────────────────────────────────
class ClientProjectDetailScreen extends StatefulWidget {
  final String projetId;
  final String projetNom;
  final String clientEmail;
  final int initialTabIndex;

  const ClientProjectDetailScreen({
    super.key,
    required this.projetId,
    required this.projetNom,
    required this.clientEmail,
    this.initialTabIndex = 0,
  });

  @override
  State<ClientProjectDetailScreen> createState() => _ClientProjectDetailScreenState();
}

class _ClientProjectDetailScreenState extends State<ClientProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data
  List<_Actualite>   _actualites   = [];
  List<_Photo>       _photos        = [];
  List<_Document>    _documents     = [];
  List<_Commentaire> _commentaires  = [];

  // Loading states
  bool _loadingActualites  = true;
  bool _loadingPhotos      = true;
  bool _loadingDocuments   = true;
  bool _loadingCommentaires = true;

  // Commentaire input
  final _commentCtrl = TextEditingController();
  bool _sendingComment = false;
  PlatformFile? _selectedFile;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadAll());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadActualites();
    _loadPhotos();
    _loadDocuments();
    _loadCommentaires();
  }

  // ── Loaders ──────────────────────────────────────────────────────────────
  Future<void> _loadActualites() async {
    try {
      final data = await ClientPortalService.getActualitesChantier(widget.projetId);
      if (!mounted) return;
      setState(() {
        _actualites = data.map((d) => _Actualite(
          type:    (d['type'] as String?) ?? 'Info',
          contenu: (d['contenu'] as String?) ?? '',
          auteur:  (d['auteur'] as String?) ?? '',
          date:    _relativeDate((d['created_at'] as String?) ?? ''),
        )).toList();
        _loadingActualites = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingActualites = false);
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final data = await ClientPortalService.getPhotosChantier(widget.projetId);
      if (!mounted) return;
      setState(() {
        _photos = data.map((d) => _Photo(
          nom:         (d['nom'] as String?) ?? '',
          url:         (d['url'] as String?) ?? '',
          description: (d['description'] as String?) ?? '',
          date:        _formatDate((d['uploaded_at'] as String?) ?? ''),
        )).toList();
        _loadingPhotos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPhotos = false);
    }
  }

  static final _versionRegex = RegExp(r'[vV](\d+(?:[._]\d+)*)', caseSensitive: false);

  String _extractVersion(String nom) {
    final m = _versionRegex.firstMatch(nom);
    return m != null ? 'v${m.group(1)!.replaceAll('_', '.')}' : '';
  }

  double _versionToNum(String v) {
    if (v.isEmpty) return -1;
    final parts = v.replaceFirst(RegExp(r'^v', caseSensitive: false), '').split('.');
    double num = 0;
    for (int i = 0; i < parts.length; i++) {
      num += (double.tryParse(parts[i]) ?? 0) / (i == 0 ? 1 : 100 * i);
    }
    return num;
  }

  Future<void> _loadDocuments() async {
    try {
      final data = await ClientPortalService.getDocumentsForProjet(widget.projetId);
      if (!mounted) return;
      final docs = data.map((d) {
        final type = (d['type'] as String?) ?? 'pdf';
        final rawNom = (d['nom'] as String?) ?? 'Document';
        final uploadedIso = (d['uploaded_at'] as String?) ?? '';
        int uploadedMs = 0;
        try { uploadedMs = DateTime.parse(uploadedIso).millisecondsSinceEpoch; } catch (_) {}
        final cleanName = _cleanDocName(rawNom);
        return _Document(
          id:           d['id']?.toString() ?? '',
          nom:          cleanName,
          type:         _docTypeLabel(type),
          date:         _formatDate(uploadedIso),
          url:          (d['url'] as String?) ?? '',
          icon:         _docIcon(type),
          version:      _extractVersion(cleanName),
          uploadedAtMs: uploadedMs,
        );
      }).toList();
      // Tri : version desc (documents avec version les plus récentes en premier), puis date desc
      docs.sort((a, b) {
        final va = _versionToNum(a.version);
        final vb = _versionToNum(b.version);
        if (va >= 0 && vb >= 0 && va != vb) return vb.compareTo(va);
        return b.uploadedAtMs.compareTo(a.uploadedAtMs);
      });
      setState(() { _documents = docs; _loadingDocuments = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDocuments = false);
    }
  }

  Future<void> _loadCommentaires() async {
    try {
      final data = await ClientPortalService.getRecentMessages(widget.projetId);
      if (!mounted) return;
      setState(() {
        _commentaires = data.map((d) {
          final auteur = (d['auteur'] as String?) ?? 'Inconnu';
          final rawContenu = (d['contenu'] as String?) ?? '';
          String contenu = rawContenu;
          String? fichierUrl = d['fichier_url'] as String?;
          String? fichierNom = d['fichier_nom'] as String?;

          // Parsing du format ||ATTACH||... (présent n'importe où dans contenu)
          const tag = '||ATTACH||';
          final attachIdx = rawContenu.indexOf(tag);
          if (attachIdx >= 0) {
            contenu = rawContenu.substring(0, attachIdx).trim();
            final payload = rawContenu.substring(attachIdx + tag.length);
            final parts = payload.split('||');
            final a = parts.isNotEmpty ? parts[0].trim() : '';
            final b = parts.length >= 2 ? parts[1].trim() : '';
            if (a.startsWith('http')) {
              fichierUrl ??= a;
              fichierNom ??= b.isNotEmpty ? b : a.split('/').last.split('?').first;
            } else if (b.startsWith('http')) {
              fichierNom ??= a.isNotEmpty ? a : b.split('/').last.split('?').first;
              fichierUrl ??= b;
            } else if (a.isNotEmpty) {
              fichierNom ??= a;
            }
          }

          return _Commentaire(
            auteur:      auteur,
            role:        _roleLabel((d['role'] as String?) ?? 'client'),
            contenu:     contenu,
            date:        _relativeDate((d['created_at'] as String?) ?? ''),
            initials:    _initials(auteur),
            avatarColor: _avatarColor(auteur),
            fichierUrl:  fichierUrl,
            fichierNom:  fichierNom,
          );
        }).toList();
        _loadingCommentaires = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCommentaires = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(withData: true, type: FileType.any);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty && _selectedFile == null) return;
    setState(() => _sendingComment = true);
    try {
      String? fichierUrl;
      String? fichierNom;
      if (_selectedFile != null) {
        var bytes = _selectedFile!.bytes;
        // Fallback : lire depuis le disque si bytes non chargé en mémoire
        if (bytes == null && _selectedFile!.path != null) {
          bytes = await File(_selectedFile!.path!).readAsBytes();
        }
        if (bytes != null) {
          fichierUrl = await ClientPortalService.uploadCommentFile(
            projetId: widget.projetId,
            fileName: _selectedFile!.name,
            bytes:    bytes,
          );
          fichierNom = _selectedFile!.name;
        } else {
          throw Exception('Impossible de lire le fichier sélectionné.');
        }
      }
      await ClientPortalService.addComment(
        projetId:   widget.projetId,
        contenu:    text.isEmpty ? '📎 Fichier joint' : text,
        fichierUrl: fichierUrl,
        fichierNom: fichierNom,
      );
      _commentCtrl.clear();
      setState(() => _selectedFile = null);
      await _loadCommentaires();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: _kRed),
      );
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static const _months = ['janv.','févr.','mars','avril','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day} ${_months[d.month - 1]} ${d.year}';
    } catch (_) { return ''; }
  }

  String _relativeDate(String iso) {
    if (iso.isEmpty) return 'Récemment';
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inDays == 0) return 'Aujourd\'hui';
      if (diff.inDays == 1) return 'Hier';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
      if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()} sem.';
      return 'Il y a ${(diff.inDays / 30).floor()} mois';
    } catch (_) { return 'Récemment'; }
  }

  String _cleanDocName(String raw) {
    if (raw.contains('||META||')) return raw.split('||META||').last.split('||').first.trim();
    if (raw.contains('||')) return raw.split('||').last.trim();
    return raw;
  }

  static const _docTypeLabels = {
    'pdf': 'PDF', 'image': 'Image', 'img': 'Image',
    'jpg': 'Image', 'jpeg': 'Image', 'png': 'Image',
    'dwg': 'Plan', 'cad': 'Plan',
    'docx': 'Word', 'doc': 'Word',
    'xlsx': 'Excel', 'xls': 'Excel',
  };

  String _docTypeLabel(String type) =>
      _docTypeLabels[type.toLowerCase()] ?? type.toUpperCase();

  IconData _docIcon(String type) {
    final t = type.toLowerCase();
    if (['image','img','jpg','jpeg','png'].contains(t)) return LucideIcons.image;
    if (['dwg','cad'].contains(t)) return LucideIcons.penTool;
    if (['xlsx','xls'].contains(t)) return LucideIcons.table;
    if (['docx','doc'].contains(t)) return LucideIcons.fileText;
    return LucideIcons.fileText;
  }

  static const _roleLabels = {
    'architecte': 'Architecte', 'client': 'Client',
    'chef_projet': 'Chef de projet', 'chef': 'Chef de projet',
  };

  String _roleLabel(String role) => _roleLabels[role.toLowerCase()] ?? role;

  static const _avatarColors = [
    _kAccentOrange, _kBlue, _kGreen, Color(0xFF8B5CF6), _kRed,
  ];

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _avatarColor(String name) =>
      _avatarColors[name.codeUnits.fold(0, (a, b) => a + b) % _avatarColors.length];

  Color _actualiteColor(String type) {
    switch (type.toLowerCase()) {
      case 'progrès': case 'progres': return _kGreen;
      case 'problème': case 'probleme': return _kRed;
      case 'livraison': return _kBlue;
      default: return _kAccentOrange;
    }
  }

  IconData _actualiteIcon(String type) {
    switch (type.toLowerCase()) {
      case 'progrès': case 'progres': return LucideIcons.trendingUp;
      case 'problème': case 'probleme': return LucideIcons.alertTriangle;
      case 'livraison': return LucideIcons.package;
      default: return LucideIcons.info;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(child: TabBarView(
          controller: _tabController,
          children: [
            _buildSuiviTab(),
            _buildDocumentsTab(),
            _buildCommentairesTab(),
            _buildModele3DTab(),
          ],
        )),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _kNavy,
        boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20, right: 20, bottom: 16,
      ),
      child: Row(children: [
        // Bouton retour
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
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
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.projetNom,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            const Text(
              'Détail du projet',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
            ),
          ]),
        ),
        // Icône projet
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _kAccentOrange,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _kAccentOrange.withOpacity(0.4), blurRadius: 8)],
          ),
          child: const Icon(LucideIcons.building2, color: Colors.white, size: 18),
        ),
      ]),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      (LucideIcons.activity, 'Suivi & Photos'),
      (LucideIcons.fileText, 'Documents'),
      (LucideIcons.messageSquare, 'Commentaires'),
      (LucideIcons.box, 'Modèle 3D'),
    ];

    return Container(
      color: _kSurface,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final (icon, label) = tabs[i];
          final isSelected = _tabController.index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _tabController.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? _kAccentOrange : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 16, color: isSelected ? _kAccentOrange : _kTextSecondary),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _kAccentOrange : _kTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── TAB 1 : Suivi & Photos ────────────────────────────────────────────────
  Widget _buildSuiviTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Section actualités
        _sectionTitle('Actualités du chantier', LucideIcons.activity),
        const SizedBox(height: 12),
        if (_loadingActualites)
          _loadingCard()
        else if (_actualites.isEmpty)
          _emptyCard('Aucune actualité pour ce projet')
        else
          ..._actualites.map((a) => _buildActualiteCard(a)),

        const SizedBox(height: 24),

        // Section photos
        _sectionTitle('Photos du chantier', LucideIcons.camera),
        const SizedBox(height: 12),
        if (_loadingPhotos)
          _loadingCard()
        else if (_photos.isEmpty)
          _emptyCard('Aucune photo disponible')
        else
          _buildPhotosGrid(),

        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildActualiteCard(_Actualite a) {
    final color = _actualiteColor(a.type);
    final icon  = _actualiteIcon(a.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(a.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ),
            const Spacer(),
            Text(a.date, style: const TextStyle(fontSize: 10, color: _kTextSecondary)),
          ]),
          const SizedBox(height: 6),
          Text(a.contenu, style: const TextStyle(fontSize: 13, color: _kDark, height: 1.5)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(LucideIcons.user, size: 11, color: _kTextSecondary),
            const SizedBox(width: 4),
            Text(a.auteur, style: const TextStyle(fontSize: 11, color: _kTextSecondary, fontWeight: FontWeight.w500)),
          ]),
        ])),
      ]),
    );
  }

  Widget _buildPhotosGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _photos.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => _openPhotoViewer(i),
        child: _buildPhotoCard(_photos[i]),
      ),
    );
  }

  Widget _buildPhotoCard(_Photo photo) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
          // Image
          photo.url.isNotEmpty
            ? Image.network(
                photo.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _photoPlaceholder(),
              )
            : _photoPlaceholder(),
          // Overlay gradient bas
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(photo.nom, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (photo.date.isNotEmpty)
                  Text(photo.date, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 9)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(LucideIcons.image, size: 32, color: _kTextSecondary),
      ),
    );
  }

  void _openPhotoViewer(int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PhotoViewerPage(photos: _photos, initialIndex: initialIndex),
    ));
  }

  // ── TAB 2 : Documents ─────────────────────────────────────────────────────
  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Documents du projet', LucideIcons.folder),
        const SizedBox(height: 8),
        if (!_loadingDocuments && _documents.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              const Icon(LucideIcons.arrowDownNarrowWide, size: 12, color: _kTextSecondary),
              const SizedBox(width: 4),
              Text(
                'Trié par version puis date',
                style: const TextStyle(fontSize: 11, color: _kTextSecondary),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAccentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${_documents.length} fichier${_documents.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kAccentOrange)),
              ),
            ]),
          ),
        if (_loadingDocuments)
          _loadingCard()
        else if (_documents.isEmpty)
          _emptyCard('Aucun document disponible')
        else
          ..._documents.map(_buildDocumentRow),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildDocumentRow(_Document doc) {
    final typeColor = _docTypeColor(doc.type);
    return GestureDetector(
      onTap: () => _openDocumentPreview(doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(doc.icon, size: 18, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(doc.type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: typeColor)),
              ),
              if (doc.version.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(doc.version, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
                ),
              ],
              const SizedBox(width: 8),
              if (doc.date.isNotEmpty)
                Text(doc.date, style: const TextStyle(fontSize: 11, color: _kTextSecondary)),
            ]),
          ])),
          const SizedBox(width: 8),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.eye, size: 15, color: _kTextSecondary),
          ),
        ]),
      ),
    );
  }

  void _openDocumentPreview(_Document doc) {
    if (doc.url.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _DocumentViewerPage(doc: doc),
    ));
  }

  Color _docTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':   return _kRed;
      case 'IMAGE': return _kGreen;
      case 'PLAN':  return _kBlue;
      case 'WORD':  return const Color(0xFF2563EB);
      case 'EXCEL': return _kGreen;
      default:      return _kAccentOrange;
    }
  }

  // ── TAB 3 : Commentaires ──────────────────────────────────────────────────
  Widget _buildCommentairesTab() {
    return Column(children: [
      Expanded(
        child: _loadingCommentaires
          ? const Center(child: CircularProgressIndicator(color: _kAccentOrange, strokeWidth: 2))
          : _commentaires.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(LucideIcons.messageSquare, size: 28, color: _kTextSecondary),
                  ),
                  const SizedBox(height: 12),
                  const Text('Aucun commentaire', style: TextStyle(fontSize: 14, color: _kTextSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Soyez le premier à commenter', style: TextStyle(fontSize: 12, color: _kTextSecondary)),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _commentaires.length,
                itemBuilder: (_, i) => _buildCommentaireCard(_commentaires[i]),
              ),
      ),
      // Zone de saisie
      _buildCommentInput(),
    ]);
  }

  Widget _buildCommentaireCard(_Commentaire c) {
    final isClient = c.role == 'Client';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isClient ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isClient) ...[
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: c.avatarColor, borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(c.initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isClient ? _kAccentOrange.withOpacity(0.1) : _kSurface,
                borderRadius: BorderRadius.only(
                  topLeft:     Radius.circular(isClient ? 14 : 4),
                  topRight:    Radius.circular(isClient ? 4 : 14),
                  bottomLeft:  const Radius.circular(14),
                  bottomRight: const Radius.circular(14),
                ),
                border: isClient
                  ? Border.all(color: _kAccentOrange.withOpacity(0.2))
                  : null,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(c.auteur, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kDark)),
                  const SizedBox(width: 6),
                  Text(c.role, style: TextStyle(fontSize: 10, color: isClient ? _kAccentOrange : _kTextSecondary, fontWeight: FontWeight.w500)),
                ]),
                if (c.contenu.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(c.contenu, style: const TextStyle(fontSize: 13, color: _kDark, height: 1.5)),
                ],
                if ((c.fichierUrl?.isNotEmpty ?? false) || (c.fichierNom?.isNotEmpty ?? false)) ...[
                  SizedBox(height: c.contenu.isEmpty ? 4 : 8),
                  _buildFileAttachment(c.fichierUrl ?? '', c.fichierNom ?? 'Fichier joint'),
                ],
                const SizedBox(height: 4),
                Text(c.date, style: const TextStyle(fontSize: 10, color: _kTextSecondary), textAlign: TextAlign.right),
              ]),
            ),
          ),
          if (isClient) const SizedBox(width: 10),
        ],
      ),
    );
  }

  // ── Helpers type de fichier ───────────────────────────────────────────────
  static const _imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];

  String _fileExt(String nameOrUrl) =>
      nameOrUrl.split('/').last.split('?').first.split('.').last.toLowerCase();

  Color _extColor(String ext) {
    if (_imageExts.contains(ext)) return _kGreen;
    if (ext == 'pdf') return _kRed;
    if (['xlsx', 'xls'].contains(ext)) return _kGreen;
    if (['docx', 'doc'].contains(ext)) return _kBlue;
    if (['dwg', 'dxf'].contains(ext)) return const Color(0xFF8B5CF6);
    return _kAccentOrange;
  }

  IconData _extIcon(String ext) {
    if (_imageExts.contains(ext)) return LucideIcons.image;
    if (ext == 'pdf') return LucideIcons.fileText;
    if (['xlsx', 'xls'].contains(ext)) return LucideIcons.table;
    if (['docx', 'doc'].contains(ext)) return LucideIcons.fileText;
    if (['dwg', 'dxf'].contains(ext)) return LucideIcons.penTool;
    return LucideIcons.file;
  }

  String _extLabel(String ext) {
    if (_imageExts.contains(ext)) return 'Image';
    if (ext == 'pdf') return 'PDF';
    if (['xlsx', 'xls'].contains(ext)) return 'Excel';
    if (['docx', 'doc'].contains(ext)) return 'Word';
    if (['dwg', 'dxf'].contains(ext)) return 'Plan';
    return ext.isEmpty ? 'Fichier' : ext.toUpperCase();
  }

Widget _buildFileAttachment(String url, String nom) {
  final hasUrl  = url.isNotEmpty;
  final source  = nom.isNotEmpty ? nom : url;
  final ext     = _fileExt(source);
  final icon    = _extIcon(ext);
  final display = nom.isNotEmpty ? nom : 'Fichier joint';

  Future<void> openUrl() async {
    if (!hasUrl) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ✅ NOUVEAU — toujours afficher en pill, même pour les images
  return GestureDetector(
    onTap: hasUrl ? openUrl : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        // ✅ Fond orange uni comme dans le screenshot
        color: _kAccentOrange,
        borderRadius: BorderRadius.circular(30), // ✅ pill arrondie
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Icône type fichier
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        // Nom fichier
        Flexible(
          child: Text(
            display,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        // Icône download
        const Icon(LucideIcons.download, size: 14, color: Colors.white),
      ]),
    ),
  );
}
  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: _kSurface,
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, -3))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Aperçu fichier sélectionné
        if (_selectedFile != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kAccentOrange.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kAccentOrange.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(LucideIcons.paperclip, size: 14, color: _kAccentOrange),
              const SizedBox(width: 8),
              Expanded(child: Text(_selectedFile!.name, style: const TextStyle(fontSize: 12, color: _kDark), maxLines: 1, overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: () => setState(() => _selectedFile = null),
                child: const Icon(LucideIcons.x, size: 14, color: _kTextSecondary),
              ),
            ]),
          ),
        // Zone de saisie + boutons
        Row(children: [
          // Bouton joindre fichier
          GestureDetector(
            onTap: _sendingComment ? null : _pickFile,
            child: Container(
              width: 42, height: 42,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _selectedFile != null ? _kAccentOrange.withOpacity(0.12) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.paperclip, size: 16, color: _selectedFile != null ? _kAccentOrange : _kTextSecondary),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(fontSize: 13, color: _kDark),
              decoration: InputDecoration(
                hintText: 'Écrire un commentaire...',
                hintStyle: const TextStyle(color: _kTextSecondary, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendingComment ? null : _sendComment,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _sendingComment ? _kTextSecondary : _kAccentOrange,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _sendingComment ? [] : [BoxShadow(color: _kAccentOrange.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: _sendingComment
                ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : const Icon(LucideIcons.send, color: Colors.white, size: 16),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── TAB 4 : Modèle 3D ────────────────────────────────────────────────────
  Widget _buildModele3DTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Modèle 3D du projet', LucideIcons.box),
        const SizedBox(height: 12),
        // Placeholder viewer 3D
        Container(
          height: 260,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Stack(children: [
            // Grille décorative
            CustomPaint(painter: _GridPainter(), size: Size.infinite),
            // Contenu centre
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _kAccentOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _kAccentOrange.withOpacity(0.3)),
                ),
                child: const Icon(LucideIcons.box, size: 30, color: _kAccentOrange),
              ),
              const SizedBox(height: 14),
              const Text(
                'Viewer 3D / BIM',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              Text(
                'Intégrez votre viewer IFC ou 3D ici\n(Speckle, Autodesk Forge, etc.)',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ])),
            // Badge coin
            Positioned(
              top: 14, right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kAccentOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kAccentOrange.withOpacity(0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.zap, size: 11, color: _kAccentOrange),
                  SizedBox(width: 4),
                  Text('BIM Ready', style: TextStyle(fontSize: 10, color: _kAccentOrange, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // Info cards
        Row(children: [
          Expanded(child: _buildInfo3DCard(LucideIcons.layers, 'Format', 'IFC / RVT / OBJ', _kBlue)),
          const SizedBox(width: 10),
          Expanded(child: _buildInfo3DCard(LucideIcons.rotate3d, 'Navigation', '3D interactive', _kGreen)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildInfo3DCard(LucideIcons.eye, 'Phases', 'Toutes les phases', _kAccentOrange)),
          const SizedBox(width: 10),
          Expanded(child: _buildInfo3DCard(LucideIcons.download, 'Export', 'PDF / DWG', _kTextSecondary)),
        ]),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildInfo3DCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: _kTextSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kDark)),
        ]),
      ]),
    );
  }

  // ── Widgets utilitaires ───────────────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: _kAccentOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: _kAccentOrange),
      ),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kDark, letterSpacing: -0.3)),
    ]);
  }

  Widget _loadingCard() {
    return Container(
      height: 80,
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14)),
      child: const Center(child: CircularProgressIndicator(color: _kAccentOrange, strokeWidth: 2)),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Center(child: Text(msg, style: const TextStyle(fontSize: 13, color: _kTextSecondary))),
    );
  }
}

// ── Visionneuse document plein écran ─────────────────────────────────────────
class _DocumentViewerPage extends StatefulWidget {
  final _Document doc;
  const _DocumentViewerPage({super.key, required this.doc});

  @override
  State<_DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<_DocumentViewerPage> {
  late final WebViewController? _webCtrl;
  bool _webLoading = true;
  bool _webError   = false;

  bool get _isImage =>
      ['Image', 'IMAGE'].contains(widget.doc.type) ||
      ['jpg','jpeg','png','gif','webp','bmp'].contains(
          widget.doc.url.split('?').first.split('.').last.toLowerCase());

  @override
  void initState() {
    super.initState();
    if (!_isImage && widget.doc.url.isNotEmpty) {
      _webCtrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) => setState(() { _webLoading = true;  _webError = false; }),
          onPageFinished: (_) => setState(() => _webLoading = false),
          onWebResourceError: (_) => setState(() { _webLoading = false; _webError = true; }),
        ))
        ..loadRequest(Uri.parse(widget.doc.url));
    } else {
      _webCtrl = null;
    }
  }

  Color _typeColor() {
    switch (widget.doc.type.toUpperCase()) {
      case 'PDF':   return _kRed;
      case 'IMAGE': return _kGreen;
      case 'PLAN':  return _kBlue;
      case 'WORD':  return const Color(0xFF2563EB);
      case 'EXCEL': return _kGreen;
      default:      return _kAccentOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = _typeColor();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [

        // ── Barre haute ───────────────────────────────────────────────────
        Container(
          color: _kNavy,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16, right: 16, bottom: 12,
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.x, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.doc.nom,
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tc.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(widget.doc.type,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: tc)),
                ),
                if (widget.doc.date.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(widget.doc.date,
                      style: TextStyle(fontSize: 10,
                          color: Colors.white.withOpacity(0.45))),
                ],
              ]),
            ])),
            const SizedBox(width: 8),
            // Bouton ouvrir externalement
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(widget.doc.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kAccentOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kAccentOrange.withOpacity(0.3)),
                ),
                child: const Icon(LucideIcons.externalLink,
                    color: _kAccentOrange, size: 16),
              ),
            ),
          ]),
        ),

        // ── Contenu ───────────────────────────────────────────────────────
        Expanded(child: _buildContent(tc)),
      ]),
    );
  }

  Widget _buildContent(Color tc) {
    if (_isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            widget.doc.url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator(
                    color: _kAccentOrange, strokeWidth: 2)),
            errorBuilder: (_, __, ___) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.doc.icon, size: 56, color: tc.withOpacity(0.4)),
                const SizedBox(height: 12),
                const Text('Impossible de charger l\'image',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    if (_webError) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.doc.icon, size: 56, color: tc.withOpacity(0.4)),
        const SizedBox(height: 16),
        const Text('Impossible de charger le document',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse(widget.doc.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _kAccentOrange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.externalLink, color: Colors.white, size: 15),
              SizedBox(width: 8),
              Text('Ouvrir dans le navigateur',
                  style: TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]));
    }

    return Stack(children: [
      if (_webCtrl != null)
        WebViewWidget(controller: _webCtrl!),
      if (_webLoading)
        const Center(child: CircularProgressIndicator(
            color: _kAccentOrange, strokeWidth: 2)),
    ]);
  }
}

// ── Visionneuse photo plein écran ─────────────────────────────────────────────
class _PhotoViewerPage extends StatefulWidget {
  final List<_Photo> photos;
  final int initialIndex;
  const _PhotoViewerPage({super.key, required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current  = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ── Photos (swipe) ────────────────────────────────────────────────
        PageView.builder(
          controller: _pageCtrl,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) {
            final p = widget.photos[i];
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: p.url.isNotEmpty
                  ? Image.network(
                      p.url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(LucideIcons.image, size: 48, color: Colors.white38),
                    )
                  : const Icon(LucideIcons.image, size: 48, color: Colors.white38),
              ),
            );
          },
        ),

        // ── Barre haute ───────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16, right: 16, bottom: 14,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.x, color: Colors.white, size: 18),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_current + 1} / ${widget.photos.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),

        // ── Info bas ──────────────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (photo.nom.isNotEmpty)
                Text(photo.nom, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (photo.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(photo.description, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (photo.date.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(photo.date, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ],
            ]),
          ),
        ),

        // ── Flèche précédente ─────────────────────────────────────────────
        if (_current > 0)
          Positioned(
            left: 12, top: 0, bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),

        // ── Flèche suivante ───────────────────────────────────────────────
        if (_current < widget.photos.length - 1)
          Positioned(
            right: 12, top: 0, bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _pageCtrl.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(LucideIcons.chevronRight, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),

      ]),
    );
  }
}

// ── Painter grille 3D ─────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}