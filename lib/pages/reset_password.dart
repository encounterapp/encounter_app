import 'package:flutter/material.dart';
import 'package:encounter_app/pages/auth_service.dart';
import 'package:encounter_app/components/my_buttons.dart';
import 'package:encounter_app/components/my_textfields.dart';

class ResetPasswordPage extends StatefulWidget {
  final Function()? onTap;
  const ResetPasswordPage({super.key, required this.onTap});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  // Get Auth Service
  final authService = SupabaseAuthService();
  // Text editing controllers
  final TextEditingController _emailController = TextEditingController();

  //Reset Password Method
  void resetPassword() async {
    final email = _emailController.text;

      // Check if email is valid
    bool isValidEmail(String email) {
    String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA0-9.-]+\.[a-zA-Z]{2,}$';
    RegExp regExp = RegExp(emailPattern);
    return regExp.hasMatch(email);
  }

  if (!isValidEmail(email)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid email'),
      ),
    );
    return;
  }

    //attempt to reset password
    try {
      authService.resetPasswordForEmail(email: email);
      widget.onTap!();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check email for verification code.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error resetting password'),
        ),
      );
    }
}
  
  @override
  Widget build(BuildContext context) {
return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        title: const Text('Reset Password',
        style: TextStyle(color: Colors.black,
        fontSize: 24,
        fontWeight: FontWeight.bold,
              )
          ),
      ),
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: SingleChildScrollView(
        child: Column(
        children: [
          // Logo
          Icon(
            Icons.account_circle,
            size: 100,
            color: Colors.black,
          ),
          // Greetings
          const SizedBox(height: 20),
          Text('Let us get you back on track!',
              style: TextStyle(color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )
          ),
          const SizedBox(height: 20),

          // Username TextField
          MyTextfields(
            controller: _emailController,
            hintText: 'Email',
            obscureText: false,
          ),
          const SizedBox(height: 20),

          // Reset Password Button
          MyButtons(onTap: resetPassword,),
          const SizedBox(height: 20),
        ],
        ),
        ),
        ),
        );
  }
}
