import 'package:flutter/material.dart';

class MyTextfields extends StatelessWidget {
  final controller;
  final String hintText;
  final bool obscureText;
  final bool enabled;

  const MyTextfields(
    {super.key, 
    this.controller, 
    required this.hintText, 
    required this.obscureText,
    this.enabled = true,
    });

  @override
  Widget build(BuildContext context) {
    return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: TextField(
            controller: controller,
            obscureText: obscureText,
            enabled: enabled,
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              fillColor: Colors.grey.shade200,
              filled: true,
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),
          ),
    );
  }
}