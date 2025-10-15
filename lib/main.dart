import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'config/auth/auth_gate.dart';
import 'pages/pg_home.dart';
import 'pages/pg_waste_scanner.dart';
import 'pages/pg_map.dart';
import 'pages/pg_stat_tracker.dart';
import 'pages/pg_games.dart';
import 'pages/pg_profile.dart';
import 'pages/pg_leaderboard.dart';
import 'config/auth/auth_login.dart';
import 'pages/pg_events.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(".env not found, skipping: $e");
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _czekajNaAuth();

  runApp(const EcoMain());
}

Future<void> _czekajNaAuth() async {
  await FirebaseAuth.instance.authStateChanges().first;
}

class EcoMain extends StatelessWidget {
  const EcoMain({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoLPU',
      home: const AuthGate(),
      routes: {
        '/scanner': (context) => const ClassifierPage(),
        '/home': (context) => const HomePage(),
        '/map': (context) => const MapPage(),
        '/trackImpact': (context) => const TrackImpactPage(),
        '/game': (context) => const MinigamesPage(),
        '/profile': (context) => const ProfilePage(),
        '/login': (context) => const LoginPage(),
        '/leaderboard': (context) => const LeaderboardPage(),
        '/events': (context) => const EventsPage(),
      },
    );
  }
}