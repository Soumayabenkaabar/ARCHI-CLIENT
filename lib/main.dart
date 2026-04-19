// lib/main.dart — App Client ArchiManager
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/colors.dart';
import 'screens/client_login_screen.dart';
import 'screens/client_portal_screen.dart';
import 'service/client_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:    'https://ngcnfbbeefsbynknvogm.supabase.co',
    anonKey:'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5nY25mYmJlZWZzYnlua252b2dtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0NjQzMDQsImV4cCI6MjA5MTA0MDMwNH0.IR7YemXmFb27rolXbkzUQUFv2SU7q1fsVh4O2kU4yb0',
  );

  // Vérifie si une session existe
  final session = await ClientAuthService.getSession();

  runApp(ArchiClientApp(initialSession: session));
}

class ArchiClientApp extends StatelessWidget {
  final ClientSession? initialSession;
  const ArchiClientApp({super.key, this.initialSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArchiManager Client',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
      theme: ThemeData(
        primaryColor: kAccent,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.light(primary: kAccent, secondary: kAccent),
        fontFamily: 'SF Pro Display',
        useMaterial3: false,
      ),
      home: initialSession != null
          ? ClientPortalScreen(session: initialSession!)
          : const ClientLoginScreen(),
    );
  }
}
