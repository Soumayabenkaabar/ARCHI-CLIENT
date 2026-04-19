// lib/screens/client_login_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../service/client_auth_service.dart';
import 'client_change_password_screen.dart';
import 'client_portal_screen.dart';

class ClientLoginScreen extends StatefulWidget {
  const ClientLoginScreen({super.key});
  @override
  State<ClientLoginScreen> createState() => _ClientLoginScreenState();
}

class _ClientLoginScreenState extends State<ClientLoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  String? _error;

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final session = await ClientAuthService.login(email, pass);
      if (!mounted) return;
      if (!session.passwordChanged) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ClientChangePasswordScreen(session: session),
        ));
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ClientPortalScreen(session: session),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 860;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: isWide ? _buildDesktop() : _buildMobile(),
    );
  }

  // ── Desktop ────────────────────────────────────────────────────────────────
  Widget _buildDesktop() {
    return Row(children: [
      // ── Gauche — Branding ──
      Expanded(
        flex: 55,
        child: Stack(children: [
          // Fond gradient profond
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0E1A), Color(0xFF0F1629), Color(0xFF0A0E1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Cercles décoratifs lumineux
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  kAccent.withOpacity(0.18),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF3B82F6).withOpacity(0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Grille décorative subtile
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          // Contenu
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(LucideIcons.building2,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('ArchiManager',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                    Text('Portail Client',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12)),
                  ]),
                ]),
                const Spacer(),
                // Headline
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Votre projet,',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -1)),
                      const Text('en temps réel.',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                              height: 1)),
                      const SizedBox(height: 20),
                      Text(
                        'Suivez l\'avancement, consultez les photos\net échangez avec votre architecte.',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 15,
                            height: 1.7),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 52),
                // Features
                ...[
                  (LucideIcons.checkCircle2, 'Tâches & Planning',
                      'Avancement en temps réel'),
                  (LucideIcons.camera, 'Galerie Photos',
                      'Suivi visuel du chantier'),
                  (LucideIcons.box, 'Modèle 3D',
                      'Maquette numérique interactive'),
                  (LucideIcons.messageSquare, 'Messagerie',
                      'Contact direct avec l\'architecte'),
                ].map((e) => _featureTile(e.$1, e.$2, e.$3)),
                const Spacer(),
                // Footer
                Text('© 2026 ArchiManager — Tous droits réservés',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.2), fontSize: 11)),
              ],
            ),
          ),
        ]),
      ),

      // ── Droite — Formulaire ──
      Expanded(
        flex: 45,
        child: Container(
          color: const Color(0xFFFAFAFC),
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _buildFormCard(),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Mobile ─────────────────────────────────────────────────────────────────
  Widget _buildMobile() {
    return Stack(children: [
      // Fond
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E1A), Color(0xFF0F1629)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      Positioned(
        top: -60,
        right: -60,
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              kAccent.withOpacity(0.15),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: kAccent.withOpacity(0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(LucideIcons.building2,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('ArchiManager',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 36),
                    Text('Votre projet,',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 26,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -0.5)),
                    const Text('en temps réel.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            height: 1.1)),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // Card formulaire
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: _buildFormCard(),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ── Card formulaire ────────────────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.logIn, size: 18, color: kAccent),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Connexion',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A0E1A),
                      letterSpacing: -0.5)),
              Text('Accédez à votre espace projet',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12)),
            ]),
          ]),

          const SizedBox(height: 32),

          // ── Champ Email ──
          _buildField(
            controller: _emailCtrl,
            label: 'ADRESSE EMAIL',
            hint: 'votre@email.com',
            icon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // ── Champ Mot de passe ──
          _buildField(
            controller: _passCtrl,
            label: 'MOT DE PASSE',
            hint: '••••••••',
            icon: LucideIcons.lock,
            obscure: !_showPass,
            suffix: GestureDetector(
              onTap: () => setState(() => _showPass = !_showPass),
              child: Icon(
                _showPass ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 17,
                color: Colors.grey.shade400,
              ),
            ),
            onSubmit: (_) => _login(),
          ),

          // ── Erreur ──
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(children: [
                const Icon(LucideIcons.alertCircle,
                    size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 24),

          // ── Bouton ──
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A0E1A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor:
                    const Color(0xFF0A0E1A).withOpacity(0.5),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Se connecter',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2)),
                        const SizedBox(width: 8),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(LucideIcons.arrowRight,
                              size: 12, color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Divider ──
          Row(children: [
            Expanded(child: Divider(color: Colors.grey.shade200)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('info',
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 11)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade200)),
          ]),

          const SizedBox(height: 16),

          // ── Info ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.info,
                    size: 13, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vos identifiants ont été envoyés par votre architecte. Contactez-le si vous n\'avez pas reçu d\'email.',
                    style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 11,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Feature tile (desktop) ─────────────────────────────────────────────────
  Widget _featureTile(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Icon(icon, color: kAccent, size: 16),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Text(sub,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 11)),
        ]),
      ]),
    );
  }

  // ── Champ formulaire ───────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    Function(String)? onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade400,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          onSubmitted: onSubmit,
          style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0A0E1A),
              fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 14,
                fontWeight: FontWeight.w400),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, size: 16, color: Colors.grey.shade400),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: suffix)
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: const Color(0xFF0A0E1A), width: 1.5)),
          ),
        ),
      ],
    );
  }
}

// ── Grid painter décoratif ─────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;

    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}