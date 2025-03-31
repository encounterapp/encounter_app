import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/auth_gate.dart';


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
      home: SupabaseAuthStateListener(),
    );
  }
}


