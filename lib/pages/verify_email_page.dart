import 'package:flutter/material.dart';
import 'package:encounter_app/pages/auth_service.dart';
import 'package:encounter_app/components/my_buttons.dart';
import 'package:encounter_app/components/my_textfields.dart';
import 'package:encounter_app/pages/create_profile.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;
  const VerifyEmailPage({super.key, required this.email});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final authService = SupabaseAuthService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyEmail() async {
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter verification code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Verify the email using the code
      final result = await authService.verifyEmail(
        email: widget.email,
        token: _codeController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result) {
          // Successfully verified
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CreateProfilePage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid verification code')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        title: const Text(
          'Verify Your Email',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 50),
              const Icon(
                Icons.email_outlined,
                size: 100,
                color: Colors.black,
              ),
              const SizedBox(height: 20),
              Text(
                'A verification code has been sent to',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              MyTextfields(
                controller: _codeController,
                hintText: 'Enter verification code',
                obscureText: false,
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : MyButtons(onTap: _verifyEmail),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  // Resend verification code
                  authService.resendVerificationCode(email: widget.email);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification code resent')),
                  );
                },
                child: const Text("Didn't receive code? Send again"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}