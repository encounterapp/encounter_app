import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/components/google_meeting_map_view.dart';
import 'package:encounter_app/widgets/chat_bubble.dart';
import 'package:encounter_app/widgets/system_message.dart';
import 'package:encounter_app/widgets/message_input.dart';
import 'package:encounter_app/widgets/message_list.dart';
import 'package:encounter_app/widgets/chat_ended_banner.dart';
import 'package:encounter_app/widgets/chat_ended_footer.dart';
import 'package:encounter_app/widgets/action_buttons_pane.dart';
import 'package:encounter_app/utils/age_verification_utils.dart';
import 'package:encounter_app/controllers/chat_controller.dart';
import 'package:encounter_app/widgets/map_action_buttons.dart';

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
    
    _controller.addListener(_controllerUpdated);
    
    // Check age verification after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showAgeVerificationIfNeeded();
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
  }
  
  @override
  void dispose() {
    _controller.removeListener(_controllerUpdated);
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> _showAgeVerificationIfNeeded() async {
    // Skip if no verification needed or already verified
    if (!mounted || 
        _controller.ageVerified || 
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
      if (mounted) Navigator.of(context).pop();
    }
  }
  
  // Generic confirmation dialog
  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: confirmColor),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Loading dialog wrapper
  Future<T?> _withLoadingOverlay<T>(Future<T> Function() action) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final result = await action();
      if (mounted) Navigator.of(context).pop();
      return result;
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operation failed: ${e.toString()}')),
        );
      }
      return null;
    }
  }
  
  Future<void> _confirmEndChat() async {
    if (_controller.isChatEnded) return;

    final confirmed = await _showConfirmationDialog(
      title: 'End Conversation',
      message: 'Are you sure you want to end this conversation? '
              'You will not be able to message this user again.',
      confirmText: 'END CHAT',
    );

    if (confirmed) {
      await _withLoadingOverlay(() async {
        await _controller.endChat(reason: 'ended');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat has been ended successfully')),
          );
        }
      });
    }
  }

  Future<void> _handleMeet() async {
    if (_controller.isChatEnded || _controller.currentUserRequestedMeeting) return;
    
    await _withLoadingOverlay(() async {
      await _controller.requestMeeting();
      
      // Show appropriate message based on meeting status
      if (mounted) {
        if (_controller.meetingConfirmed) {
          setState(() => _showMap = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meeting confirmed! You both have accepted to meet.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meeting request sent to ${_controller.recipientUsername ?? "the other user"}.'),
            ),
          );
        }
      }
    });
  }

  Future<void> _confirmDeclineChat() async {
    if (_controller.isChatEnded) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Decline Conversation',
      message: 'Are you sure you want to decline this conversation? '
              'You will not be able to message this user for 24 hours.',
      confirmText: 'DECLINE',
    );

    if (confirmed) {
      await _withLoadingOverlay(() async {
        await _controller.endChat(reason: 'declined');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User has been declined')),
          );
        }
      });
    }
  }

  Future<void> _handleMeetingResult(bool didMeet) async {
    final confirmed = await _showConfirmationDialog(
      title: didMeet ? 'Confirm Meeting Success' : 'Confirm Meeting Did Not Happen',
      message: didMeet 
          ? 'Are you confirming that you successfully met with ${_controller.recipientUsername ?? "this user"}?'
          : 'Are you confirming that you did not meet with ${_controller.recipientUsername ?? "this user"}?',
      confirmText: 'CONFIRM',
      confirmColor: didMeet ? Colors.green : Colors.red,
    );

    if (!confirmed) return;

    await _withLoadingOverlay(() async {
      final userId = _controller.currentUserId;
      if (userId == null) return;

      // Create unique key for this chat session
      final smallerId = userId.compareTo(widget.recipientId) < 0 
          ? userId : widget.recipientId;
      final largerId = userId.compareTo(widget.recipientId) < 0 
          ? widget.recipientId : userId;
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
    });
  }

  Widget _buildMeetingStatusBanner() {
    if (_controller.meetingConfirmed) {
      return _buildStatusBanner(
        color: Colors.green,
        icon: Icons.check_circle,
        message: "You both have accepted to meet. Map shown below.",
      );
    } else if (_controller.currentUserRequestedMeeting) {
      return _buildStatusBanner(
        color: Colors.blue,
        icon: Icons.info_outline,
        message: "You have accepted to meet. Waiting for ${_controller.recipientUsername ?? 'other user'} to accept.",
      );
    } else if (_controller.recipientRequestedMeeting) {
      return _buildStatusBanner(
        color: Colors.orange,
        icon: Icons.notifications_active,
        message: "${_controller.recipientUsername ?? 'Other user'} has accepted to meet. Click 'Meet' to confirm.",
        bold: true,
      );
    }
    
    return const SizedBox.shrink();
  }
  
  Widget _buildStatusBanner({
    required Color color, 
    required IconData icon, 
    required String message,
    bool bold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Color.fromRGBO(color.r.toInt(), color.g.toInt(), color.b.toInt(), 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color.fromRGBO(color.r.toInt(), color.g.toInt(), color.b.toInt(), 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Color.fromRGBO(color.r.toInt(), color.g.toInt(), color.b.toInt(), 0.7),
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // This method was removed and replaced by the MapActionButtons widget

  @override
  Widget build(BuildContext context) {
    // Show loading indicator until initialization is complete
    if (!_controller.isInitialized && _controller.currentUserId != null) {
      return _buildLoadingScreen();
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Chat ended banner
            if (_controller.isChatEnded) 
              const ChatEndedBanner(
                message: "This conversation has been ended and you can no longer send messages.",
              ),
            
            // Meeting status banner
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
            _buildMainContent(),
            
            // Chat ended footer or map action buttons
            if (_controller.isChatEnded)
              ChatEndedFooter(
                onReturn: () => Navigator.of(context).pop(),
              )
            else if (_showMap && _controller.meetingConfirmed && !_controller.isChatEnded)
              MapActionButtons(
                onWeMetPressed: () => _handleMeetingResult(true),
                onDidNotMeetPressed: () => _handleMeetingResult(false),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingScreen() {
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
  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
    );
  }
  
  Widget _buildMainContent() {
    // Show map view
    if (_showMap && _controller.meetingConfirmed && _controller.currentUserId != null) {
      return Expanded(
        child: Container(
          clipBehavior: Clip.none,
          child: GoogleMeetingMapView(
            currentUserId: _controller.currentUserId!,
            recipientId: widget.recipientId,
            recipientUsername: _controller.recipientUsername ?? "User",
          ),
        ),
      );
    }
    
    // Show message list
    return Expanded(
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
    );
  }
}