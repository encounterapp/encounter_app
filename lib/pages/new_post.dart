import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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

    try {
      final response = await Supabase.instance.client
          .from('posts')
          .insert({
            'user_id': userId,
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
            'expires_at': _selectedExpiration!.toIso8601String(),
            'status': 'active', // Default status is active
            'created_at': DateTime.now().toIso8601String(),
          })
          .select();

      if (response.isNotEmpty) {
        // Check for errors within the response data.
        if (response[0]['error'] != null) {
          String errorMessage = response[0]['error']['message'] ??
              "Failed to create post: Unknown error.";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $errorMessage")),
          );
          debugPrint("Supabase Error: $errorMessage");
           setState(() => _isPosting = false); // Stop loading on error
        } else {
          // Show a success message.
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post created successfully!')));

          // Clear the form.
          _titleController.clear();
          _contentController.clear();
          setState(() {
            _selectedExpiration = null;
          });

          // Navigate back.
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Failed to create post. Empty response.")));
        debugPrint("Supabase Error: Empty response from insert.");
         setState(() => _isPosting = false); // Stop loading on empty response.
      }
    } on PostgrestException catch (e) {
      // Catch PostgrestException
      debugPrint("Supabase PostgrestException: ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.message}")));
       setState(() => _isPosting = false); // Stop loading on exception
    } catch (e) {
      // Handle other errors during the process (e.g., network issues).
      debugPrint("Error adding post: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred.")));
       setState(() => _isPosting = false); // Stop loading on general error
    } 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
      ),
    );
  }
}