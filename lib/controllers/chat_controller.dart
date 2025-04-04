import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:encounter_app/utils/age_verification_utils.dart';

class ChatController with ChangeNotifier {
  // Dependencies
  final String recipientId;
  final VoidCallback? onChatEnded;
  final SupabaseClient supabase;
  
  // State variables
  String? currentUserId;
  String? recipientUsername;
  String? recipientProfilePic;
  List<Map<String, dynamic>> _messages = [];
  bool _isChatEnded = false;
  bool _isInitialized = false;
  
  // Age verification state
  bool _ageVerified = false;
  bool _ageGapWarningNeeded = false;
  bool _isCurrentUserMinor = false;
  bool _isRecipientMinor = false;
  Map<String, dynamic>? _ageData;
  
  // Stream controllers and channels
  Stream<List<Map<String, dynamic>>>? _messagesStream;
  RealtimeChannel? _chatStatusChannel;
  
  // Getters
  Stream<List<Map<String, dynamic>>>? get messagesStream => _messagesStream;
  List<Map<String, dynamic>> get messages => _messages;
  bool get isChatEnded => _isChatEnded;
  bool get isInitialized => _isInitialized;
  bool get ageVerified => _ageVerified;
  bool get ageGapWarningNeeded => _ageGapWarningNeeded;
  bool get isCurrentUserMinor => _isCurrentUserMinor;
  bool get isRecipientMinor => _isRecipientMinor;
  Map<String, dynamic>? get ageData => _ageData;
  
  // Constructor
  ChatController({
    required this.recipientId,
    required this.supabase,
    this.onChatEnded,
  }) {
    _init();
  }
  
  // Initialize the controller
  Future<void> _init() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;
    
    currentUserId = currentUser.id;
    
    // Load data sequentially
    await _checkIfChatIsEnded();
    await _fetchUserProfile();
    await _checkAgeVerification();
    
    _setupMessagesStream();
    _setupChatStatusListener();
    
    _isInitialized = true;
    notifyListeners();
  }
  
  // Check age verification status
  Future<void> _checkAgeVerification() async {
    if (currentUserId == null) return;
    
    // Check if age verification has been acknowledged
    final hasAcknowledged = await AgeVerificationUtils.hasAcknowledgedAgeVerification(
      currentUserId!,
      recipientId,
    );
    
    // Get age data
    final ageData = await AgeVerificationUtils.checkAgeGap(
      currentUserId!,
      recipientId,
    );
    
    _ageVerified = hasAcknowledged;
    _ageGapWarningNeeded = ageData['ageGapWarningNeeded'];
    _ageData = ageData;
    
    // Determine if current user or recipient is minor
    final currentUserData = ageData['user1']['id'] == currentUserId 
        ? ageData['user1'] 
        : ageData['user2'];
    final recipientData = ageData['user1']['id'] == currentUserId 
        ? ageData['user2'] 
        : ageData['user1'];
        
    _isCurrentUserMinor = currentUserData['isMinor'];
    _isRecipientMinor = recipientData['isMinor'];
    
    notifyListeners();
  }
  
  // Mark age verification as acknowledged
  Future<void> acknowledgeAgeVerification() async {
    if (currentUserId == null) return;
    
    await AgeVerificationUtils.saveAgeVerificationAcknowledgment(
      currentUserId!,
      recipientId,
    );
    
    _ageVerified = true;
    notifyListeners();
  }
  
  // Check if chat has been ended
  Future<void> _checkIfChatIsEnded() async {
    if (currentUserId == null) return;
    
    try {
      final response = await supabase
          .from('chat_sessions')
          .select('status')
          .or('and(user1_id.eq.$currentUserId,user2_id.eq.$recipientId),and(user1_id.eq.$recipientId,user2_id.eq.$currentUserId)')
          .limit(1)
          .maybeSingle();

      if (response != null && response['status'] == 'ended') {
        _isChatEnded = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error checking if chat is ended: $e");
    }
  }
  
  // Fetch recipient profile info
  Future<void> _fetchUserProfile() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('username, avatar_url, age')
          .eq('id', recipientId)
          .maybeSingle();

      if (response != null) {
        recipientUsername = response['username'] ?? "Unknown User";
        recipientProfilePic = response['avatar_url'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }
  
  // Set up messages stream
  void _setupMessagesStream() {
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((messages) {
      final filteredMessages = messages.where((msg) {
        final senderId = msg['sender_id'];
        final receiverId = msg['receiver_id'];
        return (senderId == currentUserId && receiverId == recipientId) ||
            (senderId == recipientId && receiverId == currentUserId);
      }).toList();

      _messages = filteredMessages;
      notifyListeners();

      return filteredMessages;
    });
  }
  
  // Set up chat status listener
  void _setupChatStatusListener() {
    if (currentUserId == null) return;
    
    final String channelName = 'chat_status_${currentUserId}_$recipientId';
    
    _chatStatusChannel = supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_sessions',
          callback: (payload) {
            final Map<String, dynamic> newRecord = payload.newRecord;
            final String user1Id = newRecord['user1_id'];
            final String user2Id = newRecord['user2_id'];
            
            if ((user1Id == currentUserId && user2Id == recipientId) ||
                (user1Id == recipientId && user2Id == currentUserId)) {
              
              if (newRecord['status'] == 'ended') {
                _isChatEnded = true;
                notifyListeners();
              }
            }
          },
        )
        .subscribe();
  }
  
  // Send a message
  Future<void> sendMessage(String text) async {
    if (!_isInitialized || currentUserId == null || _isChatEnded || text.trim().isEmpty) {
      return;
    }
    
    await _checkIfChatIsEnded();
    if (_isChatEnded) return;
    
    final newMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': currentUserId,
      'receiver_id': recipientId,
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    _messages.add(newMessage);
    notifyListeners();

    try {
      await supabase.from('messages').insert({
        'sender_id': newMessage['sender_id'],
        'receiver_id': newMessage['receiver_id'],
        'content': newMessage['content'],
        'created_at': newMessage['created_at'],
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
      throw Exception('Failed to send message: $e');
    }
  }
  
  // End the chat
  Future<void> endChat() async {
    if (_isChatEnded || currentUserId == null) return;
    
    _isChatEnded = true;
    notifyListeners();
    
    try {
      // Create unique key for this chat session
      final smallerId = currentUserId!.compareTo(recipientId) < 0 
          ? currentUserId 
          : recipientId;
      final largerId = currentUserId!.compareTo(recipientId) < 0 
          ? recipientId 
          : currentUserId;
          
      final chatId = '${smallerId}_$largerId';
      
      // Check if chat session exists
      final existingChat = await supabase
          .from('chat_sessions')
          .select()
          .eq('id', chatId)
          .maybeSingle();
      
      if (existingChat != null) {
        // Update existing chat session
        await supabase
            .from('chat_sessions')
            .update({
              'status': 'ended',
              'ended_at': DateTime.now().toUtc().toIso8601String(),
              'ended_by': currentUserId,
            })
            .eq('id', chatId);
      } else {
        // Create new chat session
        await supabase
            .from('chat_sessions')
            .insert({
              'id': chatId,
              'user1_id': smallerId,
              'user2_id': largerId,
              'status': 'ended',
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'ended_at': DateTime.now().toUtc().toIso8601String(),
              'ended_by': currentUserId,
            });
      }
      
      // Add system message about chat ending
      await supabase.from('messages').insert({
        'sender_id': currentUserId,
        'receiver_id': recipientId,
        'content': 'Chat has been ended.',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_system_message': true,
      });
      
      // Call the callback if provided
      if (onChatEnded != null) {
        onChatEnded!();
      }
    } catch (e) {
      debugPrint("Error ending chat: $e");
      // Rollback state on error
      _isChatEnded = false;
      notifyListeners();
      throw Exception('Failed to end chat: $e');
    }
  }
  
  // Clean up resources
  void dispose() {
    _chatStatusChannel?.unsubscribe();
    super.dispose();
  }
}