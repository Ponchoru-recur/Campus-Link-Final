import 'package:flutter/material.dart';
import 'package:luminescence/pages/login/login_screen.dart';
import 'package:luminescence/pages/role_selection/role_selection_screen.dart';
import 'package:luminescence/themes/app_theme.dart';

// import 'package:firebase_core/firebase_core.dart';

void main() async {
  runApp(
    MaterialApp(
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: ThemeMode.light,
      // initialRoute: AuthGate(),
      // home: AuthGate(),
      routes: {
        '/': (context) => RoleSelectionScreen(),
        '/login': (context) => LoginScreen(),
        // '/register': (context) => RegisterScreen(),
        // '/gmail': (context) => FakeEmail(),
        // '/verified': (context) => VerifiedPageScreen(),
        // '/home': (context) => HomeScreen(),
        // '/profile': (context) => ProfileScreen(),
        // '/channel': (context) => ChanncelScreen(),
        // '/assignment': (context) => AssignmentScreen(),
        // '/announcement': (context) => AnnouncementScreen(),
        // '/setting': (context) => SettingScreen(),
        // '/policy': (context) => PolicySceen(),
      },
    ),
  );
}

// 1:533268737690:android:7661542a4224b2e64fb923
