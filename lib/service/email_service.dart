// lib/service/email_service.dart
// NOTE: L'envoi principal des identifiants se fait via la Edge Function Supabase
// (send-welcome-email). Ce service est gardé pour d'autres usages email si nécessaire.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailService {
  static const String _brevoApiKey =
      'VOTRE_CLE_BREVO_ICI'; // Remplacez par votre clé Brevo
  static const String _fromEmail = 'soumayabenkaabar4@gmail.com';
  static const String _fromName = 'ArchiManager';

  // ── Envoie un email générique via Brevo ───────────────────────────────────
  static Future<void> sendEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String htmlContent,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.brevo.com/v3/smtp/email'),
      headers: {
        'api-key': _brevoApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'sender': {'name': _fromName, 'email': _fromEmail},
        'to': [{'email': toEmail, 'name': toName}],
        'subject': subject,
        'htmlContent': htmlContent,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('Erreur email: ${response.statusCode} — ${response.body}');
      throw Exception('Erreur envoi email : ${response.body}');
    }
  }

  // ── Envoie les identifiants client (appelé par Edge Function maintenant) ──
  // Gardé pour compatibilité si besoin d'appel direct
  static Future<void> sendClientPassword({
    required String toEmail,
    required String clientNom,
    required String motDePasse,
    required String projetTitre,
    required String architecteNom,
  }) async {
    final html = _buildEmailHtml(
      clientNom: clientNom,
      motDePasse: motDePasse,
      projetTitre: projetTitre,
      architecteNom: architecteNom,
      toEmail: toEmail,
    );

    await sendEmail(
      toEmail: toEmail,
      toName: clientNom,
      subject: '🏗️ Accès à votre portail projet — $projetTitre',
      htmlContent: html,
    );
  }

  // ── Template HTML email ───────────────────────────────────────────────────
  static String _buildEmailHtml({
    required String clientNom,
    required String motDePasse,
    required String projetTitre,
    required String architecteNom,
    required String toEmail,
  }) =>
      '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background:#F3F4F6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F3F4F6;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width:560px;background:#FFFFFF;border-radius:16px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">
          <tr>
            <td style="background:linear-gradient(135deg,#1F2937,#374151);padding:36px 40px;text-align:center;">
              <span style="color:#FFFFFF;font-size:22px;font-weight:800;">🏗️ ArchiManager</span>
              <p style="color:#9CA3AF;font-size:13px;margin:10px 0 0;">Portail Client</p>
            </td>
          </tr>
          <tr>
            <td style="padding:36px 40px;">
              <h2 style="color:#111827;font-size:20px;font-weight:700;margin:0 0 8px;">Bonjour $clientNom 👋</h2>
              <p style="color:#6B7280;font-size:14px;line-height:1.6;margin:0 0 24px;">
                <strong>$architecteNom</strong> vous a accordé l'accès à votre portail de suivi de projet.
              </p>
              <div style="background:#FFF7ED;border:1px solid #FED7AA;border-radius:10px;padding:16px 20px;margin-bottom:24px;">
                <p style="color:#92400E;font-size:11px;font-weight:700;margin:0 0 6px;">VOTRE PROJET</p>
                <p style="color:#1F2937;font-size:16px;font-weight:700;margin:0;">📐 $projetTitre</p>
              </div>
              <div style="background:#F9FAFB;border:1px solid #E5E7EB;border-radius:10px;padding:20px;margin-bottom:24px;">
                <p style="color:#6B7280;font-size:11px;font-weight:700;letter-spacing:0.5px;margin:0 0 14px;">VOS IDENTIFIANTS</p>
                <p style="margin:0 0 8px;"><span style="color:#6B7280;font-size:12px;">Email</span><br>
                <span style="color:#111827;font-size:14px;font-weight:600;">$toEmail</span></p>
                <p style="margin:0;"><span style="color:#6B7280;font-size:12px;">Mot de passe</span><br>
                <span style="background:#1F2937;color:#F59E0B;font-family:monospace;font-size:20px;font-weight:800;padding:8px 14px;border-radius:8px;display:inline-block;letter-spacing:2px;margin-top:4px;">$motDePasse</span></p>
              </div>
              <p style="color:#EF4444;font-size:12px;margin:0;">⚠️ Changez votre mot de passe après la première connexion.</p>
            </td>
          </tr>
          <tr>
            <td style="background:#F9FAFB;border-top:1px solid #E5E7EB;padding:20px 40px;text-align:center;">
              <p style="color:#9CA3AF;font-size:11px;margin:0;">
                Envoyé par <strong>$architecteNom</strong> via ArchiManager.<br>
                ⚠️ Ne partagez jamais votre mot de passe.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
}