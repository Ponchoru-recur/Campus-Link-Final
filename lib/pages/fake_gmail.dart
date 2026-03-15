import 'package:flutter/material.dart';

class FakeEmail extends StatelessWidget {
  const FakeEmail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Campus Link")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Campus Link",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text("no-reply@carsu.edu.ph"),

            const SizedBox(height: 30),

            const Text("Hello Student,", style: TextStyle(fontSize: 16)),

            const SizedBox(height: 20),

            const Text(
              "Click the button below to login to Campus Link.",
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 40),

            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (Route<dynamic> route) => false,
                  );
                },
                child: const Text("Login with Magic Link"),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "This link will expire in 10 minutes.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
