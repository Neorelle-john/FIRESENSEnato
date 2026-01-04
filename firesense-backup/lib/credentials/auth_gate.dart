import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/admin_side/home_screen.dart';
import 'package:firesense/user_side/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'signin_screen.dart';

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
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          // Route to admin if email matches
          if (user.email == 'admin@gmail.com') {
            return const AdminHomeScreen();
          } else {
            return const HomeScreen();
          }
        }
        return const SignInScreen();
      },
    );
  }
}
