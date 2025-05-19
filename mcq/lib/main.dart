import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mcq/firebase_options.dart';
import 'package:mcq/mcq_page.dart';
import 'package:mcq/authentication/log_in.dart';
import 'package:mcq/authentication/sign_up.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // <-- Add this line
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/mcq': (context) => const McqPage(),
      },
      // Remove the home:McqPage(), line
    );
  }
}
