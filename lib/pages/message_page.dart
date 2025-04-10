import 'package:encounter_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encounter_app/pages/setting_menu.dart';
import 'package:encounter_app/pages/new_chat.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _activeConversations = [];
  List<Map<String, dynamic>> _archivedConversations = [];
  bool _isLoading = true;
  String? currentUserId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      // Fetch all chat sessions for the current user
      final chatSessionsQuery = await supabase
          .from('chat_sessions')
          .select('id, user1_id, user2_id, status, ended_at, created_at, post_id')
          .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId');
      
      // Extract partner IDs from each session
      List<Map<String, dynamic>> activeConversations = [];
      List<Map<String, dynamic>> archivedConversations = [];
      
      // Process each chat session
      for (final session in chatSessionsQuery) {
        // Determine partner ID (the other user)
        final partnerId = session['user1_id'] == currentUserId 
            ? session['user2_id'] : session['user1_id'];
        
        // Get partner profile
        final profileResponse = await supabase
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', partnerId)
            .maybeSingle();
            
        if (profileResponse == null) continue;
        
        // Get latest message from this chat session
        final latestMessageQuery = await supabase
            .from('messages')
            .select()
            .eq('chat_session_id', session['id'])  // Use chat_session_id field
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        
        // If no messages found with chat_session_id, try the old way (direct sender/receiver)
        if (latestMessageQuery == null) {
          final directMessageQuery = await supabase
              .from('messages')
              .select()
              .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$currentUserId)')
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
              
          if (directMessageQuery == null) continue;
          
          // Create conversation entry
          final conversation = {
            'id': partnerId,
            'username': profileResponse['username'] ?? 'Unknown User',
            'avatar_url': profileResponse['avatar_url'],
            'last_message': directMessageQuery['content'],
            'timestamp': directMessageQuery['created_at'],
            'is_sender': directMessageQuery['sender_id'] == currentUserId,
            'chat_status': session['status'],
            'ended_at': session['ended_at'],
            'chat_session_id': session['id'],
            'post_id': session['post_id'],
          };
          
          // Add to appropriate list based on chat status
          if (session['status'] == 'ended') {
            archivedConversations.add(conversation);
          } else {
            activeConversations.add(conversation);
          }
        } else {
          // Create conversation entry from chat_session_id message
          final conversation = {
            'id': partnerId,
            'username': profileResponse['username'] ?? 'Unknown User',
            'avatar_url': profileResponse['avatar_url'],
            'last_message': latestMessageQuery['content'],
            'timestamp': latestMessageQuery['created_at'],
            'is_sender': latestMessageQuery['sender_id'] == currentUserId,
            'chat_status': session['status'],
            'ended_at': session['ended_at'],
            'chat_session_id': session['id'],
            'post_id': session['post_id'],
          };
          
          // Add to appropriate list based on chat status
          if (session['status'] == 'ended') {
            archivedConversations.add(conversation);
          } else {
            activeConversations.add(conversation);
          }
        }
      }
    
    // Sort by latest message
    activeConversations.sort((a, b) => 
        DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
    archivedConversations.sort((a, b) => 
        DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));

    if (mounted) {
      setState(() {
        _activeConversations = activeConversations;
        _archivedConversations = archivedConversations;
        _isLoading = false;
      });
    }
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(localizations.messages, style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: localizations.active),
            Tab(text: localizations.archived),
          ],
        ),
      ),
      drawer: const SettingsMenu(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : currentUserId == null
              ? _buildLoginPrompt(localizations)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildConversationsList(_activeConversations, isArchived: false, localizations: localizations),
                    _buildConversationsList(_archivedConversations, isArchived: true, localizations: localizations),
                  ],
                ),
    );
  }

  Widget _buildLoginPrompt(AppLocalizations localizations) {
    return Center(
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
            child: Text(localizations.signIn),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList(List<Map<String, dynamic>> conversations, {required bool isArchived, required AppLocalizations localizations}) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isArchived ? Icons.archive : Icons.message,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isArchived ? localizations.noArchivedConversations : localizations.noActiveConversations,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchConversations();
      },
      child: ListView.separated(
        itemCount: conversations.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: conversation['avatar_url'] != null
                  ? NetworkImage(conversation['avatar_url'])
                  : const AssetImage('assets/icons/flutter_logo.png') as ImageProvider,
              radius: 25,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    conversation['username'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isArchived)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      localizations.archived,
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
              ],
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
            onTap: () async {
              await Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
                    recipientId: conversation['id'],
                    postId: conversation['post_id'],
                    chatSessionId: conversation['chat_session_id'],
                  ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    const curve = Curves.easeOut;
                    
                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    
                    return SlideTransition(position: offsetAnimation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                  reverseTransitionDuration: const Duration(milliseconds: 300),
                ),
              );
              _fetchConversations();
            },
          );
        },
      ),
    );
  }
}