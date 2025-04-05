import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/components/meeting_map_view.dart';
import 'package:encounter_app/widgets/chat_bubble.dart';
import 'package:encounter_app/widgets/system_message.dart';
import 'package:encounter_app/widgets/message_input.dart';
import 'package:encounter_app/widgets/message_list.dart';
import 'package:encounter_app/widgets/age_warning_banner.dart';
import 'package:encounter_app/widgets/chat_ended_banner.dart';
import 'package:encounter_app/widgets/chat_ended_footer.dart';
import 'package:encounter_app/widgets/action_buttons_pane.dart';
import 'package:encounter_app/utils/age_verification_utils.dart';
import 'package:encounter_app/controllers/chat_controller.dart';

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final VoidCallback? onChatEnded;

  const ChatScreen({
    Key? key, 
    required this.recipientId, 
    this.onChatEnded
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _showMap = false;
  bool _mapToggledOff = false;
  
  @override
  void initState() {
    super.initState();
    _controller = ChatController(
      recipientId: widget.recipientId,
      supabase: Supabase.instance.client,
      onChatEnded: widget.onChatEnded,
    );
    
    // Listen for controller changes
    _controller.addListener(_controllerUpdated);
    
    // Wait a bit longer before checking age verification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _showAgeVerificationIfNeeded();
        }
      });
    });
  }
  
void _controllerUpdated() {
  if (mounted) {
    setState(() {
      // Only show map when meeting is confirmed AND user hasn't manually toggled it off
      if (_controller.meetingConfirmed && !_mapToggledOff) {
        _showMap = true;
      }
    });
  }
    
    // Scroll to bottom when messages update
    if (_controller.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _controller.removeListener(_controllerUpdated);
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> _showAgeVerificationIfNeeded() async {
    // Don't show dialog if already verified or if not needed
    if (!mounted || _controller.ageVerified || 
        !_controller.ageGapWarningNeeded || 
        _controller.ageData == null || 
        _controller.currentUserId == null) return;
    
    final result = await AgeVerificationUtils.showAgeVerificationWarning(
      context,
      _controller.ageData!,
      _controller.currentUserId!,
    );
    
    if (result) {
      await _controller.acknowledgeAgeVerification();
    } else {
      // User canceled, go back
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
  
  Future<void> _confirmEndChat() async {
    // Don't show dialog if chat is already ended
    if (_controller.isChatEnded) return;

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
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        await _controller.endChat(reason: 'ended');
        
        // Hide loading
        if (mounted) Navigator.of(context).pop();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat has been ended successfully')),
          );
        }
      } catch (e) {
        // Hide loading
        if (mounted) Navigator.of(context).pop();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to end chat: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _handleMeet() async {
    if (_controller.isChatEnded || _controller.currentUserRequestedMeeting) return;
    
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      await _controller.requestMeeting();
      
      // Hide loading
      if (mounted) Navigator.of(context).pop();
      
      // If meeting is now confirmed, show a success message
      if (_controller.meetingConfirmed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting confirmed! You both have accepted to meet.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Show the map
        setState(() {
          _showMap = true;
        });
      } else if (mounted) {
        // Otherwise, show that the request was sent
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meeting request sent to ${_controller.recipientUsername ?? "the other user"}.'),
          ),
        );
      }
    } catch (e) {
      // Hide loading
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request meeting: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _confirmDeclineChat() async {
    // Don't show dialog if chat is already ended
    if (_controller.isChatEnded) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Conversation'),
        content: const Text(
            'Are you sure you want to decline this conversation? '
            'You will not be able to message this user for 24 hours.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DECLINE'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        await _controller.endChat(reason: 'declined');
        
        // Hide loading
        if (mounted) Navigator.of(context).pop();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User has been declined')),
          );
        }
      } catch (e) {
        // Hide loading
        if (mounted) Navigator.of(context).pop();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to decline chat: ${e.toString()}')),
          );
        }
      }
    }
  }

  /// Handles the meeting result (success or failure)
  Future<void> _handleMeetingResult(bool didMeet) async {
  // First ask for confirmation
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(didMeet ? 'Confirm Meeting Success' : 'Confirm Meeting Did Not Happen'),
      content: Text(
          didMeet 
              ? 'Are you confirming that you successfully met with ${_controller.recipientUsername ?? "this user"}?'
              : 'Are you confirming that you did not meet with ${_controller.recipientUsername ?? "this user"}?'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: didMeet ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('CONFIRM'),
        ),
      ],
    ),
  );

  if (result != true) return; // User canceled

  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Update chat session with meeting result
    final userId = _controller.currentUserId;
    if (userId == null) {
      if (mounted) Navigator.of(context).pop(); // Hide loading
      return;
    }

    // Create unique key for this chat session
    final smallerId = userId.compareTo(widget.recipientId) < 0 
        ? userId 
        : widget.recipientId;
    final largerId = userId.compareTo(widget.recipientId) < 0 
        ? widget.recipientId 
        : userId;
    final chatId = '${smallerId}_$largerId';

    // Update the chat session with meeting result
    await Supabase.instance.client.from('chat_sessions').update({
      'meeting_happened': didMeet,
      'meeting_result_reported_at': DateTime.now().toIso8601String(),
      'meeting_result_reported_by': userId,
    }).eq('id', chatId);

    // Add system message about meeting result
    final message = didMeet
        ? "You reported that you successfully met with ${_controller.recipientUsername ?? 'the other user'}."
        : "You reported that you did not meet with ${_controller.recipientUsername ?? 'the other user'}.";
    
    await _controller.sendSystemMessage(message);

    // Hide loading indicator
    if (mounted) Navigator.of(context).pop();

    // Return to chat view
    setState(() {
      _showMap = false;
      _mapToggledOff = true;
    });

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meeting result recorded: ${didMeet ? "Met successfully" : "Did not meet"}'),
          backgroundColor: didMeet ? Colors.green : Colors.orange,
        ),
      );
    }
  } catch (e) {
    // Hide loading indicator
    if (mounted) Navigator.of(context).pop();
    
    // Show error
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording meeting result: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Widget _buildMeetingStatusBanner() {
    if (_controller.meetingConfirmed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "You both have accepted to meet. Map shown below.",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_controller.currentUserRequestedMeeting) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "You have accepted to meet. Waiting for ${_controller.recipientUsername ?? 'other user'} to accept.",
                style: TextStyle(
                  color: Colors.blue[700],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_controller.recipientRequestedMeeting) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "${_controller.recipientUsername ?? 'Other user'} has accepted to meet. Click 'Meet' to confirm.",
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator until initialization is complete
    if (!_controller.isInitialized && _controller.currentUserId != null) {
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
    
    // Always rebuild the entire UI based on current state
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
              backgroundColor: Colors.grey[300],
              backgroundImage: _controller.recipientProfilePic != null
                  ? NetworkImage(_controller.recipientProfilePic!)
                  : null,
              child: _controller.recipientProfilePic == null
                  ? Icon(Icons.person, size: 24, color: Colors.grey[600])
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _controller.recipientUsername ?? "Loading...",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _controller.isChatEnded ? Colors.red : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _controller.isChatEnded ? "Chat Ended" : "Online", 
                      style: TextStyle(
                        color: _controller.isChatEnded ? Colors.red : Colors.green, 
                        fontSize: 12
                      ),
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
          if (!_controller.isChatEnded && _controller.meetingConfirmed)
          IconButton(
            icon: Icon(
              _showMap ? Icons.chat : Icons.map,
              color: Colors.blue,
            ),
            onPressed: () {
              setState(() {
                _showMap = !_showMap;
                _mapToggledOff = !_showMap; // Track manual toggle
              });
            },
            tooltip: _showMap ? 'Show Chat' : 'Show Map',
          ),
          if (!_controller.isChatEnded) // Show settings only if chat is active
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.orange),
              onPressed: () {},
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_controller.isChatEnded) 
              const ChatEndedBanner(
                message: "This conversation has been ended and you can no longer send messages.",
              ),
            
            // Meeting status banner - shows when there's a pending/confirmed meeting
            if (!_controller.isChatEnded && 
                (_controller.currentUserRequestedMeeting || 
                 _controller.recipientRequestedMeeting || 
                 _controller.meetingConfirmed))
              _buildMeetingStatusBanner(),
              
            // Action buttons pane (Meet/Decline)
            if (!_controller.isChatEnded && !_showMap)
              ActionButtonsPane(
                onEndChat: _confirmEndChat,
                onDecline: _confirmDeclineChat,
                onMeet: _handleMeet,  
                disabled: _controller.currentUserRequestedMeeting || _controller.meetingConfirmed,
                ageGapWarningNeeded: _controller.ageGapWarningNeeded,
                isCurrentUserMinor: _controller.isCurrentUserMinor,
                meetingRequested: _controller.currentUserRequestedMeeting,
                meetingConfirmed: _controller.meetingConfirmed,
              ),
              
            // Show either map or chat based on the state
            if (_showMap && _controller.meetingConfirmed && _controller.currentUserId != null)
            Expanded(
              child: Container(
                clipBehavior: Clip.none, // This prevents overflow clipping
                child: MeetingMapView(
                  currentUserId: _controller.currentUserId!,
                  recipientId: widget.recipientId,
                  recipientUsername: _controller.recipientUsername ?? "User",
                ),
              ),
            )
            else
              Expanded(
                child: MessagesList(
                  messagesStream: _controller.messagesStream,
                  messages: _controller.messages,
                  currentUserId: _controller.currentUserId,
                  isChatEnded: _controller.isChatEnded,
                  ageGapWarningNeeded: _controller.ageGapWarningNeeded,
                  isCurrentUserMinor: _controller.isCurrentUserMinor,
                  buildChatBubble: (message, isMine) => ChatBubble(
                    message: message,
                    isMine: isMine,
                  ),
                  buildSystemMessage: (message) => SystemMessage(
                    message: message,
                  ),
                ),
              ),
            
            // Only show the message input if we're in chat mode
            if (!_controller.isChatEnded && !_showMap)
              MessageInput(
                onSend: (text) async {
                  try {
                    await _controller.sendMessage(text);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
              
            // Show action buttons for the map view
            if (_showMap && _controller.meetingConfirmed && !_controller.isChatEnded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _handleMeetingResult(true); // We Met successfully
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text("We Met"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _handleMeetingResult(false); // We did not meet
                      },
                      icon: const Icon(Icons.cancel),
                      label: const Text("We Did Not Meet"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
              
            if (_controller.isChatEnded)
              ChatEndedFooter(
                onReturn: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}