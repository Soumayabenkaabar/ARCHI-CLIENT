// ══════════════════════════════════════════════════════════════════════════════
//  WIDGET GESTION ACCÈS PORTAIL CLIENT
//  À intégrer dans projet_detail_screen.dart (bouton "Portail client")
//  ou comme onglet dédié
// ══════════════════════════════════════════════════════════════════════════════
//
//  Usage dans ProjetDetailScreen :
//    ElevatedButton(
//      onPressed: () => showDialog(context: context, builder: (_) =>
//        ClientPortalManagerDialog(project: widget.project, architecteNom: 'Ahmed Bennani')),
//      child: Text('Gérer accès client'),
//    )
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/project.dart';
import '../service/client_portal_service.dart';

class ClientPortalManagerDialog extends StatefulWidget {
  final Project project;
  final String architecteNom;
  const ClientPortalManagerDialog({
    super.key,
    required this.project,
    required this.architecteNom,
  });
  @override State<ClientPortalManagerDialog> createState() => _ClientPortalManagerDialogState();
}

class _ClientPortalManagerDialogState extends State<ClientPortalManagerDialog> {
  List<ClientAccess> _accesses = [];
  bool _loading = true;
  bool _adding  = false;

  final _nomCtrl   = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _nomCtrl.dispose(); _emailCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final list = await ClientPortalService.getAccessList(widget.project.id);
      if (mounted) setState(() { _accesses = list; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _createAccess() async {
    final nom   = _nomCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (nom.isEmpty)   { _snack('Nom du client obligatoire', kRed); return; }
    if (email.isEmpty) { _snack('Email obligatoire', kRed); return; }
    if (!email.contains('@')) { _snack('Email invalide', kRed); return; }

    setState(() => _adding = true);
    try {
      await ClientPortalService.createAccess(
        projetId:      widget.project.id,
        projetTitre:   widget.project.titre,
        clientNom:     nom,
        clientEmail:   email,
        architecteNom: widget.architecteNom,
      );
      _nomCtrl.clear();
      _emailCtrl.clear();
      _snack('Accès créé — mot de passe envoyé par email ✓', kGreen);
      await _load();
    } catch (e) {
      _snack('Erreur : ${e.toString().replaceAll('Exception: ', '')}', kRed);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _resetPassword(ClientAccess access) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Réinitialiser le mot de passe ?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text('Un nouveau mot de passe sera envoyé à ${access.clientEmail}.', style: const TextStyle(color: kTextSub, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer', style: TextStyle(color: kAccent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ClientPortalService.resetPassword(
        accessId:      access.id,
        clientEmail:   access.clientEmail,
        clientNom:     access.clientNom,
        projetTitre:   widget.project.titre,
        architecteNom: widget.architecteNom,
      );
      _snack('Nouveau mot de passe envoyé à ${access.clientEmail} ✓', kGreen);
    } catch (e) { _snack('Erreur envoi email', kRed); }
  }

  Future<void> _deleteAccess(ClientAccess access) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer l\'accès ?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text('${access.clientNom} ne pourra plus accéder au portail.', style: const TextStyle(color: kTextSub, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: kRed, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true) return;
    await ClientPortalService.deleteAccess(access.id);
    await _load();
    _snack('Accès supprimé', kRed);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Column(children: [

          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kAccent.withOpacity(0.15))),
            ),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.users, color: kAccent, size: 20)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Portail Client', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kAccent)),
                Text('Gérez les accès — ${widget.project.titre}', style: const TextStyle(color: kTextSub, fontSize: 12)),
              ])),
              GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(LucideIcons.x, size: 20, color: kTextSub)),
            ]),
          ),

          // ── Corps scrollable ─────────────────────────────────────────────
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Formulaire ajout ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('DONNER L\'ACCÈS À UN CLIENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(icon: LucideIcons.user, hint: 'Nom du client', ctrl: _nomCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(icon: LucideIcons.mail, hint: 'Email du client', ctrl: _emailCtrl, keyboard: TextInputType.emailAddress)),
                  ]),
                  const SizedBox(height: 12),

                  // Info email
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(LucideIcons.send, size: 12, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 7),
                      const Expanded(child: Text('Un email avec le mot de passe sera automatiquement envoyé au client.', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11))),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _adding ? null : _createAccess,
                      icon: _adding
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.userPlus, size: 15, color: Colors.white),
                      label: Text(_adding ? 'Envoi en cours...' : 'Créer l\'accès et envoyer le mot de passe', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      style: ElevatedButton.styleFrom(backgroundColor: kAccent, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Liste accès existants ────────────────────────────────────
              Row(children: [
                const Text('ACCÈS EXISTANTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.5)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('${_accesses.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kAccent))),
              ]),
              const SizedBox(height: 10),

              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: kAccent)))
              else if (_accesses.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: const Center(child: Column(children: [
                    Icon(LucideIcons.users, size: 28, color: kTextSub),
                    SizedBox(height: 8),
                    Text('Aucun accès client créé', style: TextStyle(color: kTextSub, fontSize: 13)),
                  ])),
                )
              else
                ..._accesses.map((a) => _accessCard(a)),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _accessCard(ClientAccess a) {
    final lastLogin = a.lastLogin != null
        ? a.lastLogin!.substring(0, 10)
        : 'Jamais connecté';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: a.actif ? const Color(0xFFE5E7EB) : const Color(0xFFFECACA)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar
          Container(width: 40, height: 40, decoration: BoxDecoration(color: a.actif ? kAccent.withOpacity(0.1) : const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)), child: Icon(LucideIcons.user, size: 18, color: a.actif ? kAccent : kRed)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.clientNom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextMain)),
            Text(a.clientEmail, style: const TextStyle(color: kTextSub, fontSize: 12)),
          ])),
          // Badge actif/inactif
          GestureDetector(
            onTap: () async {
              await ClientPortalService.toggleAccess(a.id, !a.actif);
              await _load();
              _snack(a.actif ? 'Accès désactivé' : 'Accès réactivé', a.actif ? kRed : kGreen);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: a.actif ? kGreen.withOpacity(0.1) : kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: a.actif ? kGreen : kRed, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(a.actif ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: a.actif ? kGreen : kRed)),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 10),

        Row(children: [
          // Dernière connexion
          Icon(LucideIcons.clock, size: 11, color: kTextSub),
          const SizedBox(width: 5),
          Text(lastLogin, style: const TextStyle(fontSize: 11, color: kTextSub)),
          const Spacer(),
          // Actions
          _actionBtn(LucideIcons.refreshCw, 'Renvoyer', const Color(0xFF3B82F6), () => _resetPassword(a)),
          const SizedBox(width: 8),
          _actionBtn(LucideIcons.trash2, 'Supprimer', kRed, () => _deleteAccess(a)),
        ]),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _field({required IconData icon, required String hint, required TextEditingController ctrl, TextInputType keyboard = TextInputType.text}) => TextField(
    controller: ctrl, keyboardType: keyboard,
    style: const TextStyle(fontSize: 13, color: kTextMain),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: kTextSub, fontSize: 12),
      prefixIcon: Padding(padding: const EdgeInsets.only(left: 10, right: 8), child: Icon(icon, size: 14, color: kTextSub)),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccent, width: 2)),
    ),
  );
}
