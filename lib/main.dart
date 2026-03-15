import 'package:flutter/material.dart';
import 'package:luminescence/pages/channels/group_chats.dart';
import 'package:luminescence/pages/fake_gmail.dart';
import 'package:luminescence/pages/loading.dart';
import 'package:luminescence/pages/home.dart';
import 'package:luminescence/pages/auth/login.dart';
import 'package:luminescence/themes/app_theme.dart';

void main() {
  runApp(
    MaterialApp(
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: ThemeMode.light,
      // home
      // initialRoute: '/gmail',
      routes: {
        '/': (context) => LoadingScreen(),
        '/login': (context) => LoginScreen(),
        '/gmail': (context) => FakeEmail(),
        '/home': (context) => HomeScreen(),
        '/groupchat': (context) => GroupChatScreen(),
      },
    ),
  );
}
