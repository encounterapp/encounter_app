import 'package:encounter_app/pages/home_page.dart';
import 'package:encounter_app/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthStateListener extends StatelessWidget {
  const SupabaseAuthStateListener({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.session != null) {
          return HomePage(selectedIndex: 0,);
        } else {
          return SplashPage();
        }
      },
    );
  }
}
