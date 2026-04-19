// lib/screens/client_change_password_screen.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../service/client_auth_service.dart';
import 'client_portal_screen.dart';

class ClientChangePasswordScreen extends StatefulWidget {
  final ClientSession session;
  const ClientChangePasswordScreen({super.key, required this.session});

  @override
  State<ClientChangePasswordScreen> createState() =>
      _ClientChangePasswordScreenState();
}

class _ClientChangePasswordScreenState
    extends State<ClientChangePasswordScreen> {
  final _newPassCtrl    = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  bool _loading         = false;
  bool _showNew         = false;
  bool _showConfirm     = false;
  String? _error;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final newPass     = _newPassCtrl.text.trim();
    final confirmPass = _confirmCtrl.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs.');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // 1. Change le mot de passe dans Supabase Auth
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );

      // 2. Marque password_changed = true dans client_portal_access
      await Supabase.instance.client
          .from('client_portal_access')
          .update({'password_changed': true})
          .eq('id', widget.session.id);

      // 3. Met à jour la session locale
      final updatedSession = ClientSession(
        id: widget.session.id,
        projetId: widget.session.projetId,
        clientNom: widget.session.clientNom,
        clientEmail: widget.session.clientEmail,
        passwordChanged: true,
      );

      await ClientAuthService.saveSession(updatedSession);

      if (!mounted) return;

      // 4. Redirige vers le portail
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ClientPortalScreen(session: updatedSession),
        ),
      );
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(LucideIcons.keyRound, color: kAccent, size: 26),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Changer votre\nmot de passe',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: kTextMain,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pour votre sécurité, définissez un nouveau mot de passe avant d\'accéder à votre espace.',
                  style: TextStyle(color: kTextSub, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 32),

                // Nouveau mot de passe
                _buildField(
                  controller: _newPassCtrl,
                  label: 'Nouveau mot de passe',
                  hint: 'Minimum 8 caractères',
                  obscure: !_showNew,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _showNew = !_showNew),
                    child: Icon(
                      _showNew ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18,
                      color: kTextSub,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Confirmer
                _buildField(
                  controller: _confirmCtrl,
                  label: 'Confirmer le mot de passe',
                  hint: 'Répétez le mot de passe',
                  obscure: !_showConfirm,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _showConfirm = !_showConfirm),
                    child: Icon(
                      _showConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18,
                      color: kTextSub,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Erreur
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: kRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kRed.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Icon(LucideIcons.alertCircle, size: 14, color: kRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: TextStyle(color: kRed, fontSize: 13)),
                      ),
                    ]),
                  ),

                const SizedBox(height: 24),

                // Bouton
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'Confirmer et accéder à mon espace',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    Widget? suffix,
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
          obscureText: obscure,
          onSubmitted: (_) => _changePassword(),
          style: const TextStyle(fontSize: 14, color: kTextMain),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 10),
              child: Icon(LucideIcons.lock, size: 18, color: kTextSub),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 14), child: suffix)
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kAccent, width: 2)),
          ),
        ),
      ],
    );
  }
}