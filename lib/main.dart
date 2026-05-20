import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chats_screen.dart';
import 'package:luminescence/pages/home_hamburger/updates_tasks_screen.dart';
import 'package:luminescence/pages/tasks/task_list_screen.dart';
import 'package:luminescence/pages/today/today_screen.dart';
import 'package:luminescence/pages/login/login_screen.dart';
import 'package:luminescence/pages/role_selection/role_selection_screen.dart';
import 'package:luminescence/pages/verify_email/verify_email_screen.dart';
import 'package:luminescence/pages/auth/pending_approval_screen.dart';
import 'package:luminescence/themes/app_theme.dart';
import 'package:luminescence/services/notification_service.dart';
import 'package:luminescence/services/deadline_reminder_service.dart';
import 'package:luminescence/services/user_service.dart';
import 'package:luminescence/services/user_provider_widget.dart';

/// Top-level background message handler for FCM.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('Background message: ${message.messageId}');
}

/// Top-level callback for workmanager background tasks.
///
/// Dispatches to DeadlineReminderService based on task name.
@pragma('vm:entry-point')
void _workmanagerCallback() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('Workmanager executing: $taskName');
    try {
      await Firebase.initializeApp();
    } catch (_) {}

    if (taskName == 'deadlineReminder3h' || taskName == 'deadlineReminder1h') {
      final taskId = inputData?['taskId'] as String?;
      final period = inputData?['period'] as String?;
      if (taskId != null && period != null) {
        await DeadlineReminderService.handleReminderCallback(
          taskId: taskId,
          period: period,
        );
      }
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize workmanager with callback dispatcher
  await Workmanager().initialize(_workmanagerCallback);

  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('FCM init skipped (emulator/unsupported device): $e');
  }

  // Centralized user document stream
  final userService = UserService();
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null && user.emailVerified) {
      userService.startListening(user.uid);
    } else {
      userService.stopListening();
    }
  });

  runApp(MyApp(userService: userService));
}

class MyApp extends StatelessWidget {
  final UserService userService;

  const MyApp({super.key, required this.userService});

  @override
  Widget build(BuildContext context) {
    return UserProvider(
      service: userService,
      child: MaterialApp(
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
        '/pendingApproval': (context) => const PendingApprovalScreen(),
      },
    ),
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
      return const TodayScreen();
    }
    // Load role from SharedPreferences for unverified users
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('pending_role') ?? 'student';
    return VerifyEmailScreen(email: user.email, role: role);
  }
}
