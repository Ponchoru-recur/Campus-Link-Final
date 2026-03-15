import 'package:flutter/material.dart';
import 'package:luminescence/pages/channels/channel.dart';
import 'package:luminescence/pages/fake_gmail.dart';
import 'package:luminescence/pages/loading.dart';
import 'package:luminescence/pages/home.dart';
import 'package:luminescence/pages/login.dart';

void main() {
  runApp(
    MaterialApp(
      // home
      // initialRoute: '/gmail',
      routes: {
        '/': (context) => LoadingScreen(),
        '/login': (context) => LoginScreen(),
        '/gmail': (context) => FakeEmail(),
        '/home': (context) => HomeScreen(),
        '/channel': (context) => ChannelScreen(),
      },
    ),
  );
}
