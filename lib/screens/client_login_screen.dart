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
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  String? _error;
  late AnimationController _anim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await ClientAuthService.login(email, pass);
      if (!mounted) return;

      if (!session.passwordChanged) {
        // ── Première connexion → forcer changement mot de passe ──
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ClientChangePasswordScreen(session: session),
          ),
        );
      } else {
        // ── Connexion normale → portail ──
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ClientPortalScreen(session: session),
          ),
        );
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
    final isWide = size.width > 800;

    return Scaffold(
      backgroundColor: kDark,
      body: isWide ? _buildDesktop() : _buildMobile(),
    );
  }

  // ── Desktop : split screen ─────────────────────────────────────────────────
  Widget _buildDesktop() => Row(children: [
        // Gauche — branding
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1F2937), Color(0xFF111827)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: kAccent,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.building2,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ArchiManager',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      Text('Portail Client',
                          style: TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 13)),
                    ],
                  ),
                ]),
                const Spacer(),
                const Text(
                  'Suivez votre projet\nen temps réel',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1.2),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Accédez à l\'avancement, aux photos et\ncommuniquez directement avec votre architecte.',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 48),
                ...[
                  (LucideIcons.checkCircle, 'Suivi des tâches en temps réel'),
                  (LucideIcons.camera, 'Galerie photos du chantier'),
                  (LucideIcons.box, 'Modèle 3D interactif'),
                  (LucideIcons.messageCircle,
                      'Messagerie directe avec l\'architecte'),
                ].map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: kAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(e.$1, color: kAccent, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Text(e.$2,
                            style: const TextStyle(
                                color: Color(0xFFD1D5DB), fontSize: 14)),
                      ]),
                    )),
                const Spacer(),
                const Text('© 2026 ArchiManager',
                    style:
                        TextStyle(color: Color(0xFF4B5563), fontSize: 12)),
              ],
            ),
          ),
        ),
        // Droite — formulaire
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(child: _buildForm()),
          ),
        ),
      ]);

  // ── Mobile ─────────────────────────────────────────────────────────────────
  Widget _buildMobile() => SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(16)),
                child: const Icon(LucideIcons.building2,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('ArchiManager',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Portail Client',
                  style:
                      TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
            ]),
          ),
          Padding(
              padding: const EdgeInsets.all(24), child: _buildForm()),
        ]),
      );

  // ── Formulaire commun ──────────────────────────────────────────────────────
  Widget _buildForm() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Connexion',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: kTextMain)),
              const SizedBox(height: 6),
              const Text('Accédez à votre espace projet',
                  style: TextStyle(color: kTextSub, fontSize: 14)),
              const SizedBox(height: 36),

              // Email
              _buildField(
                controller: _emailCtrl,
                label: 'Adresse email',
                hint: 'votre@email.com',
                icon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Mot de passe
              _buildField(
                controller: _passCtrl,
                label: 'Mot de passe',
                hint: '••••••••',
                icon: LucideIcons.lock,
                obscure: !_showPass,
                suffix: GestureDetector(
                  onTap: () => setState(() => _showPass = !_showPass),
                  child: Icon(
                    _showPass ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 18,
                    color: kTextSub,
                  ),
                ),
                onSubmit: (_) => _login(),
              ),
              const SizedBox(height: 12),

              // Erreur
              if (_error != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: kRed.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(LucideIcons.alertCircle,
                        size: 14, color: kRed),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                color: kRed, fontSize: 13))),
                  ]),
                ),

              const SizedBox(height: 24),

              // Bouton connexion
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor:
                        kAccent.withOpacity(0.6),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white),
                        )
                      : const Text('Se connecter',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 32),

              // Info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.info,
                        size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vos identifiants ont été envoyés par email par votre architecte. Contactez-le si vous n\'avez pas reçu d\'email.',
                        style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kTextSub,
                letterSpacing: 0.3)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          onSubmitted: onSubmit,
          style: const TextStyle(fontSize: 14, color: kTextMain),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Color(0xFFD1D5DB)),
            prefixIcon: Padding(
              padding:
                  const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, size: 18, color: kTextSub),
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
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
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
                borderSide: BorderSide(color: kAccent, width: 2)),
          ),
        ),
      ],
    );
  }
}