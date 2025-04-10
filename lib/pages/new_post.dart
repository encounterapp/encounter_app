import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:encounter_app/utils/post_manager.dart';
import 'package:encounter_app/utils/subscription_manager.dart';
import 'package:encounter_app/utils/subscription_service.dart';

class NewPost extends StatefulWidget {
  const NewPost({super.key});

  @override
  State<NewPost> createState() => _NewPostState();
}

class _NewPostState extends State<NewPost> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final supabase = Supabase.instance.client;
  DateTime? _selectedExpiration; // Stores selected expiration date & time
  bool _isPosting = false; // Loading indicator when posting
  bool _isCheckingLimits = true; // Check subscription limits on load
  int _remainingPosts = 0; // Remaining posts this month
  bool _isUnlimited = false; // Whether the user has unlimited posts

  @override
  void initState() {
    super.initState();
    _checkSubscriptionLimits();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _checkSubscriptionLimits() async {
    setState(() {
      _isCheckingLimits = true;
    });

    try {
      // Get the subscription service
      final subscriptionService = SubscriptionService();
      
      // Get remaining usage for posts
      final remaining = await subscriptionService.getRemainingUsage(LimitedFeature.posts);
      
      // Check if unlimited
      _isUnlimited = remaining < 0;
      
      if (mounted) {
        setState(() {
          _remainingPosts = remaining;
          _isCheckingLimits = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking subscription limits: $e');
      if (mounted) {
        setState(() {
          _isCheckingLimits = false;
        });
      }
    }
  }

  Future<void> _pickExpirationDateTime() async {
    DateTime now = DateTime.now();

    // Pick Date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 15)), // Allow selection up to 15 days
    );

    if (pickedDate == null) return;

    // Pick Time
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    // Combine Date and Time
    final DateTime pickedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _selectedExpiration = pickedDateTime;
    });
  }

  Future<void> _addPost() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty ||
        _selectedExpiration == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Title, content, and expiration are required!")));
      return;
    }

    setState(() => _isPosting = true); // Show loading indicator

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Prepare the post data
    final postData = {
      'user_id': userId,
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'expires_at': _selectedExpiration!.toIso8601String(),
      'status': 'active', // Default status is active
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      // Use PostManager to create the post which handles subscription checks
      final response = await PostManager.createPost(context, postData);

      if (response != null) {
        // Show a success message.
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post created successfully!')));

        // Clear the form.
        _titleController.clear();
        _contentController.clear();
        setState(() {
          _selectedExpiration = null;
          _isPosting = false;
        });

        // Navigate back.
        Navigator.pop(context, true);
      } else {
        // PostManager returns null if the operation failed.
        // We don't need to show a snackbar here as it's handled within PostManager.
        setState(() => _isPosting = false);
      }
    } catch (e) {
      // Handle other errors
      debugPrint("Error adding post: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred.")));
      setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: _isCheckingLimits
          ? const Center(child: CircularProgressIndicator())
          : _remainingPosts <= 0 && !_isUnlimited
              ? _buildLimitReachedView()
              : _buildPostForm(),
    );
  }

  Widget _buildLimitReachedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 24),
            const Text(
              'Monthly Post Limit Reached',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'You have used all your monthly posts. Upgrade to premium for more posts.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/premium');
              },
              icon: const Icon(Icons.star),
              label: const Text('Upgrade to Premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscription info banner
            if (!_isUnlimited)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Posts Remaining This Month: $_remainingPosts',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/premium'),
                            child: Text(
                              'Upgrade for more posts →',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Title Field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Content Field
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'What are you doing?',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // Status info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your post will be active until someone accepts to meet with you, or until it expires.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Expiration Time Picker
            InkWell(
              onTap: _pickExpirationDateTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    Text(
                      _selectedExpiration == null
                          ? 'Select Expiration Time'
                          : 'Expires: ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedExpiration!)}',
                      style: TextStyle(
                        color: _selectedExpiration == null ? Colors.grey[600] : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Submit Button
            ElevatedButton(
              onPressed: _isPosting ? null : _addPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Create Post', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}