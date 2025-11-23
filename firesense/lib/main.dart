import 'package:firebase_core/firebase_core.dart';
import 'package:firesense/credentials/auth_gate.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FireSense',
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}
