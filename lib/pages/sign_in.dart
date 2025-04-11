import 'package:encounter_app/components/my_buttons.dart';
import 'package:encounter_app/components/my_textfields.dart';
import 'package:encounter_app/components/square_tile.dart';
import 'package:encounter_app/pages/home_page.dart';
import 'package:encounter_app/pages/login_or_register.dart';
import 'package:encounter_app/pages/reset_password.dart';
import 'package:flutter/material.dart';
import 'package:encounter_app/pages/auth_service.dart';

class SignInPage extends StatefulWidget {
  final Function()? onTap;
  const SignInPage({super.key, required this.onTap});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  // Get Auth Service
  final authService = SupabaseAuthService();
  // Text editing controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  //Sign User In Method
  void signUserIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    
    // Validate inputs
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password'),
        ),
      );
      return;
    }
    
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });
    
    //attempt to sign in user
    try {
      final response = await authService.signInWithEmailPassword(
        email: email, 
        password: password
      );
      
      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });
      
      // Check if sign in was successful
      if (response.user != null) {
        // Call onTap callback if it exists
        if (widget.onTap != null) {
          widget.onTap!();
        }
        
        // Navigate to Home Page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const HomePage(selectedIndex: 0),
            ),
          );
        }
      } else {
        // Show error message if sign in failed but no exception was thrown
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid email or password'),
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
                  // Add the gradient background
      backgroundColor: Colors.transparent, // Set to transparent to show the gradient
      extendBodyBehindAppBar: true, // Extend the body behind the app bar
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(255,179,189,1),
              Color.fromRGBO(254,248,154,1),
              Color.fromRGBO(161,224,186,1),
            ],
            stops: [0.018, 0.506, 1.03], // 1.8% and 50.6% and 100.3%
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
          // Greetings
          const SizedBox(height: 20),
          Text('Welcome, we are happy to see you again!',
              style: TextStyle(color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )
          ),
          const SizedBox(height: 20),

          // Sign In
          const Text('Sign In',
              style: TextStyle(color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              )
          ),
          const SizedBox(height: 20),


          // Username TextField
          MyTextfields(
            controller: emailController,
            hintText: 'Email',
            obscureText: false,
          ),
          const SizedBox(height: 10),


          // Password TextField
          MyTextfields(
            controller: passwordController,
            hintText: 'Password', 
            obscureText: true),
          const SizedBox(height: 5),

          // Forgot Password
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
             GestureDetector(
                onTap: () {
                  Navigator.push(context,
                    MaterialPageRoute(
                      builder: (context) => ResetPasswordPage(onTap: widget.onTap),
                          ),
                        );
                      },
                child: const Text('Reset Password',
                  style: TextStyle(
                    color: Colors.blue,
                  ),
                ),
              ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Sign In Button
          _isLoading
              ? const CircularProgressIndicator()
              : MyButtons(onTap: signUserIn),
          const SizedBox(height: 20),

          /*// or Continue with
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    thickness: 0.5,
                    color: Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'or Continue with',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(
                    thickness: 0.5,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Google Button + Apple Button + Facebook Button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //Google Button
              SquareTile(imagePath:'assets/icons/google.png'),
              const SizedBox(width: 15),
              //Apple Button
              SquareTile(imagePath:'assets/icons/apple.png'),
            ],
          ),
          const SizedBox(height: 20),*/
          
          
          // Create Account
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Don\'t have an account?'),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: () {
                  Navigator.push(context,
                    MaterialPageRoute(
                      builder: (context) => const LoginOrRegisterPage(),
                          ),
                        );
                      },
                child: const Text('Create Account',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    ),
    ),
    ),
    ));
  }
}