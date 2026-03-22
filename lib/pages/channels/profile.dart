import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void testing() {
    FirebaseFirestore.instance.collection("Users").get().then((snapshot) {
      print("Total users in collection: ${snapshot.docs.length}");
      for (var doc in snapshot.docs) {
        print("c: ${doc.data()}");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: Center(
        child: ElevatedButton(onPressed: testing, child: Text("Test user")),
      ),
    );
  }
}
