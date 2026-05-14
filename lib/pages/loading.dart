import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;

      // Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amberAccent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitFoldingCube(color: Colors.green, size: 50.0),
            SizedBox(height: 10),
            Text(
              "Campus Link",
              style: TextStyle(
                fontSize: 36,
                fontFamily: "Poppins",
                fontWeight: FontWeight.normal,
              ),
            ),
            // Text(
            //   "Academic Messaging, Simplified",
            //   style: TextStyle(fontSize: 18, fontFamily: "Poppins"),
            // ),
            Text("Caraga State University"),
          ],
        ),
      ),
    );
  }
}
