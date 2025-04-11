import 'package:encounter_app/components/square_tile.dart';
import 'package:encounter_app/pages/email_sign_in.dart';
import 'package:encounter_app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:encounter_app/services/auth_service.dart';
import 'package:encounter_app/pages/create_profile.dart';

class SignInPage extends StatefulWidget {
  final Function()? onTap;
  const SignInPage({super.key, required this.onTap});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  // Get Auth Service
  final authService = SupabaseAuthService();
  bool _isLoading = false;

  // Google Sign In Method
  void signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await authService.signInWithGoogle();
      
      if (response.user != null) {
        // Check if this is a new user
        final isNewUser = response.user!.createdAt == response.user!.updatedAt;
        
        if (mounted) {
          if (isNewUser) {
            // New user, navigate to profile creation
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CreateProfilePage()),
            );
          } else {
            // Existing user, navigate to home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage(selectedIndex: 0)),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Apple Sign In Method
  void signInWithApple() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await authService.signInWithApple();
      
      if (response.user != null) {
        // Check if this is a new user
        final isNewUser = response.user!.createdAt == response.user!.updatedAt;
        
        if (mounted) {
          if (isNewUser) {
            // New user, navigate to profile creation
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CreateProfilePage()),
            );
          } else {
            // Existing user, navigate to home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage(selectedIndex: 0)),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // LINE Sign In Method
  void signInWithLine() async {
    setState(() => _isLoading = true);
    
    try {
      // TODO: Implement LINE sign in
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LINE Sign In feature coming soon!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Kakao Sign In Method
  void signInWithKakao() async {
    setState(() => _isLoading = true);
    
    try {
      // TODO: Implement Kakao sign in
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kakao Sign In feature coming soon!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Add the gradient background
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(255, 179, 189, 1),
              Color.fromRGBO(254, 248, 154, 1),
              Color.fromRGBO(161, 224, 186, 1),
            ],
            stops: [0.018, 0.506, 1.03],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  const Icon(
                    Icons.account_circle,
                    size: 100,
                    color: Colors.black,
                  ),
                  
                  // Greeting
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome to Encounter!',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  const Text(
                    'Sign in to connect with people around you',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Social Sign In Buttons
                  // Google Sign In
                  _buildSocialSignInButton(
                    'Sign in with Google',
                    'assets/icons/google.png',
                    signInWithGoogle,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Apple Sign In
                  _buildSocialSignInButton(
                    'Sign in with Apple',
                    'assets/icons/apple.png',
                    signInWithApple,
                    backgroundColor: Colors.black,
                    textColor: Colors.white,
                  ),              

                  const SizedBox(height: 30),
                  
                  // OR divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            thickness: 0.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Divider(
                            thickness: 0.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Email Sign In Button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmailSignInPage(onTap: widget.onTap),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      margin: const EdgeInsets.symmetric(horizontal: 25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email, color: Colors.blue),
                          SizedBox(width: 10),
                          Text(
                            'Continue with Email',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Create Account
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: widget.onTap,
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Loading indicator
                  if (_isLoading)
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialSignInButton(
    String text,
    String imagePath,
    VoidCallback onTap, {
    Color backgroundColor = Colors.white,
    Color textColor = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: GestureDetector(
        onTap: _isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Image.asset(
                imagePath,
                height: 24,
              ),
              const Spacer(),
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              SizedBox(width: 24), // Balance the icon on the left
            ],
          ),
        ),
      ),
    );
  }
}