import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class SupabaseAuthService {
  final supabase = Supabase.instance.client;
  
  //Sign In with Email and Password
  Future<AuthResponse> signInWithEmailPassword({required String email, required String password}) async {
     return await supabase.auth.signInWithPassword(
        email: email, 
        password: password);
    }

  // Sign In with Google
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Initialize Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      
      // Start the sign-in process
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      // If the user canceled the sign-in process
      if (googleUser == null) {
        throw Exception('Google sign in canceled by user');
      }
      
      // Get authentication from Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Get ID token and access token
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;
      
      if (idToken == null) {
        throw Exception('No ID Token found');
      }
      
      // Use the tokens to sign in with Supabase
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      return response;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }
  
  // Sign In with Apple
  Future<AuthResponse> signInWithApple() async {
    try {
      // Generate a random string to be used as nonce
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      
      // Request Apple sign in
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      
      // Use the credential to sign in with Supabase
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('No ID Token found');
      }
      
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      
      return response;
    } catch (e) {
      debugPrint('Error signing in with Apple: $e');
      rethrow;
    }
  }
  
  // Helper function to generate a random nonce
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
  
  // Helper function to perform SHA-256 hashing
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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