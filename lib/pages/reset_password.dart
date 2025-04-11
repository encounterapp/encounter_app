import 'package:flutter/material.dart';
import 'package:encounter_app/services/auth_service.dart';
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
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;
  
  // Request reset password email
  Future<void> _requestResetEmail() async {
    final email = _emailController.text;

    // Check if email is valid
    bool isValidEmail(String email) {
      String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
      RegExp regExp = RegExp(emailPattern);
      return regExp.hasMatch(email);
    }

    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid email')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Request password reset
      await authService.resetPasswordForEmail(email: email);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _codeSent = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check email for reset code')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  // Reset password with verification code
  Future<void> _resetPassword() async {
    final email = _emailController.text;
    final code = _codeController.text;
    final newPassword = _newPasswordController.text;
    
    if (code.isEmpty || newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both code and new password')),
      );
      return;
    }
    
    // Validate password
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Reset password with verification code
      final success = await authService.verifyPasswordReset(
        email: email,
        token: code,
        newPassword: newPassword,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset successfully')),
          );
          
          // Return to sign in page
          widget.onTap?.call();
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
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        title: const Text('Reset Password',
          style: TextStyle(
            color: Colors.black,
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
              const Icon(
                Icons.account_circle,
                size: 100,
                color: Colors.black,
              ),
              // Greetings
              const SizedBox(height: 20),
              Text(
                _codeSent 
                  ? 'Enter verification code and new password' 
                  : 'Let us get you back on track!',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Email TextField
              MyTextfields(
                controller: _emailController,
                hintText: 'Email',
                obscureText: false,
                enabled: !_codeSent, // Disable once code is sent
              ),
              const SizedBox(height: 20),
              
              // If code sent, show code and new password inputs
              if (_codeSent) ...[
                MyTextfields(
                  controller: _codeController,
                  hintText: 'Verification Code',
                  obscureText: false,
                ),
                const SizedBox(height: 20),
                MyTextfields(
                  controller: _newPasswordController,
                  hintText: 'New Password',
                  obscureText: true,
                ),
                const SizedBox(height: 20),
              ],

              // Action Button
              _isLoading
                  ? const CircularProgressIndicator()
                  : MyButtons(
                      onTap: _codeSent ? _resetPassword : _requestResetEmail,
                    ),
              const SizedBox(height: 20),
              
              // Resend button if code already sent
              if (_codeSent)
                TextButton(
                  onPressed: _requestResetEmail,
                  child: const Text("Didn't receive code? Send again"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}