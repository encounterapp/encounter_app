import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/setting_menu.dart';
import 'package:encounter_app/pages/new_chat.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  void _initializeUser() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      currentUserId = user.id;
      _fetchConversations();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchConversations() async {
    if (currentUserId == null) return;

    try {
      // First get all unique conversations for the current user
      final messagesQuery = await supabase
          .from('messages')
          .select('sender_id, receiver_id')
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId');

      // Extract unique conversation partners
      final Set<String> conversationPartners = {};
      for (final message in messagesQuery) {
        if (message['sender_id'] == currentUserId) {
          conversationPartners.add(message['receiver_id']);
        } else {
          conversationPartners.add(message['sender_id']);
        }
      }

      // For each conversation partner, get their profile and latest message
      final List<Map<String, dynamic>> conversationList = [];
      for (final partnerId in conversationPartners) {
        // Get partner profile
        final profileResponse = await supabase
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', partnerId)
            .maybeSingle();

        // Get latest message
        final latestMessageQuery = await supabase
            .from('messages')
            .select()
            .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$currentUserId)')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (profileResponse != null && latestMessageQuery != null) {
          conversationList.add({
            'id': partnerId,
            'username': profileResponse['username'] ?? 'Unknown User',
            'avatar_url': profileResponse['avatar_url'],
            'last_message': latestMessageQuery['content'],
            'timestamp': latestMessageQuery['created_at'],
            'is_sender': latestMessageQuery['sender_id'] == currentUserId,
          });
        }
      }

      // Sort by latest message
      conversationList.sort((a, b) => 
        DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));

      setState(() {
        _conversations = conversationList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(String timestamp) {
    final messageTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        // Add icon removed
      ),
      drawer: Drawer(
        child: SettingsMenu(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentUserId == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Please log in to view your messages",
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to login page
                        },
                        child: const Text("Log In"),
                      ),
                    ],
                  ),
                )
              : _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "No conversations yet",
                            style: TextStyle(fontSize: 16),
                          ),
                          // "Start a conversation" button removed
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _fetchConversations();
                      },
                      child: ListView.separated(
                        itemCount: _conversations.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final conversation = _conversations[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: conversation['avatar_url'] != null
                                  ? NetworkImage(conversation['avatar_url'])
                                  : const AssetImage('assets/icons/flutter_logo.png') as ImageProvider,
                              radius: 25,
                            ),
                            title: Text(
                              conversation['username'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Row(
                              children: [
                                if (conversation['is_sender'])
                                  const Text(
                                    "You: ",
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                Expanded(
                                  child: Text(
                                    conversation['last_message'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(
                              _formatTimestamp(conversation['timestamp']),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            // Inside your onTap method in MessagesPage
                            onTap: () async {
                              await Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
                                    recipientId: conversation['id'],
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    const begin = Offset(0.0, 1.0); // Start from bottom
                                    const end = Offset.zero;
                                    const curve = Curves.easeOut;
                                    
                                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                    var offsetAnimation = animation.drive(tween);
                                    
                                    return SlideTransition(position: offsetAnimation, child: child);
                                  },
                                  // Optional: You can adjust these for smoother or faster transitions
                                  transitionDuration: const Duration(milliseconds: 300),
                                  reverseTransitionDuration: const Duration(milliseconds: 300),
                                ),
                              );
                              _fetchConversations();
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}