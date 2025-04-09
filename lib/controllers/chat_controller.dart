import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:encounter_app/utils/age_verification_utils.dart';

/// ChatState represents the current state of a chat session
class ChatState {
  final bool isInitialized;
  final bool isChatEnded;
  final String? recipientUsername;
  final String? recipientProfilePic;
  final List<Map<String, dynamic>> messages;
  final bool ageVerified;
  final bool ageGapWarningNeeded;
  final bool isCurrentUserMinor;
  final bool isRecipientMinor;
  final Map<String, dynamic>? ageData;
  final bool currentUserRequestedMeeting;
  final bool recipientRequestedMeeting;
  final bool meetingConfirmed;
  final String? postStatus;

  const ChatState({
    this.isInitialized = false,
    this.isChatEnded = false,
    this.recipientUsername,
    this.recipientProfilePic,
    this.messages = const [],
    this.ageVerified = false,
    this.ageGapWarningNeeded = false,
    this.isCurrentUserMinor = false,
    this.isRecipientMinor = false,
    this.ageData,
    this.currentUserRequestedMeeting = false,
    this.recipientRequestedMeeting = false,
    this.meetingConfirmed = false,
    this.postStatus,
  });

  /// Creates a copy of the current state with the specified fields replaced
  ChatState copyWith({
    bool? isInitialized,
    bool? isChatEnded,
    String? recipientUsername,
    String? recipientProfilePic,
    List<Map<String, dynamic>>? messages,
    bool? ageVerified,
    bool? ageGapWarningNeeded,
    bool? isCurrentUserMinor,
    bool? isRecipientMinor,
    Map<String, dynamic>? ageData,
    bool? currentUserRequestedMeeting,
    bool? recipientRequestedMeeting,
    bool? meetingConfirmed,
    String? postStatus,
  }) {
    return ChatState(
      isInitialized: isInitialized ?? this.isInitialized,
      isChatEnded: isChatEnded ?? this.isChatEnded,
      recipientUsername: recipientUsername ?? this.recipientUsername,
      recipientProfilePic: recipientProfilePic ?? this.recipientProfilePic,
      messages: messages ?? this.messages,
      ageVerified: ageVerified ?? this.ageVerified,
      ageGapWarningNeeded: ageGapWarningNeeded ?? this.ageGapWarningNeeded,
      isCurrentUserMinor: isCurrentUserMinor ?? this.isCurrentUserMinor,
      isRecipientMinor: isRecipientMinor ?? this.isRecipientMinor,
      ageData: ageData ?? this.ageData,
      currentUserRequestedMeeting: currentUserRequestedMeeting ?? this.currentUserRequestedMeeting,
      recipientRequestedMeeting: recipientRequestedMeeting ?? this.recipientRequestedMeeting,
      meetingConfirmed: meetingConfirmed ?? this.meetingConfirmed,
      postStatus: postStatus ?? this.postStatus,
    );
  }
}

/// Manages the chat functionality including messages, meeting requests, and chat status
class ChatController with ChangeNotifier {
  // Dependencies
  final String recipientId;
  final String? chatSessionId;
  final VoidCallback? onChatEnded;
  final SupabaseClient supabase;
  final String? postId;
  
  // State management
  ChatState _state = const ChatState();
  
  // Current user ID
  String? _currentUserId;
  
  // Stream controllers and channels
  Stream<List<Map<String, dynamic>>>? _messagesStream;
  RealtimeChannel? _chatStatusChannel;
  RealtimeChannel? _postStatusChannel;
  
  // Getters
  Stream<List<Map<String, dynamic>>>? get messagesStream => _messagesStream;
  List<Map<String, dynamic>> get messages => _state.messages;
  bool get isChatEnded => _state.isChatEnded;
  bool get isInitialized => _state.isInitialized;
  bool get ageVerified => _state.ageVerified;
  bool get ageGapWarningNeeded => _state.ageGapWarningNeeded;
  bool get isCurrentUserMinor => _state.isCurrentUserMinor;
  bool get isRecipientMinor => _state.isRecipientMinor;
  Map<String, dynamic>? get ageData => _state.ageData;
  String? get currentUserId => _currentUserId;
  String? get recipientUsername => _state.recipientUsername;
  String? get recipientProfilePic => _state.recipientProfilePic;
  String? get postStatus => _state.postStatus;
  
  // Meeting state getters
  bool get currentUserRequestedMeeting => _state.currentUserRequestedMeeting;
  bool get recipientRequestedMeeting => _state.recipientRequestedMeeting;
  bool get meetingConfirmed => _state.meetingConfirmed;
  bool get canRequestMeeting => !_state.isChatEnded && !_state.currentUserRequestedMeeting;

  // Setter for post status with notification
  set postStatus(String? value) {
    if (_state.postStatus != value) {
      _state = _state.copyWith(postStatus: value);
      notifyListeners();
    }
  }
  
  // Constructor
  ChatController({
    required this.recipientId,
    required this.supabase,
    this.onChatEnded,
    this.postId, 
    this.chatSessionId,
  }) {
    _init();
  }
  
  // Initialize the controller
  Future<void> _init() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;
    
    _currentUserId = currentUser.id;
    
    // Initialize all components in parallel for faster loading
    await Future.wait([
      _checkAgeVerification(),
      _checkIfChatIsEnded(),
      _fetchUserProfile(),
      _checkMeetingStatus(),
      if (postId != null) _fetchPostStatus(),
    ]);
    
    // Setup listeners after initialization
    _setupMessagesStream();
    _setupChatStatusListener();
    _setupMeetingStatusListener();
    if (postId != null) _setupPostStatusListener();
    
    // Update state to initialized
    _state = _state.copyWith(isInitialized: true);
    notifyListeners();
  }

  // Setup post status listener
  void _setupPostStatusListener() {
    if (postId == null) return;
    
    final String channelName = 'post_status_${postId}';
    
    _postStatusChannel = supabase
      .channel(channelName)
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'posts',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: postId,
        ),
        callback: (payload) {
          final Map<String, dynamic> newRecord = payload.newRecord;
          final String? newStatus = newRecord['status'];
          
          debugPrint("Post status changed: $newStatus");
          
          if (newStatus != _state.postStatus) {
            // If post becomes closed/archived, end this chat automatically
            if (_state.postStatus != 'closed' && newStatus == 'closed' && !_state.isChatEnded) {
              _state = _state.copyWith(isChatEnded: true, postStatus: newStatus);
              _sendSystemMessage("This conversation has been ended because the post was archived.");
            } else {
              _state = _state.copyWith(postStatus: newStatus);
            }
            
            notifyListeners();
          }
        },
      )
      .subscribe();
  }

  // Fetch post status
  Future<void> _fetchPostStatus() async {
    if (postId == null) return;
    
    debugPrint("Fetching post status for post ID: $postId");
    
    try {
      final String nonNullPostId = postId!;
      final response = await supabase
          .from('posts')
          .select('status')
          .eq('id', nonNullPostId)
          .single();
          
      if (response != null) {
        final newStatus = response['status'];
        debugPrint("Fetched post status: $newStatus");
        
        if (_state.postStatus != newStatus) {
          _state = _state.copyWith(postStatus: newStatus);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error fetching post status: $e");
    }
  }

  /// Manually refresh the post status from the database
  Future<void> refreshPostStatus() async {
    await _fetchPostStatus();
  }

  // Check age verification status
  Future<void> _checkAgeVerification() async {
    if (_currentUserId == null) return;
    
    try {
      // Check if age verification has been acknowledged
      final hasAcknowledged = await AgeVerificationUtils.hasAcknowledgedAgeVerification(
        _currentUserId!,
        recipientId,
      );
      
      // Get age data
      final ageData = await AgeVerificationUtils.checkAgeGap(
        _currentUserId!,
        recipientId,
      );
      
      // Determine if current user or recipient is minor
      final currentUserData = ageData['user1']['id'] == _currentUserId 
          ? ageData['user1'] 
          : ageData['user2'];
      final recipientData = ageData['user1']['id'] == _currentUserId 
          ? ageData['user2'] 
          : ageData['user1'];
          
      _state = _state.copyWith(
        ageVerified: hasAcknowledged,
        ageGapWarningNeeded: ageData['ageGapWarningNeeded'],
        ageData: ageData,
        isCurrentUserMinor: currentUserData['isMinor'],
        isRecipientMinor: recipientData['isMinor'],
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint("Error checking age verification: $e");
    }
  }
  
  // Check meeting status
  Future<void> _checkMeetingStatus() async {
    if (_currentUserId == null) return;
    
    try {
      // Create unique key for this chat session
      final String chatId = _generateChatId();
      
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
        final parts = chatId.split('_');
        if (parts.length >= 2) {
          final smallerId = parts[0];
          final isUser1 = _currentUserId == smallerId;
          
          _state = _state.copyWith(
            currentUserRequestedMeeting: isUser1 ? user1Requested : user2Requested,
            recipientRequestedMeeting: isUser1 ? user2Requested : user1Requested,
            meetingConfirmed: meetingConfirmed,
          );
          
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error checking meeting status: $e");
    }
  }
  
  // Mark age verification as acknowledged
  Future<void> acknowledgeAgeVerification() async {
    if (_currentUserId == null) return;
    
    await AgeVerificationUtils.saveAgeVerificationAcknowledgment(
      _currentUserId!,
      recipientId,
    );
    
    _state = _state.copyWith(ageVerified: true);
    notifyListeners();
  }
  
  // Check if chat has been ended
  Future<void> _checkIfChatIsEnded() async {
    if (_currentUserId == null) return;
    
    try {
      final response = await supabase
          .from('chat_sessions')
          .select('status')
          .or('and(user1_id.eq.$_currentUserId,user2_id.eq.$recipientId),and(user1_id.eq.$recipientId,user2_id.eq.$_currentUserId)')
          .limit(1)
          .maybeSingle();

      if (response != null && response['status'] == 'ended') {
        _state = _state.copyWith(isChatEnded: true);
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
        _state = _state.copyWith(
          recipientUsername: response['username'] ?? "Unknown User",
          recipientProfilePic: response['avatar_url'],
        );
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }
  
  // Generate a unique chat ID
  String _generateChatId() {
    if (_currentUserId == null) return '';
    
    final smallerId = _currentUserId!.compareTo(recipientId) < 0 
        ? _currentUserId 
        : recipientId;
    final largerId = _currentUserId!.compareTo(recipientId) < 0 
        ? recipientId 
        : _currentUserId;
        
    // If postId is provided, include it in the chat ID
    if (postId != null) {
      return '${smallerId}_${largerId}';
    }
    
    return '${smallerId}_${largerId}';
  }
  
  // Set up messages stream
  void _setupMessagesStream() {
    if (_currentUserId == null) return;
    
    // If we have a chat session ID directly, use it
    if (chatSessionId != null) {
      final String sessionId = chatSessionId!;
      
      debugPrint("Using provided chat session ID: $sessionId");
      _messagesStream = supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('chat_session_id', sessionId)
          .order('created_at', ascending: true)
          .map((messages) {
        _state = _state.copyWith(messages: messages);
        notifyListeners();
        return messages;
      });
      return;
    }
    
    // Otherwise, generate a chat ID
    final String chatId = _generateChatId();
    debugPrint("Looking for chat session with ID: $chatId");
    
    // Get the chat session to determine which messages to fetch
    supabase
        .from('chat_sessions')
        .select('id')
        .eq('id', chatId)
        .maybeSingle()
        .then((chatSession) {
          if (chatSession != null) {
            debugPrint("Found chat session: ${chatSession['id']}");
            // Set up the messages stream for this specific chat session
            _messagesStream = supabase
                .from('messages')
                .stream(primaryKey: ['id'])
                .eq('chat_session_id', chatSession['id'])
                .order('created_at', ascending: true)
                .map((messages) {
              _state = _state.copyWith(messages: messages);
              notifyListeners();
              return messages;
            });
          } else {
            // No chat session found, create a new stream for direct messages
            debugPrint("No chat session found, using direct messages");
            _messagesStream = supabase
                .from('messages')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: true)
                .map((messages) {
              final filteredMessages = messages.where((msg) {
                final senderId = msg['sender_id'];
                final receiverId = msg['receiver_id'];
                return (senderId == _currentUserId && receiverId == recipientId) ||
                    (senderId == recipientId && receiverId == _currentUserId);
              }).toList();

              _state = _state.copyWith(messages: filteredMessages);
              notifyListeners();

              return filteredMessages;
            });
          }
        })
        .catchError((error) {
          debugPrint("Error fetching chat session: $error");
          // Fallback to showing all messages between these users
          _messagesStream = supabase
              .from('messages')
              .stream(primaryKey: ['id'])
              .order('created_at', ascending: true)
              .map((messages) {
            final filteredMessages = messages.where((msg) {
              final senderId = msg['sender_id'];
              final receiverId = msg['receiver_id'];
              return (senderId == _currentUserId && receiverId == recipientId) ||
                  (senderId == recipientId && receiverId == _currentUserId);
            }).toList();

            _state = _state.copyWith(messages: filteredMessages);
            notifyListeners();

            return filteredMessages;
          });
        });
  }
  
  // Set up chat status listener
  void _setupChatStatusListener() {
    if (_currentUserId == null) return;
    
    final String channelName = 'chat_status_${_currentUserId}_$recipientId';
    
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
            
            if ((user1Id == _currentUserId && user2Id == recipientId) ||
                (user1Id == recipientId && user2Id == _currentUserId)) {
              
              if (newRecord['status'] == 'ended') {
                _state = _state.copyWith(isChatEnded: true);
                notifyListeners();
              }
            }
          },
        )
        .subscribe();
  }
  
  // Set up meeting status listener
  void _setupMeetingStatusListener() {
    if (_currentUserId == null) return;
    
    final String channelName = 'meeting_status_${_currentUserId}_$recipientId';
    
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
            
            if ((user1Id == _currentUserId && user2Id == recipientId) ||
                (user1Id == recipientId && user2Id == _currentUserId)) {
              
              // Create unique key for this chat session to determine user order
              final smallerId = _currentUserId!.compareTo(recipientId) < 0 
                  ? _currentUserId 
                  : recipientId;
                  
              // Determine if current user is user1 or user2
              final isUser1 = _currentUserId == smallerId;
              
              // Update meeting state
              final user1Requested = newRecord['user1_meeting_requested'] ?? false;
              final user2Requested = newRecord['user2_meeting_requested'] ?? false;
              final meetingConfirmed = newRecord['meeting_confirmed'] ?? false;
              
              _state = _state.copyWith(
                currentUserRequestedMeeting: isUser1 ? user1Requested : user2Requested,
                recipientRequestedMeeting: isUser1 ? user2Requested : user1Requested,
                meetingConfirmed: meetingConfirmed,
              );
              
              // If meeting was just confirmed, send a system message
              if (meetingConfirmed && !_state.isChatEnded) {
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
    if (!_state.isInitialized || _currentUserId == null || _state.isChatEnded || text.trim().isEmpty) {
      return;
    }
    
    await _checkIfChatIsEnded();
    if (_state.isChatEnded) return;
    
    // Get the chat ID
    final String chatId = _generateChatId();
    
    // Create temporary message for UI update
    final newMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': _currentUserId,
      'receiver_id': recipientId,
      'chat_session_id': chatId,
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Update UI optimistically
    final updatedMessages = List<Map<String, dynamic>>.from(_state.messages);
    updatedMessages.add(newMessage);
    _state = _state.copyWith(messages: updatedMessages);
    notifyListeners();

    try {
      // Send message to backend
      await supabase.from('messages').insert({
        'sender_id': newMessage['sender_id'],
        'receiver_id': newMessage['receiver_id'],
        'chat_session_id': chatId,
        'content': newMessage['content'],
        'created_at': newMessage['created_at'],
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
      // Revert optimistic update on error
      updatedMessages.removeLast();
      _state = _state.copyWith(messages: updatedMessages);
      notifyListeners();
      throw Exception('Failed to send message: $e');
    }
  }
  
  // Send a system message
  Future<void> _sendSystemMessage(String text) async {
    if (_currentUserId == null || _state.isChatEnded) return;
    
    try {
      await supabase.from('messages').insert({
        'sender_id': _currentUserId,
        'receiver_id': recipientId,
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
    if (_state.isChatEnded || _currentUserId == null || _state.currentUserRequestedMeeting) return;
    
    try {
      // Get chat ID
      final String chatId = _generateChatId();
      
      // Determine if current user is user1 or user2
      final parts = chatId.split('_');
      if (parts.length < 2) return;
      
      final smallerId = parts[0];
      final isUser1 = _currentUserId == smallerId;
      
      // Check if chat session exists
      final existingChat = await supabase
          .from('chat_sessions')
          .select('*, post_id')
          .eq('id', chatId)
          .maybeSingle();
      
      final updateData = <String, dynamic>{};
      
      // Update meeting request field based on user position
      if (isUser1) {
        updateData['user1_meeting_requested'] = true;
      } else {
        updateData['user2_meeting_requested'] = true;
      }
      
      // Check if this is a confirmation (both users have requested meeting)
      bool isMeetingConfirmed = false;
      if ((isUser1 && (existingChat?['user2_meeting_requested'] ?? false)) ||
          (!isUser1 && (existingChat?['user1_meeting_requested'] ?? false))) {
        updateData['meeting_confirmed'] = true;
        updateData['meeting_confirmed_at'] = DateTime.now().toIso8601String();
        isMeetingConfirmed = true;
      }
      
      // Add a timestamp for the meeting request
      updateData['meeting_requested_at'] = DateTime.now().toIso8601String();
      
      // Link post ID if provided and not already linked
      if (postId != null && (existingChat == null || existingChat['post_id'] == null)) {
        updateData['post_id'] = postId!;
      }
      
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
          'user2_id': parts[1],
          'status': 'active',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        
        // Add post ID if available
        if (postId != null) {
          initialData['post_id'] = postId!;
        }
        
        // Add meeting request details
        initialData.addAll(updateData);
        
        await supabase
            .from('chat_sessions')
            .insert(initialData);
      }
      
      // If meeting is confirmed and we have a postId, update the post status
      if (isMeetingConfirmed && postId != null) {
        try {
          debugPrint("Updating post status to closed for post ID: $postId");
          
          await supabase
              .from('posts')
              .update({
                'status': 'closed',
                'closed_at': DateTime.now().toUtc().toIso8601String(),
                'closed_by': chatId,
              })
              .eq('id', postId!);
          
          // Update local post status
          _state = _state.copyWith(postStatus: 'closed');
          
          // Send system message about post being closed
          await _sendSystemMessage("This post has been marked as closed since both users have agreed to meet.");
          
          // Refresh post status
          await refreshPostStatus();
        } catch (postUpdateError) {
          debugPrint("Error updating post status: $postUpdateError");
        }
      }
      
      // Update local state optimistically
      _state = _state.copyWith(
        currentUserRequestedMeeting: true,
        meetingConfirmed: isMeetingConfirmed,
      );
      notifyListeners();
      
      // Send appropriate system messages
      if (isMeetingConfirmed) {
        await _sendSystemMessage("You both have accepted to meet.");
      } else {
        await _sendSystemMessage("${_state.recipientUsername ?? 'Other user'} will be notified of your interest to meet.");
        await _sendMessage("has accepted to meet", isSystemMessage: true);
      }
    } catch (e) {
      debugPrint("Error requesting meeting: $e");
      // Revert optimistic update on error
      _state = _state.copyWith(
        currentUserRequestedMeeting: false,
        meetingConfirmed: false,
      );
      notifyListeners();
      throw Exception('Failed to request meeting: $e');
    }
  }
  
  // Send a message with proper sender/receiver
  Future<void> _sendMessage(String content, {bool isSystemMessage = false}) async {
    if (_currentUserId == null) return;
    
    try {
      await supabase.from('messages').insert({
        'sender_id': _currentUserId,
        'receiver_id': recipientId,
        'content': content,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_system_message': isSystemMessage,
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }
  
  /// End the chat with a specific reason
  Future<void> endChat({String reason = 'ended'}) async {
    if (_state.isChatEnded || _currentUserId == null) return;
    
    // Update UI state optimistically
    _state = _state.copyWith(isChatEnded: true);
    notifyListeners();
    
    try {
      final String chatId = _generateChatId();
      
      // Check if chat session exists
      final existingChat = await supabase
          .from('chat_sessions')
          .select()
          .eq('id', chatId)
          .maybeSingle();
      
      final updateData = <String, dynamic>{
        'status': 'ended',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'ended_by': _currentUserId,
        'end_reason': reason,
        // Reset meeting state when chat is ended
        'user1_meeting_requested': false,
        'user2_meeting_requested': false,
        'meeting_confirmed': false,
      };
      
      // If reason is 'declined', add a declined_at timestamp
      if (reason == 'declined') {
        updateData['declined_at'] = DateTime.now().toUtc().toIso8601String();
        updateData['declined_by'] = _currentUserId;
      }
      
      if (existingChat != null) {
        // Update existing chat session
        await supabase
            .from('chat_sessions')
            .update(updateData)
            .eq('id', chatId);
      } else {
        // Create new chat session with ended status
        final parts = chatId.split('_');
        if (parts.length < 2) return;
        
        final initialData = <String, dynamic>{
          'id': chatId,
          'user1_id': parts[0],
          'user2_id': parts[1],
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
      _state = _state.copyWith(isChatEnded: false);
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

  /// Create a chat session linked to a post
  static Future<String?> createChatSessionForPost(String postId, String recipientId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return null;
    
    // First check if post is available
    final isAvailable = await isPostAvailable(postId);
    if (!isAvailable) return null;
    
    try {
      // Create unique chat ID
      final smallerId = currentUser.id.compareTo(recipientId) < 0 
          ? currentUser.id 
          : recipientId;
      final largerId = currentUser.id.compareTo(recipientId) < 0 
          ? recipientId 
          : currentUser.id;
      
      // Generate a unique chat ID that includes the post ID
      final chatId = '${smallerId}_${largerId}';
      
      // Check if this chat session already exists
      final existingChat = await Supabase.instance.client
          .from('chat_sessions')
          .select()
          .eq('id', chatId)
          .maybeSingle();
          
      if (existingChat == null) {
        // Create new chat session
        await Supabase.instance.client
            .from('chat_sessions')
            .insert({
              'id': chatId,
              'user1_id': smallerId,
              'user2_id': largerId,
              'post_id': postId,
              'status': 'active',
              'created_at': DateTime.now().toUtc().toIso8601String(),
            });
            
    } else {
      // Update existing chat with post_id if needed
      if (existingChat['post_id'] == null) {
        await Supabase.instance.client
            .from('chat_sessions')
            .update({'post_id': postId})
            .eq('id', chatId);
      }
    }
      
      return chatId;
    } catch (e) {
      debugPrint("Error creating chat session for post: $e");
      return null;
    }
  }
  
  /// Check if a post is available for chatting
  static Future<bool> isPostAvailable(String postId) async {
    try {
      final response = await Supabase.instance.client
          .from('posts')
          .select('status')
          .eq('id', postId)
          .single();
          
      return response['status'] == 'active';
    } catch (e) {
      debugPrint("Error checking post availability: $e");
      return false;
    }
  }
  
  /// End all chat sessions related to a post
  static Future<void> endAllChatsForPost(String postId) async {
    try {
      // Get all active chat sessions related to this post
      final chatSessions = await Supabase.instance.client
          .from('chat_sessions')
          .select('id')
          .eq('post_id', postId)
          .neq('status', 'ended');
          
      // End each chat session and notify users
      for (final session in chatSessions) {
        final chatId = session['id'];
        
        // Get user IDs from chat ID
        final parts = chatId.split('_');
        if (parts.length >= 2) {
          final user1Id = parts[0];
          final user2Id = parts[1];
          
          // Add system message to inform users
          await Supabase.instance.client.from('messages').insert({
            'sender_id': user1Id,
            'receiver_id': user2Id,
            'content': "This conversation has been ended because the post was archived.",
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'is_system_message': true,
          });
          
          // End the chat session
          await Supabase.instance.client.from('chat_sessions').update({
            'status': 'ended',
            'ended_at': DateTime.now().toUtc().toIso8601String(),
            'ended_by': 'system',
            'end_reason': 'post_archived',
          }).eq('id', chatId);
        }
      }
    } catch (e) {
      debugPrint("Error ending chats for post $postId: $e");
    }
  }
  
  /// Send a system message visible to both users
  Future<void> sendSystemMessage(String text) async {
    await _sendSystemMessage(text);
  }

  @override
  void dispose() {
    _chatStatusChannel?.unsubscribe();
    _postStatusChannel?.unsubscribe();
    super.dispose();
  }
}