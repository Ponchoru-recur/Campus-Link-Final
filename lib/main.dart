import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chats_screen.dart';
import 'package:luminescence/pages/home_hamburger/updates_tasks_screen.dart';
import 'package:luminescence/pages/tasks/task_list_screen.dart';
import 'package:luminescence/pages/login/login_screen.dart';
import 'package:luminescence/pages/role_selection/role_selection_screen.dart';
import 'package:luminescence/pages/verify_email/verify_email_screen.dart';
import 'package:luminescence/themes/app_theme.dart';
import 'package:luminescence/services/notification_service.dart';

/// Top-level background message handler for FCM.
///
/// Must be a top-level function (not a class method) because it runs in a
/// separate isolate. The @pragma annotation is required for Dart to retain
/// this function in the compiled output.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // No UI updates possible in isolate — just log receipt
  debugPrint('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: ThemeMode.light,
      home: const AuthWrapper(),
      routes: {
        '/roleSelection': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/chatScreen': (context) => const ChatsScreen(),
        '/updatesTasks': (context) => const UpdatesTasksScreen(),
        '/tasks': (context) => const TaskListScreen(),
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
          return const RoleSelectionScreen();
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
            return const RoleSelectionScreen();
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
