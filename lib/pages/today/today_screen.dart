import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_item.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/group_chat_screen.dart';
import 'package:luminescence/pages/tasks/task_detail_screen.dart';
import 'package:luminescence/pages/home_hamburger/updates_tasks_screen.dart';
import 'package:luminescence/pages/home_hamburger/settings_screen/settings_screen.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chats_screen.dart';
import 'compact_task_card.dart';
import 'everyone_item.dart';
import 'mention_item.dart';

/// Data holder for an @everyone event.
class _EveryoneData {
  final String chatId;
  final String groupName;
  final String messagePreview;
  final DateTime timestamp;
  _EveryoneData({
    required this.chatId,
    required this.groupName,
    required this.messagePreview,
    required this.timestamp,
  });
}

/// Data holder for an @mention event.
class _MentionData {
  final String chatId;
  final String chatName;
  final String messagePreview;
  final String senderName;
  final DateTime timestamp;
  _MentionData({
    required this.chatId,
    required this.chatName,
    required this.messagePreview,
    required this.senderName,
    required this.timestamp,
  });
}

/// Today Dashboard — default home screen.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen>
    with WidgetsBindingObserver {
  // --- User state ---
  String? _userId;
  String _userRole = 'student';
  bool _isRevoked = false;

  // --- Tasks state ---
  final List<Task> _tasks = [];
  bool _tasksLoading = true;

  // --- Group names cache ---
  final Map<String, String> _groupNames = {};

  // --- @everyone state ---
  final List<_EveryoneData> _everyoneItems = [];
  bool _everyoneLoading = true;

  // --- @mention state ---
  final List<_MentionData> _mentionItems = [];
  bool _mentionLoading = true;

  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  StreamSubscription<QuerySnapshot>? _groupChatsSubscription;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _setupUserStream();
    _setupTasksStream();
    _setupGroupChatsStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tasksSubscription?.cancel();
    _groupChatsSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshEveryoneAndMentions();
    }
  }

  void _setupUserStream() {
    final uid = _userId;
    if (uid == null) return;
    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final data = snapshot.data();
      if (data != null) {
        setState(() {
          _userRole = data['role'] ?? 'student';
          _isRevoked = data['isRevoked'] ?? false;
        });
      }
    }, onError: (e) {
      debugPrint('Error streaming user doc: $e');
    });
  }

  void _setupTasksStream() {
    final uid = _userId;
    if (uid == null) return;
    _tasksSubscription = FirebaseFirestore.instance
        .collection('tasks')
        .where('targetUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _tasks.clear();
        for (final doc in snapshot.docs) {
          final task = Task.fromFirestore(doc);
          if (_userRole == 'faculty' && task.ignoredBy.contains(uid)) {
            continue;
          }
          _tasks.add(task);
        }
        _tasksLoading = false;
      });
    }, onError: (e) {
      debugPrint('Error in tasks stream: $e');
      if (mounted) setState(() => _tasksLoading = false);
    });
  }

  void _setupGroupChatsStream() {
    final uid = _userId;
    if (uid == null) return;
    _groupChatsSubscription = FirebaseFirestore.instance
        .collection('group_chats')
        .where('members', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final names = <String, String>{};
      List<String> chatIds = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        names[doc.id] = data['name'] ?? 'Group';
        chatIds.add(doc.id);
      }
      setState(() {
        _groupNames
          ..clear()
          ..addAll(names);
      });
      _fetchEveryoneData(chatIds);
      _fetchMentionData(chatIds);
    }, onError: (e) {
      debugPrint('Error in group chats stream: $e');
    });
  }

  Future<void> _fetchEveryoneData(List<String> chatIds) async {
    final uid = _userId;
    if (uid == null || chatIds.isEmpty) {
      if (mounted) setState(() => _everyoneLoading = false);
      return;
    }

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final results = <_EveryoneData>[];

    for (final chatId in chatIds) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('group_chats')
            .doc(chatId)
            .collection('everyone_calls')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final ts = _toDateTimeSafe(data['timestamp']);
          if (ts == null || ts.isBefore(cutoff)) continue;
          results.add(_EveryoneData(
            chatId: chatId,
            groupName: _groupNames[chatId] ?? 'Group',
            messagePreview: data['text'] ?? '',
            timestamp: ts,
          ));
        }
      } catch (e) {
        debugPrint('Error fetching everyone_calls for $chatId: $e');
      }
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (mounted) {
      setState(() {
        _everyoneItems
          ..clear()
          ..addAll(results.take(10));
        _everyoneLoading = false;
      });
    }
  }

  Future<void> _fetchMentionData(List<String> chatIds) async {
    final uid = _userId;
    if (uid == null || chatIds.isEmpty) {
      if (mounted) setState(() => _mentionLoading = false);
      return;
    }

    final startOfToday = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final results = <_MentionData>[];

    for (final chatId in chatIds) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('group_chats')
            .doc(chatId)
            .collection('mentions')
            .where('mentionedUid', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final ts = _toDateTimeSafe(data['timestamp']);
          if (ts == null || ts.isBefore(startOfToday)) continue;
          results.add(_MentionData(
            chatId: chatId,
            chatName: _groupNames[chatId] ?? 'Group',
            messagePreview: data['text'] ?? '',
            senderName: data['senderName'] ?? 'Unknown',
            timestamp: ts,
          ));
        }
      } catch (e) {
        debugPrint('Error fetching mentions for $chatId: $e');
      }
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (mounted) {
      setState(() {
        _mentionItems
          ..clear()
          ..addAll(results.take(10));
        _mentionLoading = false;
      });
    }
  }

  void _refreshEveryoneAndMentions() {
    if (_groupNames.isEmpty) return;
    final chatIds = _groupNames.keys.toList();
    setState(() {
      _everyoneLoading = true;
      _mentionLoading = true;
    });
    _fetchEveryoneData(chatIds);
    _fetchMentionData(chatIds);
  }

  // ───── Date helpers ─────

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isToday(DateTime? dt) {
    if (dt == null) return false;
    return _isSameDay(dt, DateTime.now());
  }

  bool _isOverdue(Task task) {
    if (task.deadline == null) return false;
    if (!task.isActive) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final deadlineDay = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
    return deadlineDay.isBefore(today);
  }

  int _daysLeft(Task task) {
    if (task.deadline == null) return 999;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final deadlineDay = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
    return deadlineDay.difference(today).inDays;
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  /// Safely convert Firestore timestamp field to DateTime.
  /// Handles both Timestamp and String representations.
  DateTime? _toDateTimeSafe(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ───── Section filters ─────

  List<Task> _dueToday() {
    final uid = _userId;
    return _tasks.where((t) {
      if (!t.isActive) return false;
      if (t.deadline == null) return false;
      if (uid != null && t.doneByUids.contains(uid)) return false;
      return _isToday(t.deadline!);
    }).toList()
      ..sort((a, b) => (a.deadline ?? DateTime.now())
          .compareTo(b.deadline ?? DateTime.now()));
  }

  List<Task> _dueThisWeek() {
    final uid = _userId;
    return _tasks.where((t) {
      if (!t.isActive) return false;
      if (t.deadline == null) return false;
      if (uid != null && t.doneByUids.contains(uid)) return false;
      final left = _daysLeft(t);
      if (left <= 0) return false; // overdue handled in Section 1
      return left >= 1 && left <= 7;
    }).toList()
      ..sort((a, b) => (a.deadline ?? DateTime.now())
          .compareTo(b.deadline ?? DateTime.now()));
  }

  List<Task> _unacknowledged() {
    final uid = _userId;
    if (uid == null) return [];
    return _tasks.where((t) {
      if (!t.isActive) return false;
      // Don't show tasks the current user created
      if (t.createdBy == uid) return false;
      final response = t.studentResponses[uid];
      if (response == null) return false;
      if (response.acknowledged) return false;
      // Only include if deadline hasn't passed
      if (t.deadline != null && _isOverdue(t)) return false;
      return true;
    }).toList();
  }

  List<Task> _tasksCreatedToday() {
    final uid = _userId;
    if (uid == null) return [];
    if (_userRole != 'faculty') return [];
    return _tasks.where((t) {
      if (!t.isActive) return false;
      if (t.createdBy != uid) return false;
      return _isToday(t.createdAt);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ───── Drawer ─────

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            color: AppColors.drawerHeader,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      backgroundImage:
                          const AssetImage('assets/images/avatar.png'),
                      onBackgroundImageError: (_, _) {},
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.today,
                  label: 'Today',
                  isActive: true,
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Channels',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatsScreen(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.description_outlined,
                  label: 'Updates & Tasks',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UpdatesTasksScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.description_outlined,
                  label: 'Policies',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _DrawerItem(
                  icon: Icons.logout,
                  label: 'Log out',
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/roleSelection',
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _userName {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) return '';
    final namePart = email.split('@').first;
    return namePart
        .split('.')
        .map((part) =>
            part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  // ───── Build ─────

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          if (_userRole == 'faculty' && _isRevoked) _buildRevokedBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildRevokedBanner() {
    return Container(
      width: double.infinity,
      color: Colors.amber[700],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your account has been restricted. Contact your administrator for assistance.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_tasksLoading && _tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final dueTodayTasks = _dueToday();
    final dueThisWeekTasks = _dueThisWeek();
    final unacknowledgedTasks = _unacknowledged();
    final createdTodayTasks = _tasksCreatedToday();

    final showSection1 = dueTodayTasks.isNotEmpty;
    final showSection2 = dueThisWeekTasks.isNotEmpty;
    final showSection3 = !_everyoneLoading && _everyoneItems.isNotEmpty;
    final showSection4 = !_mentionLoading && _mentionItems.isNotEmpty;
    final showSection5 = unacknowledgedTasks.isNotEmpty;
    final showSection6 = _userRole == 'faculty' && createdTodayTasks.isNotEmpty;

    final allEmpty = !showSection1 &&
        !showSection2 &&
        !showSection3 &&
        !showSection4 &&
        !showSection5 &&
        !showSection6 &&
        !_everyoneLoading &&
        !_mentionLoading;

    if (allEmpty) {
      return _buildFullEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Due Today
          _buildSectionHeader('📋 Due Today'),
          if (_tasksLoading && dueTodayTasks.isEmpty)
            _buildSectionLoading()
          else if (!showSection1)
            _buildSectionEmpty('✅', 'Nothing due today')
          else
            ...dueTodayTasks.map((task) => CompactTaskCard(
                  task: task,
                  groupName: _groupNames[task.chatId] ?? 'Group',
                  deadlineLabel: _isOverdue(task) ? 'Overdue' : 'Due today',
                  deadlineColor: _isOverdue(task)
                      ? AppColors.urgentRed
                      : CompactTaskCard.computeDeadlineColor(task),
                  onTap: () => _openTaskDetail(task.id),
                  trailing: _isOverdue(task)
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.urgentRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('OVERDUE',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        )
                      : null,
                )),
          const SizedBox(height: 20),

          // Section 2: Due This Week
          if (showSection2 || _tasksLoading) ...[
            _buildSectionHeader('📅 Due This Week'),
            if (_tasksLoading && dueThisWeekTasks.isEmpty)
              _buildSectionLoading()
            else
              ...dueThisWeekTasks.map((task) => CompactTaskCard(
                    task: task,
                    groupName: _groupNames[task.chatId] ?? 'Group',
                    deadlineLabel: CompactTaskCard.daysLeftText(task),
                    deadlineColor: CompactTaskCard.computeDeadlineColor(task),
                    onTap: () => _openTaskDetail(task.id),
                  )),
            const SizedBox(height: 20),
          ],

          // Section 3: Active @everyone
          if (showSection3) ...[
            _buildSectionHeader('📢 Active @everyone'),
            ..._everyoneItems.map((item) => EveryoneItem(
                  groupName: item.groupName,
                  messagePreview: item.messagePreview,
                  timeAgo: _timeAgo(item.timestamp),
                  onTap: () => _openGroupChat(item.chatId, item.groupName),
                )),
            const SizedBox(height: 20),
          ],

          // Section 4: @mentioned Today
          if (showSection4) ...[
            _buildSectionHeader('🔔 You Were Mentioned'),
            ..._mentionItems.map((item) => MentionItem(
                  chatName: item.chatName,
                  messagePreview: item.messagePreview,
                  senderName: item.senderName,
                  timeAgo: _timeAgo(item.timestamp),
                  onTap: () =>
                      _openGroupChat(item.chatId, item.chatName),
                )),
            const SizedBox(height: 20),
          ],

          // Section 5: Unacknowledged Tasks
          if (showSection5) ...[
            _buildSectionHeader('⚠️ Needs Acknowledgement'),
            ...unacknowledgedTasks.map((task) => CompactTaskCard(
                  task: task,
                  groupName: _groupNames[task.chatId] ?? 'Group',
                  deadlineLabel: 'Due: ${_formatDate(task.deadline)}',
                  deadlineColor: CompactTaskCard.computeDeadlineColor(task),
                  onTap: () => _openTaskDetail(task.id),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.pendingYellow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('UNACKNOWLEDGED',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                )),
            const SizedBox(height: 20),
          ],

          // Section 6: Faculty — Tasks Created Today
          if (showSection6) ...[
            _buildSectionHeader('📝 You Created Today'),
            ...createdTodayTasks.map((task) => CompactTaskCard(
                  task: task,
                  groupName: _groupNames[task.chatId] ?? 'Group',
                  deadlineLabel: _buildAckSummary(task),
                  deadlineColor: Colors.grey[600]!,
                  onTap: () => _openTaskDetail(task.id),
                  trailing: _buildAckBadge(task),
                )),
            const SizedBox(height: 20),
          ],

          // Section 3+4 loading indicators
          if (_everyoneLoading && _groupNames.isNotEmpty)
            _buildSectionLoading(),
          if (_mentionLoading && _groupNames.isNotEmpty)
            _buildSectionLoading(),
        ],
      ),
    );
  }

  // ───── Section widgets ─────

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSectionLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildSectionEmpty(String icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎉', style: TextStyle(fontSize: 56, color: Colors.grey[400])),
            const SizedBox(height: 16),
            Text(
              "You're all caught up!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tasks due, no mentions, nothing pending.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ───── Helpers ─────

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'No deadline';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _buildAckSummary(Task task) {
    final total = task.studentResponses.length;
    if (total == 0) return 'No targets';
    final ackCount =
        task.studentResponses.values.where((r) => r.acknowledged).length;
    return '$ackCount / $total acknowledged';
  }

  Widget _buildAckBadge(Task task) {
    final total = task.studentResponses.length;
    if (total == 0) return const SizedBox.shrink();
    final ackCount =
        task.studentResponses.values.where((r) => r.acknowledged).length;
    if (ackCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey[300]!,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('No acks',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600])),
      );
    }
    if (ackCount >= total) {
      return const Text('✅',
          style: TextStyle(fontSize: 16));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$ackCount/$total',
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.primary)),
    );
  }

  void _openTaskDetail(String taskId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(taskId: taskId),
      ),
    );
  }

  void _openGroupChat(String chatId, String groupName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(
          chat: ChatItem(
            id: chatId,
            name: groupName,
            lastMessage: '',
            time: '',
            type: ChatType.groupChat,
          ),
        ),
      ),
    );
  }
}

// ───── Drawer Item ─────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppColors.primary : AppColors.textSecondary,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          color: isActive ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      tileColor: isActive ? AppColors.primary.withValues(alpha: 0.06) : null,
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}