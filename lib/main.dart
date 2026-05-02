import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chats_screen.dart';
import 'package:luminescence/pages/login/login_screen.dart';
import 'package:luminescence/pages/role_selection/role_selection_screen.dart';
import 'package:luminescence/themes/app_theme.dart';

// import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await testFirebaseConnection();

  runApp(
    MaterialApp(
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: ThemeMode.light,
      routes: {
        '/': (context) => RoleSelectionScreen(),
        '/login': (context) => LoginScreen(),
        '/chatScreen': (context) => ChatsScreen(),
      },
    ),
  );
}

// 1:533268737690:android:7661542a4224b2e64fb923
Future<void> testFirebaseConnection() async {
  try {
    await FirebaseAuth.instance.signInAnonymously();
    print("✅ Firebase connected successfully");
  } catch (e) {
    print("❌ Firebase error: $e");
  }
}
