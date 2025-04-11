import 'package:flutter/material.dart';
import 'package:encounter_app/utils/safety_manager.dart';
import 'package:timeago/timeago.dart' as timeago;

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({Key? key}) : super(key: key);

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final blockedUsers = await SafetyManager.getBlockedUsers();
      
      if (mounted) {
        setState(() {
          _blockedUsers = blockedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading blocked users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unblockUser(String userId, String username) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User?'),
        content: Text('Are you sure you want to unblock $username? They will be able to see your posts and contact you again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('UNBLOCK'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unblocking user...'),
          duration: Duration(seconds: 1),
        ),
      );

      final success = await SafetyManager.unblockUser(userId);
      
      if (success && mounted) {
        // Refresh the list
        _loadBlockedUsers();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully unblocked $username'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to unblock user. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unblocking user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBlockedUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : _buildBlockedUsersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Blocked Users',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t blocked any users yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'When you block someone, they won\'t be able to contact you or see your posts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUsersList() {
    return ListView.builder(
      itemCount: _blockedUsers.length,
      itemBuilder: (context, index) {
        final blockedUser = _blockedUsers[index];
        final profiles = blockedUser['profiles'];
        final username = profiles?['username'] ?? 'Unknown User';
        final avatarUrl = profiles?['avatar_url'];
        final blockedId = blockedUser['blocked_id'];
        final blockedAt = DateTime.parse(blockedUser['created_at']);
        
        return Dismissible(
          key: Key(blockedId),
          background: Container(
            color: Colors.blue,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(
              Icons.remove_circle,
              color: Colors.white,
            ),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Unblock User?'),
                content: Text('Are you sure you want to unblock $username?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCEL'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('UNBLOCK'),
                  ),
                ],
              ),
            ) ?? false;
          },
          onDismissed: (direction) {
            SafetyManager.unblockUser(blockedId);
            
            setState(() {
              _blockedUsers.removeAt(index);
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully unblocked $username'),
                backgroundColor: Colors.green,
              ),
            );
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey[300],
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? Icon(Icons.person, color: Colors.grey[600]) : null,
            ),
            title: Text(
              username,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Blocked ${timeago.format(blockedAt)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            trailing: TextButton.icon(
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Unblock'),
              onPressed: () => _unblockUser(blockedId, username),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ),
        );
      },
    );
  }
}