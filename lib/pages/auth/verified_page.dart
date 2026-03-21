import 'package:flutter/material.dart';
import 'dart:async';

class VerifiedPageScreen extends StatefulWidget {
  const VerifiedPageScreen({super.key});

  @override
  State<VerifiedPageScreen> createState() => _VerifiedPageScreenState();
}

class _VerifiedPageScreenState extends State<VerifiedPageScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/home', (Route<dynamic> route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("You have been verified", style: TextStyle(fontSize: 18)),
                Icon(Icons.check),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
