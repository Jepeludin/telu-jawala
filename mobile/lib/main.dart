import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/api_service.dart';

void main() {
  runApp(const JawalaApp());
}

class JawalaApp extends StatelessWidget {
  const JawalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JAWALA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF25C5C)),
      ),
      // Jika token tersimpan -> langsung ke Home, jika tidak -> Login
      home: FutureBuilder<String?>(
        future: ApiService.getToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data != null ? const HomePage() : const LoginPage();
        },
      ),
    );
  }
}
