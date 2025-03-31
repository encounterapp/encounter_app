import 'package:encounter_app/pages/register_page.dart';
import 'package:encounter_app/pages/sign_in.dart';
import 'package:flutter/material.dart';

class LoginOrRegisterPage extends StatefulWidget {
  const LoginOrRegisterPage({super.key});

  @override
  State<LoginOrRegisterPage> createState() => _LoginOrRegisterPageState();
}

class _LoginOrRegisterPageState extends State<LoginOrRegisterPage> {
  // Initially show the login page
  bool showSignInPage = true;

  //toggle between login and register page
  void toggleLoginRegister() {
    setState(() {
      showSignInPage = !showSignInPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showSignInPage) {
      return RegisterPage(onTap: toggleLoginRegister);
    }
    else {
      return SignInPage(onTap: toggleLoginRegister);
    }
  }
}