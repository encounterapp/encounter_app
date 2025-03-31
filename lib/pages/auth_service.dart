import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final supabase = Supabase.instance.client;
  
  //Sign In with Email and Password
  Future<AuthResponse> signInWithEmailPassword({required String email, required String password}) async {
     return await supabase.auth.signInWithPassword(
        email: email, 
        password: password);
    }




  //Sign Up with Email and Password
  Future<AuthResponse> signUpWithEmailPassword({required String email, required String password}) async {
      return await supabase.auth.signUp(
        email: email, 
        password: password);
        
    }

  //Sign Out
  Future<void> signOut() async {
     await supabase.auth.signOut();
    }
  
  //Reset Password
  Future<void> resetPasswordForEmail({required String email}) async {
      return await supabase.auth.resetPasswordForEmail(email);
    } 

  //Update User Password
  Future<UserResponse> updateUserPassword({required String password}) async {
      return await supabase.auth.updateUser(UserAttributes(password: password));
    }

  //Get Current User Session
  Session? get currentSection {
    return supabase.auth.currentSession;
  }

  //Get Current User
  User? get currentUser {
    return supabase.auth.currentUser;
  }


}