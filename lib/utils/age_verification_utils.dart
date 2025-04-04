import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgeVerificationUtils {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Check if either user is under 18
  static Future<Map<String, dynamic>> checkAgeGap(String userId1, String userId2) async {
    try {
      // Get age for first user
      final user1Data = await _supabase
          .from('profiles')
          .select('age, username')
          .eq('id', userId1)
          .maybeSingle();
          
      // Get age for second user
      final user2Data = await _supabase
          .from('profiles')
          .select('age, username')
          .eq('id', userId2)
          .maybeSingle();
      
      // Default values if data is missing
      final int age1 = user1Data?['age'] ?? 0;
      final int age2 = user2Data?['age'] ?? 0;
      final String username1 = user1Data?['username'] ?? 'Unknown User';
      final String username2 = user2Data?['username'] ?? 'Unknown User';
      
      final bool user1IsMinor = age1 > 0 && age1 < 18;
      final bool user2IsMinor = age2 > 0 && age2 < 18;
      
      return {
        'user1': {
          'id': userId1,
          'age': age1,
          'username': username1,
          'isMinor': user1IsMinor,
        },
        'user2': {
          'id': userId2,
          'age': age2,
          'username': username2,
          'isMinor': user2IsMinor,
        },
        'ageGapWarningNeeded': (user1IsMinor && !user2IsMinor) || (!user1IsMinor && user2IsMinor),
        'bothMinors': user1IsMinor && user2IsMinor,
      };
    } catch (e) {
      debugPrint('Error checking age gap: $e');
      return {
        'user1': {'id': userId1, 'isMinor': false},
        'user2': {'id': userId2, 'isMinor': false},
        'ageGapWarningNeeded': false,
        'bothMinors': false,
      };
    }
  }
  
  /// Show age verification warning dialog
  static Future<bool> showAgeVerificationWarning(
    BuildContext context, 
    Map<String, dynamic> ageData,
    String currentUserId,
  ) async {
    // Determine which user is the minor and which is the adult
    final currentUserData = ageData['user1']['id'] == currentUserId 
        ? ageData['user1'] 
        : ageData['user2'];
    final otherUserData = ageData['user1']['id'] == currentUserId 
        ? ageData['user2'] 
        : ageData['user1'];
    
    final bool currentUserIsMinor = currentUserData['isMinor'];
    final bool otherUserIsMinor = otherUserData['isMinor'];
    
    // Select appropriate message based on who is the minor
    String warningMessage;
    
    if (currentUserIsMinor && !otherUserIsMinor) {
      warningMessage = 'You are under 18 and chatting with ${otherUserData['username']}, '
          'who is 18 or older. For safety reasons, please be careful about sharing '
          'personal information and consider involving a trusted adult in your communication.';
    } else if (!currentUserIsMinor && otherUserIsMinor) {
      warningMessage = '${otherUserData['username']} is under 18. Please be respectful '
          'and mindful of appropriate conversation topics. Inappropriate communications '
          'with minors may violate our Terms of Service and applicable laws.';
    } else {
      // Should not happen but just in case
      warningMessage = 'Please be respectful in all communications and follow our community guidelines.';
    }
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[700]),
              const SizedBox(width: 10),
              const Text('Age Verification Notice'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(warningMessage),
              const SizedBox(height: 20),
              const Text(
                'By continuing, you acknowledge this notice and agree to follow community guidelines.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('I UNDERSTAND'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }
  
  /// Save age verification acknowledgment to prevent repeated warnings
  static Future<void> saveAgeVerificationAcknowledgment(String userId1, String userId2) async {
    try {
      // Sort user IDs to ensure consistent chat ID
      final String smallerId = userId1.compareTo(userId2) < 0 ? userId1 : userId2;
      final String largerId = userId1.compareTo(userId2) < 0 ? userId2 : userId1;
      final String chatId = '${smallerId}_${largerId}';
      
      // Check if verification record exists
      final existingRecord = await _supabase
          .from('age_verifications')
          .select()
          .eq('chat_id', chatId)
          .maybeSingle();
      
      if (existingRecord == null) {
        // Create new record
        await _supabase.from('age_verifications').insert({
          'chat_id': chatId,
          'user1_id': smallerId,
          'user2_id': largerId,
          'acknowledged_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error saving age verification: $e');
    }
  }
  
  /// Check if age verification has been acknowledged
  static Future<bool> hasAcknowledgedAgeVerification(String userId1, String userId2) async {
    try {
      // Sort user IDs to ensure consistent chat ID
      final String smallerId = userId1.compareTo(userId2) < 0 ? userId1 : userId2;
      final String largerId = userId1.compareTo(userId2) < 0 ? userId2 : userId1;
      final String chatId = '${smallerId}_${largerId}';
      
      // Check if verification record exists
      final existingRecord = await _supabase
          .from('age_verifications')
          .select()
          .eq('chat_id', chatId)
          .maybeSingle();
      
      return existingRecord != null;
    } catch (e) {
      debugPrint('Error checking age verification: $e');
      return false;
    }
  }
}