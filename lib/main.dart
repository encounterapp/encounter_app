import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/auth_gate.dart';
import 'package:encounter_app/pages/premium_page.dart';
import 'package:encounter_app/pages/blocked_users_page.dart';
import 'package:encounter_app/pages/my_reports_page.dart';
import 'package:encounter_app/pages/language_settings_page.dart';


Future<void> main() async {
  await Supabase.initialize(
    url: 'https://knsdbtqfmjrdhogzvtdz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtuc2RidHFmbWpyZGhvZ3p2dGR6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE4MjI1OTMsImV4cCI6MjA1NzM5ODU5M30.riFtHkhiH1drvhErn7fj9CF8KLj_0Zl_WIQPW5OgHjE',
  );
  runApp(MyApp());
}
        

// Get a reference your Supabase client
final supabase = Supabase.instance.client;


  class MyApp extends StatelessWidget {
    const MyApp({super.key});
  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Encounter App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
      ),
      home: SupabaseAuthStateListener(),
      routes: {
        '/premium': (context) => const PremiumPage(),
        '/blocked_users': (context) => const BlockedUsersPage(),
        '/my_reports': (context) => const MyReportsPage(),
        '/language_settings': (context) => const LanguageSettingsPage(),
      },
    );
  }
}


