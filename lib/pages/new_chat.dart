import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    
    // Show age verification if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAgeVerificationIfNeeded();
    });
  }
  
  void _controllerUpdated() {
    if (mounted) setState(() {});
    
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
        
        await _controller.endChat();
        
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

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator until initialization is complete
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
              backgroundImage: _controller.recipientProfilePic != null
                  ? NetworkImage(_controller.recipientProfilePic!)
                  : const AssetImage('assets/icons/flutter_logo.png') as ImageProvider,
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
              const ChatEndedBanner( message: "This conversation has been ended and you can no longer send messages.",),
              
            /*if (!_controller.isChatEnded && _controller.ageGapWarningNeeded)
              AgeWarningBanner(
                message: _controller.isCurrentUserMinor 
                  ? "You are under 18 chatting with someone 18 or older. Be careful about sharing personal information and consider involving a trusted adult."
                  : "This user is under 18. Be respectful and mindful of appropriate conversation topics.",
              ),*/
              
            if (!_controller.isChatEnded)
              ActionButtonsPane(
                onEndChat: _confirmEndChat,
                disabled: false,
                ageGapWarningNeeded: _controller.ageGapWarningNeeded,
                isCurrentUserMinor: _controller.isCurrentUserMinor,
              ),
              
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
            
            if (!_controller.isChatEnded)
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