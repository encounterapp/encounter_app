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

  // Verify email with token
  Future<bool> verifyEmail({required String email, required String token}) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      
      return response.session != null;
    } catch (e) {
      print('Error verifying email: $e');
      return false;
    }
  }
  
  // Resend verification email
  Future<void> resendVerificationCode({required String email}) async {
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } catch (e) {
      print('Error resending verification code: $e');
      rethrow;
    }
  }
  
  // Send password reset email
  @override
  Future<void> resetPasswordForEmail({required String email}) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: null, // We'll handle it in-app, not with redirects
      );
    } catch (e) {
      print('Error requesting password reset: $e');
      rethrow;
    }
  }
  
  // Verify password reset with token and set new password
  Future<bool> verifyPasswordReset({
    required String email, 
    required String token, 
    required String newPassword
  }) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      
      if (response.session != null) {
        // Now update the password
        await supabase.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Error verifying password reset: $e');
      return false;
    }
  }


}