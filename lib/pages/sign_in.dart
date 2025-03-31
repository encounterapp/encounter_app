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

//Sign User In Method
  void SignUserIn() {
    final email = emailController.text;
    final password = passwordController.text;
    
    //attempt to sign in user
    try {
      authService.signInWithEmailPassword(email: email, password: password);
      widget.onTap!();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid email or password'),
        ),
      );
    }
    // Navigate to Home Page
    Navigator.push(context,
      MaterialPageRoute(
        builder: (context) => HomePage(selectedIndex: 0,),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
        child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // Logo
          Icon(
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
          MyButtons(onTap: SignUserIn,),
          const SizedBox(height: 20),

          // or Continue with
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
          const SizedBox(height: 20),
          
          
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
                      builder: (context) => LoginOrRegisterPage(),
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
    );
  }
}