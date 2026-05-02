import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chats_screen.dart';
import 'package:luminescence/pages/login/login_screen.dart';
import 'package:luminescence/pages/role_selection/role_selection_screen.dart';
import 'package:luminescence/pages/verify_email/verify_email_screen.dart';
import 'package:luminescence/themes/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: ThemeMode.light,
      home: const AuthWrapper(),
      routes: {
        '/roleSelection': (context) => RoleSelectionScreen(),
        '/login': (context) => LoginScreen(),
        '/chatScreen': (context) => ChatsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return RoleSelectionScreen();
        }
        return FutureBuilder<Widget>(
          future: _resolveUser(user),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasData) {
              return snap.data!;
            }
            return RoleSelectionScreen();
          },
        );
      },
    );
  }

  Future<Widget> _resolveUser(User user) async {
    await user.reload();
    if (user.emailVerified) {
      return const ChatsScreen();
    }
    // Load role from SharedPreferences for unverified users
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('pending_role') ?? 'student';
    return VerifyEmailScreen(email: user.email, role: role);
  }
}
