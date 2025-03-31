import 'package:encounter_app/pages/sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin{

  @override
    void initState() {
        super.initState();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

        Future.delayed(Duration(seconds: 3), () {
            Navigator.push(
              context, PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>SignInPage(onTap: () {}),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
              );
            },
          ),
        );
    });
    }

  @override
    void dispose() {
        super.dispose();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
      
    }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
    clipBehavior: Clip.antiAlias,
    decoration: ShapeDecoration(
        color: Color(0xFFEDB709),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
        ),
    ),
    child: Stack(
        children: [
            Positioned(
                left: 0,
                top: 341,
                child: Container(
                    width: 400,
                    height: 185,
                    decoration: BoxDecoration(
                        image: DecorationImage(
                            image: AssetImage('assets/icons/SplashPage.jpg'),
                            fit: BoxFit.fill,
                        ),
                    ),
                ),
            ),
        ],
    ),
)
      );
  }
}