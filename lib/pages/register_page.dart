import 'package:encounter_app/components/my_buttons.dart';
import 'package:encounter_app/components/my_textfields.dart';
import 'package:encounter_app/components/square_tile.dart';
import 'package:encounter_app/pages/auth_service.dart';
import 'package:encounter_app/pages/create_profile.dart';
import 'package:flutter/material.dart';


class RegisterPage extends StatefulWidget {
  final Function()? onTap;
  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Get Auth Service
  final authService = SupabaseAuthService();
  // Text editing controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

//Sign User Up Method
  void signUserUp() async {
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
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
  // Check if password and confirm password match
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
        ),
      );
      return;
    }
    //attempt to sign up user
    try {
      final response = await authService.signUpWithEmailPassword(
        email: email, 
        password: password);
      if (response.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CreateProfilePage()),
        ); // Navigate to Create Profile page
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign Up failed'),
        ),
      );
      print('Signup error: $e');
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
          Icon(
            Icons.account_circle,
            size: 100,
            color: Colors.black,
          ),
          // Greetings
          const SizedBox(height: 20),
          Text('Come on in, let\'s get you started!',
              style: TextStyle(color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )
          ),
          const SizedBox(height: 20),

          // Sign Up
          const Text('Sign Up',
              style: TextStyle(color: Colors.black,
                fontSize: 24,
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
          const SizedBox(height: 10),


          // Password TextField
          MyTextfields(
            controller: _passwordController,
            hintText: 'Password', 
            obscureText: true),
          const SizedBox(height: 10),
          MyTextfields(
            controller: _confirmPasswordController,
            hintText: 'Confirm Password', 
            obscureText: true),
          const SizedBox(height: 20),

          // Sign Up Button
          MyButtons(onTap: signUserUp,),
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
          
          
          // Return to Sign In Account
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Have an account?'),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: widget.onTap,
                child: const Text('Sign In',
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