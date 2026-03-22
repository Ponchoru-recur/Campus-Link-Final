import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/firebase_options.dart';
import 'package:luminescence/pages/auth/auth_gate.dart';
import 'package:luminescence/pages/auth/register.dart';
import 'package:luminescence/pages/auth/verified_page.dart';
import 'package:luminescence/pages/channels/announcements.dart';
import 'package:luminescence/pages/channels/assignments.dart';
import 'package:luminescence/pages/channels/group_chats.dart';
import 'package:luminescence/pages/channels/policies.dart';
import 'package:luminescence/pages/channels/profile.dart';
import 'package:luminescence/pages/channels/settings.dart';
import 'package:luminescence/pages/fake_gmail.dart';
import 'package:luminescence/pages/home.dart';
import 'package:luminescence/pages/auth/login.dart';
import 'package:luminescence/themes/app_theme.dart';

// import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MaterialApp(
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: ThemeMode.light,
      // initialRoute: AuthGate(),
      home: AuthGate(),
      routes: {
        // '/': (context) => LoadingScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/gmail': (context) => FakeEmail(),
        '/verified': (context) => VerifiedPageScreen(),
        '/home': (context) => HomeScreen(),
        '/profile': (context) => ProfileScreen(),
        '/channel': (context) => ChanncelScreen(),
        '/assignment': (context) => AssignmentScreen(),
        '/announcement': (context) => AnnouncementScreen(),
        '/setting': (context) => SettingScreen(),
        '/policy': (context) => PolicySceen(),
      },
    ),
  );
}

// 1:533268737690:android:7661542a4224b2e64fb923
