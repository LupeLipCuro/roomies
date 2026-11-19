import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/group_setup_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RoomiesApp());
}

const kTeal = Color(0xFF0F766E);
const kBg = Color(0xFFF6F4EF);
const kInk = Color(0xFF14211F);

class RoomiesApp extends StatelessWidget {
  const RoomiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roomies',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kTeal, primary: kTeal),
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(backgroundColor: kBg, foregroundColor: kInk, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Sin sesión -> AuthScreen. Con sesión y sin grupo -> GroupSetupScreen. Con grupo -> HomeScreen.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final data = DataService();
    return StreamBuilder<User?>(
      stream: auth.authState,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Loading();
        final user = snap.data;
        if (user == null) return const AuthScreen();
        return StreamBuilder<Group?>(
          stream: data.myGroup(user.uid),
          builder: (context, gsnap) {
            if (gsnap.connectionState == ConnectionState.waiting) return const _Loading();
            final group = gsnap.data;
            if (group == null) return GroupSetupScreen(user: user);
            return HomeScreen(user: user, group: group);
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
