import 'package:flutter/material.dart';

class MessagesList extends StatefulWidget {
  final Stream<List<Map<String, dynamic>>>? messagesStream;
  final List<Map<String, dynamic>> messages;
  final String? currentUserId;
  final bool isChatEnded;
  final bool ageGapWarningNeeded;
  final bool isCurrentUserMinor;
  final Function(String, bool) buildChatBubble;
  final Function(String) buildSystemMessage;
  
  const MessagesList({
    Key? key,
    required this.messagesStream,
    required this.messages,
    required this.currentUserId,
    required this.isChatEnded,
    required this.ageGapWarningNeeded,
    required this.isCurrentUserMinor,
    required this.buildChatBubble,
    required this.buildSystemMessage,
  }) : super(key: key);

  @override
  State<MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<MessagesList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.messagesStream,
      builder: (context, snapshot) {
        if (widget.messages.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Show empty state message if there are no messages
        if (widget.messages.isEmpty) {
          return _buildEmptyState();
        }

        final displayMessages = List<Map<String, dynamic>>.from(widget.messages);
        
        // Insert age verification message at the beginning if needed
        if (widget.ageGapWarningNeeded && displayMessages.isNotEmpty) {
          // Check if we already have an age verification message
          bool hasAgeMessage = displayMessages.any((msg) => 
            msg['is_system_message'] == true && 
            (msg['content'].toString().contains('under 18') || 
             msg['content'].toString().contains('minor'))
          );
          
          if (!hasAgeMessage) {
            final String ageMessage = widget.isCurrentUserMinor 
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

        // Scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          itemCount: displayMessages.length,
          itemBuilder: (context, index) {
            final msg = displayMessages[index];
            final isMine = msg['sender_id'] == widget.currentUserId;
            final isSystemMessage = msg['is_system_message'] == true;
            
            if (isSystemMessage) {
              return widget.buildSystemMessage(msg['content']);
            }
            
            return widget.buildChatBubble(msg['content'], isMine);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
            widget.isChatEnded 
                ? "This chat ended without any messages" 
                : "Start a conversation!",
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          // Add age warning in empty state if needed
          if (widget.ageGapWarningNeeded && !widget.isChatEnded)
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
                      widget.isCurrentUserMinor 
                        ? "Remember: You are chatting with an adult" 
                        : "Remember: You are chatting with a minor",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isCurrentUserMinor
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
}