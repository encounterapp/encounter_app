import 'package:flutter/material.dart';
import 'package:encounter_app/components/post_list.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PostList(), // Displays posts from the database
    );
  }
}
