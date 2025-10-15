import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../pages/pg_home.dart';
import 'auth_login.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        if (user.isAnonymous) {
          FirebaseAuth.instance.signOut();
          return const LoginPage();
        }

        return const HomePage();
      },
    );
  }
}
