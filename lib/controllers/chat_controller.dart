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
  
  // Meeting state
  bool _currentUserRequestedMeeting = false;
  bool _recipientRequestedMeeting = false;
  bool _meetingConfirmed = false;
  
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
  
  // Meeting state getters
  bool get currentUserRequestedMeeting => _currentUserRequestedMeeting;
  bool get recipientRequestedMeeting => _recipientRequestedMeeting;
  bool get meetingConfirmed => _meetingConfirmed;
  bool get canRequestMeeting => !_isChatEnded && !_currentUserRequestedMeeting;
  
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
    await _checkMeetingStatus();
    
    _setupMessagesStream();
    _setupChatStatusListener();
    _setupMeetingStatusListener();
    
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
  
  // Check meeting status
  Future<void> _checkMeetingStatus() async {
    if (currentUserId == null) return;
    
    try {
      // Create unique key for this chat session
      final smallerId = currentUserId!.compareTo(recipientId) < 0 
          ? currentUserId 
          : recipientId;
      final largerId = currentUserId!.compareTo(recipientId) < 0 
          ? recipientId 
          : currentUserId;
          
      final chatId = '${smallerId}_$largerId';
      
      // Check if chat session exists and get meeting status
      final existingChat = await supabase
          .from('chat_sessions')
          .select()
          .eq('id', chatId)
          .maybeSingle();
      
      if (existingChat != null) {
        // Set meeting state based on database values
        final user1Requested = existingChat['user1_meeting_requested'] ?? false;
        final user2Requested = existingChat['user2_meeting_requested'] ?? false;
        final meetingConfirmed = existingChat['meeting_confirmed'] ?? false;
        
        // Determine which user is the current user
        final isUser1 = currentUserId == smallerId;
        
        _currentUserRequestedMeeting = isUser1 ? user1Requested : user2Requested;
        _recipientRequestedMeeting = isUser1 ? user2Requested : user1Requested;
        _meetingConfirmed = meetingConfirmed;
      }
    } catch (e) {
      debugPrint("Error checking meeting status: $e");
    }
    
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
  
  // Set up meeting status listener
  void _setupMeetingStatusListener() {
    if (currentUserId == null) return;
    
    final String channelName = 'meeting_status_${currentUserId}_$recipientId';
    
    supabase
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
              
              // Create unique key for this chat session to determine user order
              final smallerId = currentUserId!.compareTo(recipientId) < 0 
                  ? currentUserId 
                  : recipientId;
                  
              // Determine if current user is user1 or user2
              final isUser1 = currentUserId == smallerId;
              
              // Update meeting state
              final user1Requested = newRecord['user1_meeting_requested'] ?? false;
              final user2Requested = newRecord['user2_meeting_requested'] ?? false;
              final meetingConfirmed = newRecord['meeting_confirmed'] ?? false;
              
              _currentUserRequestedMeeting = isUser1 ? user1Requested : user2Requested;
              _recipientRequestedMeeting = isUser1 ? user2Requested : user1Requested;
              _meetingConfirmed = meetingConfirmed;
              
              // If meeting was just confirmed, send a system message
              if (_meetingConfirmed && !_isChatEnded) {
                _sendSystemMessage("You both have accepted to meet.");
              }
              
              notifyListeners();
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
  
  // Send a system message
  Future<void> _sendSystemMessage(String text) async {
    if (currentUserId == null || _isChatEnded) return;
    
    try {
      await supabase.from('messages').insert({
        'sender_id': 'system',
        'receiver_id': 'system',
        'content': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_system_message': true,
      });
    } catch (e) {
      debugPrint("Error sending system message: $e");
    }
  }
  
// Request to meet the recipient
  Future<void> requestMeeting() async {
    if (_isChatEnded || currentUserId == null || _currentUserRequestedMeeting) return;
    
    try {
      // Create unique key for this chat session
      final smallerId = currentUserId!.compareTo(recipientId) < 0 
          ? currentUserId 
          : recipientId;
      final largerId = currentUserId!.compareTo(recipientId) < 0 
          ? recipientId 
          : currentUserId;
          
      final chatId = '${smallerId}_$largerId';
      
      // Determine if current user is user1 or user2
      final isUser1 = currentUserId == smallerId;
      
      // Check if chat session exists
      final existingChat = await supabase
          .from('chat_sessions')
          .select()
          .eq('id', chatId)
          .maybeSingle();
      
      final updateData = <String, dynamic>{};
      
      // Use String keys with dynamic values to fix type issues
      if (isUser1) {
        updateData['user1_meeting_requested'] = true;
      } else {
        updateData['user2_meeting_requested'] = true;
      }
      
      // Add meeting_confirmed = true if both users requested meeting
      if ((isUser1 && (existingChat?['user2_meeting_requested'] ?? false)) ||
          (!isUser1 && (existingChat?['user1_meeting_requested'] ?? false))) {
        updateData['meeting_confirmed'] = true;
        updateData['meeting_confirmed_at'] = DateTime.now().toUtc().toIso8601String();
      }
      
      // Add a timestamp for the meeting request
      updateData['meeting_requested_at'] = DateTime.now().toUtc().toIso8601String();
      
      if (existingChat != null) {
        // Update existing chat session
        await supabase
            .from('chat_sessions')
            .update(updateData)
            .eq('id', chatId);
      } else {
        // Create new chat session with meeting request
        final initialData = <String, dynamic>{
          'id': chatId,
          'user1_id': smallerId,
          'user2_id': largerId,
          'status': 'active',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        
        // Add meeting request details
        initialData.addAll(updateData);
        
        await supabase
            .from('chat_sessions')
            .insert(initialData);
      }
      
      // Update local state
      _currentUserRequestedMeeting = true;
      
      // Check if meeting is confirmed after the update
      if ((isUser1 && (existingChat?['user2_meeting_requested'] ?? false)) ||
          (!isUser1 && (existingChat?['user1_meeting_requested'] ?? false))) {
        _meetingConfirmed = true;
        
        // Send system message about meeting confirmation
        await _sendSystemMessage("You both have accepted to meet.");
      } else {
        // Send system message about meeting request
        await _sendSystemMessage("${recipientUsername ?? 'Other user'} will be notified of your interest to meet.");
        
        // Send a message to the recipient
        await _sendMessage("has accepted to meet", isSystemMessage: true);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint("Error requesting meeting: $e");
      throw Exception('Failed to request meeting: $e');
    }
  }
  
  // Send a message with proper sender/receiver
  Future<void> _sendMessage(String content, {bool isSystemMessage = false}) async {
    if (currentUserId == null) return;
    
    try {
      await supabase.from('messages').insert({
        'sender_id': currentUserId,
        'receiver_id': recipientId,
        'content': content,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_system_message': isSystemMessage,
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }
  
// In the ChatController class, add a new method:

/// End the chat with a specific reason
Future<void> endChat({String reason = 'ended'}) async {
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
    
    final updateData = <String, dynamic>{
      'status': 'ended',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'ended_by': currentUserId,
      'end_reason': reason,
      // Reset meeting state when chat is ended
      'user1_meeting_requested': false,
      'user2_meeting_requested': false,
      'meeting_confirmed': false,
    };
    
    // If reason is 'declined', add a declined_at timestamp
    if (reason == 'declined') {
      updateData['declined_at'] = DateTime.now().toUtc().toIso8601String();
      updateData['declined_by'] = currentUserId;
    }
    
    if (existingChat != null) {
      // Update existing chat session
      await supabase
          .from('chat_sessions')
          .update(updateData)
          .eq('id', chatId);
    } else {
      // Create new chat session
      final initialData = <String, dynamic>{
        'id': chatId,
        'user1_id': smallerId,
        'user2_id': largerId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      
      // Add end chat data
      initialData.addAll(updateData);
      
      await supabase
          .from('chat_sessions')
          .insert(initialData);
    }
    
    // Add system message about chat ending with appropriate message
    String systemMessage;
    if (reason == 'declined') {
      systemMessage = 'Chat has been declined. You cannot start a new chat with this user for 24 hours.';
    } else {
      systemMessage = 'Chat has been ended.';
    }
    await _sendSystemMessage(systemMessage);
    
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

/// Check if a chat with this user is allowed (not declined within 24 hours)
static Future<bool> canStartChatWith(String userId1, String userId2) async {
  try {
    // Create unique key for this chat session
    final smallerId = userId1.compareTo(userId2) < 0 ? userId1 : userId2;
    final largerId = userId1.compareTo(userId2) < 0 ? userId2 : userId1;
    final chatId = '${smallerId}_$largerId';
    
    // Get the chat session
    final response = await Supabase.instance.client
        .from('chat_sessions')
        .select('ended_at, ended_by')
        .eq('id', chatId)
        .maybeSingle();
    
    if (response == null || response['ended_at'] == null) {
      return true; // No decline record, chat is allowed
    }
    
    // Check if 24 hours have passed since the decline
    final declinedAt = DateTime.parse(response['ended_at']);
    final now = DateTime.now().toUtc();
    final difference = now.difference(declinedAt);
    
    return difference.inHours >= 24;
  } catch (e) {
    debugPrint("Error checking if chat is allowed: $e");
    return true; // Allow chat on error to prevent blocking legitimate chats
  }
}
}