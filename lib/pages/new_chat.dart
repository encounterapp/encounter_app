import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/utils/age_verification_utils.dart';

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final VoidCallback? onChatEnded;

  const ChatScreen({super.key, required this.recipientId, this.onChatEnded});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final supabase = Supabase.instance.client;
  Stream<List<Map<String, dynamic>>>? _messagesStream;
  RealtimeChannel? _chatStatusChannel;
  String? currentUserId;
  String? _recipientProfilePic;
  String? _recipientUsername;
  final List<Map<String, dynamic>> _messages = [];
  bool _isChatEnded = false;
  bool _isInitialized = false;
  
  // Age verification state
  bool _ageVerified = false;
  bool _ageGapWarningNeeded = false;
  bool _isCurrentUserMinor = false;
  bool _isRecipientMinor = false;
  Map<String, dynamic>? _ageData;

  @override
  void initState() {
    super.initState();
    _isChatEnded = false;
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in!')),
          );
        }
      });
      return;
    }

    currentUserId = currentUser.id;
    
    // Fetch critical data in sequence to ensure proper initialization
    await _checkIfChatIsEnded();
    await _fetchUserProfile();
    
    // Check age verification status
    await _checkAgeVerification();
    
    _setupMessagesStream();
    _setupChatStatusListener();
    
    // Mark as initialized
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
    
    // Show age verification warning if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAgeVerificationIfNeeded();
    });
  }
  
  // Check age verification
  Future<void> _checkAgeVerification() async {
    if (currentUserId == null) return;
    
    // Check if age verification has been acknowledged
    final hasAcknowledged = await AgeVerificationUtils.hasAcknowledgedAgeVerification(
      currentUserId!,
      widget.recipientId,
    );
    
    // Get age data
    final ageData = await AgeVerificationUtils.checkAgeGap(
      currentUserId!,
      widget.recipientId,
    );
    
    if (mounted) {
      setState(() {
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
      });
    }
  }
  
  // Show age verification warning if needed
  Future<void> _showAgeVerificationIfNeeded() async {
    if (!mounted || _ageVerified || !_ageGapWarningNeeded || _ageData == null || currentUserId == null) return;
    
    final result = await AgeVerificationUtils.showAgeVerificationWarning(
      context,
      _ageData!,
      currentUserId!,
    );
    
    if (result) {
      // Save acknowledgment
      await AgeVerificationUtils.saveAgeVerificationAcknowledgment(
        currentUserId!,
        widget.recipientId,
      );
      
      if (mounted) {
        setState(() {
          _ageVerified = true;
        });
      }
    } else {
      // User canceled, go back
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesStream?.listen(null).cancel();
    _chatStatusChannel?.unsubscribe();
    super.dispose();
  }

  // Improved method to check if chat has already been ended
  Future<void> _checkIfChatIsEnded() async {
    try {
      // Create a precise query with complex conditions to find the specific chat session
      final response = await supabase
          .from('chat_sessions')
          .select('status')
          .or('and(user1_id.eq.$currentUserId,user2_id.eq.${widget.recipientId}),and(user1_id.eq.${widget.recipientId},user2_id.eq.$currentUserId)')
          .limit(1)
          .maybeSingle();

      if (response != null && response['status'] == 'ended') {
        if (mounted) {
          setState(() {
            _isChatEnded = true;
          });
        }
      }
    } catch (e) {
      // Log the error but don't disrupt the flow
      debugPrint("Error checking if chat is ended: $e");
      // Default to not ended if we can't verify
    }
  }

  //Confirmation message to end chat
  Future<void> _confirmEndChat() async {
    // Don't show dialog if chat is already ended
    if (_isChatEnded) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Conversation'),
        content: const Text(
            'Are you sure you want to end this conversation? '
            'You will not be able to message this user again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('END CHAT'),
          ),
        ],
      ),
    );

    if (result == true) {
      _endChat();
    }
  }

  // New method to listen for real-time chat status changes
 void _setupChatStatusListener() {
  // Create a unique channel name for this chat
  final String channelName = 'chat_status_${currentUserId}_${widget.recipientId}';
  
  // Subscribe to the chat_sessions table for changes
  _chatStatusChannel = supabase
      .channel(channelName)
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'chat_sessions',
        callback: (payload) {
          // Check if this update relates to our chat
          final Map<String, dynamic> newRecord = payload.newRecord;
          final String user1Id = newRecord['user1_id'];
          final String user2Id = newRecord['user2_id'];
          
          // Verify this update is for our chat session
          if ((user1Id == currentUserId && user2Id == widget.recipientId) ||
              (user1Id == widget.recipientId && user2Id == currentUserId)) {
            
            if (newRecord['status'] == 'ended' && mounted) {
              setState(() {
                _isChatEnded = true;
              });
              
              // Notify the user that the chat has been ended
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('This chat has been ended by the other user')),
              );
            }
          }
        },
      )
      .subscribe();
}

  Future<void> _fetchUserProfile() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('username, avatar_url, age')
          .eq('id', widget.recipientId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _recipientUsername = response['username'] ?? "Unknown User";
          _recipientProfilePic = response['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  void _setupMessagesStream() {
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((messages) {
      final filteredMessages = messages.where((msg) {
        final senderId = msg['sender_id'];
        final receiverId = msg['receiver_id'];
        return (senderId == currentUserId && receiverId == widget.recipientId) ||
            (senderId == widget.recipientId && receiverId == currentUserId);
      }).toList();

      // Store the filtered messages regardless of chat state
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(filteredMessages);
        });

        // Scroll to bottom when new messages come in
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }

      return filteredMessages;
    });
  }

  // Enhanced send message with additional safety checks
  void _sendMessage() async {
    final text = _messageController.text.trim();
    
    // Exit early if chat isn't fully initialized yet
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat is still initializing. Please try again.')),
      );
      return;
    }
    
    // Verify chat status again before sending message
    await _checkIfChatIsEnded();
    
    // Triple-check all conditions before sending
    if (text.isEmpty || currentUserId == null || _isChatEnded) {
      if (_isChatEnded) {
        // Let the user know they can't send messages
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This chat has ended. You cannot send messages.')),
        );
      }
      return;
    }

    final newMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': currentUserId,
      'receiver_id': widget.recipientId,
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    _messageController.clear();
    setState(() {
      _messages.add(newMessage);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      await supabase.from('messages').insert({
        'sender_id': newMessage['sender_id'],
        'receiver_id': newMessage['receiver_id'],
        'content': newMessage['content'],
        'created_at': newMessage['created_at'],
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: ${e.toString()}')),
        );
      }
    }
  }

  // Improved end chat with better database handling
Future<void> _endChat() async {
  // Update local state first
  setState(() {
    _isChatEnded = true;
  });
  
  // Show processing indicator
  if (mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  try {
    // Create a unique key for this chat session
    final smallerId = currentUserId!.compareTo(widget.recipientId) < 0 
        ? currentUserId 
        : widget.recipientId;
    final largerId = currentUserId!.compareTo(widget.recipientId) < 0 
        ? widget.recipientId 
        : currentUserId;
        
    final chatId = '${smallerId}_$largerId';
    
    // First check if the chat session exists
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
    
    // 2. Add a system message about chat ending
    await supabase.from('messages').insert({
      'sender_id': currentUserId,
      'receiver_id': widget.recipientId,
      'content': 'Chat has been ended.',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'is_system_message': true,
    });
    
    // Close the loading dialog
    if (mounted) Navigator.of(context).pop();
    
    // Show confirmation to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat has been ended successfully')),
      );
    }
    
    // Call the callback if provided
    if (widget.onChatEnded != null) {
      widget.onChatEnded!();
    }
    
  } catch (e) {
    // Close the loading dialog
    if (mounted) Navigator.of(context).pop();
    
    debugPrint("Error ending chat: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end chat: ${e.toString()}')),
      );
    }
    
    // Rollback local state if db operation failed
    setState(() {
      _isChatEnded = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator until initialization is complete
    if (!_isInitialized && currentUserId != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text("Loading Chat..."),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Always rebuild the entire UI based on current _isChatEnded state
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: _recipientProfilePic != null
                  ? NetworkImage(_recipientProfilePic!)
                  : const AssetImage('assets/icons/flutter_logo.png') as ImageProvider,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _recipientUsername ?? "Loading...",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isChatEnded ? Colors.red : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isChatEnded ? "Chat Ended" : "Online", 
                      style: TextStyle(
                        color: _isChatEnded ? Colors.red : Colors.green, 
                        fontSize: 12
                      )
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (!_isChatEnded) // Show settings only if chat is active
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.orange),
              onPressed: () {},
            ),
        ],
      ),
      body: SafeArea(
        child: _buildChatBody(),
      ),
    );
  }

  // Separate method to build the chat body based on chat status
  Widget _buildChatBody() {
    if (_isChatEnded) {
      // Chat ended layout - simpler layout with no input
      return Column(
        children: [
          _buildChatEndedBanner(), // Always show the banner at the top
          Expanded(child: _buildMessagesList()),
          _buildChatEndedFooter(), // Add a footer emphasizing chat has ended
        ],
      );
    } else {
      // Active chat layout
      return Column(
        children: [
          const SizedBox(height: 10),
          // Add age warning banner if needed
          //if (_ageGapWarningNeeded)
          // _buildAgeWarningBanner(),
          _buildActionButtonsAndGuidelines(disabled: false),
          const SizedBox(height: 10),
          Expanded(child: _buildMessagesList()),
          _buildMessageInput() // Only included in active chat
        ],
      );
    }
  }

  Widget _buildAgeWarningBanner() {
    Color bannerColor = Colors.orange[100]!;
    Color textColor = Colors.orange[900]!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: bannerColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCurrentUserMinor 
                    ? "You are under 18 chatting with someone 18 or older." 
                    : "This user is under 18.",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isCurrentUserMinor
                    ? "Be careful about sharing personal information and consider involving a trusted adult."
                    : "Be respectful and mindful of appropriate conversation topics.",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatEndedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.red[100],
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Chat Ended",
                  style: TextStyle(
                    color: Colors.red[700], 
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "This conversation has been ended and you can no longer send messages.",
                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatEndedFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          "Return to Home",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // Implementation of _buildActionButtonsAndGuidelines
  Widget _buildActionButtonsAndGuidelines({required bool disabled}) {
    // Additional safety guidelines if age gap exists
    final List<String> safetyGuidelines = [
      '• Meet in public places only',
      '• Tell a friend or family member about your plans',
      '• No solicitation of any kind',
      '• No harassment or inappropriate content',
      '• Report violations immediately',
    ];
    
    // Add age-specific guidelines
    if (_ageGapWarningNeeded) {
      if (_isCurrentUserMinor) {
        safetyGuidelines.add('• Consider involving a trusted adult in communications');
        safetyGuidelines.add('• Never share personal information or photos');
      } else {
        safetyGuidelines.add('• Communication must be appropriate for minors');
        safetyGuidelines.add('• Inappropriate communications with minors may violate laws');
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        children: [
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: disabled ? null : () {},
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Meet"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    // Apply disabled styling
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: disabled ? null : _confirmEndChat,
                  icon: const Icon(Icons.close),
                  label: const Text("Decline"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    // Apply disabled styling
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),

          // Guidelines collapsed section
          ExpansionTile(
            title: const Text(
              "Safety Guidelines",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            childrenPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            initiallyExpanded: false,
            iconColor: Colors.orange,
            children: [
              // Display all safety guidelines including age-specific ones
              ...safetyGuidelines.map((guideline) => _guidelineText(guideline)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guidelineText(String text) {
    // Highlight age-related guidelines with a different color
    final bool isAgeGuideline = text.contains('minor') || 
                               text.contains('adult') || 
                               text.contains('trusted');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14, 
          color: isAgeGuideline ? Colors.orange[800] : Colors.grey[600],
          fontWeight: isAgeGuideline ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // Implementation of _buildMessagesList
  Widget _buildMessagesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (_messages.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Show empty state message if there are no messages
        if (_messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No messages yet",
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  _isChatEnded 
                      ? "This chat ended without any messages" 
                      : "Start a conversation!",
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                // Add age warning in empty state if needed
                if (_ageGapWarningNeeded && !_isChatEnded)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _isCurrentUserMinor 
                              ? "Remember: You are chatting with an adult" 
                              : "Remember: You are chatting with a minor",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isCurrentUserMinor
                              ? "Be careful about what you share and involve a trusted adult if needed." 
                              : "Keep conversations appropriate and respectful.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        final displayMessages = List<Map<String, dynamic>>.from(_messages);
        
        // Insert age verification message at the beginning if needed
        if (_ageGapWarningNeeded && displayMessages.isNotEmpty) {
          // Check if we already have an age verification message
          bool hasAgeMessage = displayMessages.any((msg) => 
            msg['is_system_message'] == true && 
            (msg['content'].toString().contains('under 18') || 
             msg['content'].toString().contains('minor'))
          );
          
          if (!hasAgeMessage) {
            final String ageMessage = _isCurrentUserMinor 
              ? "Age Verification Notice: You are under 18 chatting with someone 18 or older. Please be careful about sharing personal information."
              : "Age Verification Notice: This user is under 18. Please ensure all communication is appropriate and respectful.";
              
            // Add the system message to the beginning
            displayMessages.insert(0, {
              'id': 'age_verification',
              'sender_id': 'system',
              'receiver_id': 'system',
              'content': ageMessage,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'is_system_message': true,
            });
          }
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          itemCount: displayMessages.length,
          itemBuilder: (context, index) {
            final msg = displayMessages[index];
            final isMine = msg['sender_id'] == currentUserId;
            final isSystemMessage = msg['is_system_message'] == true;
            
            if (isSystemMessage) {
              return _buildSystemMessage(msg['content']);
            }
            
            return _buildChatBubble(msg['content'], isMine);
          },
        );
      },
    );
  }

  Widget _buildSystemMessage(String text) {
    // Add special styling for age verification system messages
    final bool isAgeMessage = text.contains('under 18') || 
                             text.contains('minor') || 
                             text.contains('age verification');
                             
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isAgeMessage ? Colors.orange[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: isAgeMessage ? Border.all(color: Colors.orange) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAgeMessage)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(Icons.warning_amber, size: 16, color: Colors.orange[800]),
              ),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: isAgeMessage ? Colors.orange[800] : Colors.grey[800], 
                  fontSize: 14, 
                  fontStyle: FontStyle.italic,
                  fontWeight: isAgeMessage ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isMine) {
    // Check if this message might contain age-related content to highlight
    final bool containsAgeWarning = text.toLowerCase().contains('under 18') ||
                                  text.toLowerCase().contains('minor') ||
                                  text.toLowerCase().contains('adult');
                                  
    // Determine bubble color based on whether it's the user's message and if it contains warnings
    Color bubbleColor;
    if (isMine) {
      bubbleColor = containsAgeWarning ? Colors.orange : Colors.blue;
    } else {
      bubbleColor = containsAgeWarning ? Colors.orange[100]! : Colors.grey[300]!;
    }
    
    // Text color based on bubble color
    Color textColor = isMine ? Colors.white : Colors.black;
    
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMine ? 12 : 0),
            topRight: Radius.circular(isMine ? 0 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
          // Add border for age-related messages
          border: containsAgeWarning 
              ? Border.all(color: Colors.orange[700]!, width: 1.0) 
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16, 
            color: textColor,
            // Make age-related text bold
            fontWeight: containsAgeWarning ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Implementation of _buildMessageInput
  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Your message",
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}