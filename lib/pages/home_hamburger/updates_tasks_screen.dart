import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:luminescence/models/task.dart';
import 'package:luminescence/services/task_service.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/widgets/acknowledge_button.dart';
import 'package:luminescence/widgets/acknowledgment_status_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

/// Updates & Tasks screen showing all tasks for the current user.
/// Tasks are informational only - no submissions allowed.
class UpdatesTasksScreen extends StatefulWidget {
  const UpdatesTasksScreen({super.key});

  @override
  State<UpdatesTasksScreen> createState() => _UpdatesTasksScreenState();
}

class _UpdatesTasksScreenState extends State<UpdatesTasksScreen> {
  StreamSubscription<QuerySnapshot>? _tasksSubscription;
  final List<Task> _tasks = [];
  bool _isLoading = true;
  String _userRole = 'student';
  String? _userId;
  final _taskService = TaskService();

  // --- Search, Filter, Sort state ---
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _seenSent = {};
  String _searchQuery = '';
  String _activeFilter = 'All'; // All | Completed | Deleted | Due Soon | Overdue
  String _activeSort = 'Newest First';

  // Sort options
  static const List<String> _sortOptions = [
    'Newest First',
    'Oldest First',
    'Due Date',
    'Alphabetical',
  ];

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _fetchUserRole();
    _setupTasksStream();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _userRole = doc.exists ? (doc['role'] ?? 'student') : 'student';
        });
      }
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }
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
        _isLoading = false;
      });
    }, onError: (e) {
      debugPrint('Error in tasks stream: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({'isActive': false});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreTask(Task task) async {
    try {
      await _taskService.restoreTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task restored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _ignoreTask(Task task) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({
        'ignoredBy': FieldValue.arrayUnion([uid]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task ignored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleTaskDone(Task task) async {
    final uid = _userId;
    if (uid == null) return;
    final isDone = task.doneByUids.contains(uid);
    try {
      if (isDone) {
        await _taskService.unmarkTaskDone(task.id, uid);
      } else {
        await _taskService.markTaskDone(task.id, uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _launchLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return;
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No app available to open this link'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'No deadline';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  bool _isOverdue(Task task) {
    if (task.deadline == null) return false;
    if (!task.isActive) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final deadlineDay = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
    return deadlineDay.isBefore(today);
  }

  bool _isDueSoon(Task task) {
    if (task.deadline == null) return false;
    if (!task.isActive) return false;
    if (_isOverdue(task)) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final deadlineDay = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
    final daysLeft = deadlineDay.difference(today).inDays;
    return daysLeft >= 0 && daysLeft <= 3;
  }

  Color _getDeadlineColor(Task task) {
    if (task.deadline == null) return Colors.grey[600]!;
    if (!task.isActive) return Colors.grey[500]!;

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final deadlineDay = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
    final daysLeft = deadlineDay.difference(today).inDays;

    final green = task.greenThresholdDays ?? TaskService.defaultGreenDays;
    final yellow = task.yellowThresholdDays ?? TaskService.defaultYellowDays;
    final red = task.redThresholdDays ?? TaskService.defaultRedDays;

    if (daysLeft >= green) return AppColors.doneGreen;
    if (daysLeft >= yellow) return AppColors.pendingYellow;
    if (daysLeft >= red) return AppColors.urgentRed;
    return AppColors.urgentRed;
  }

  // --- Filtering ---
  List<Task> _getFilteredTasks() {
    final uid = _userId;
    List<Task> result;

    // Base category: active (not done), done, or deleted
    switch (_activeFilter) {
      case 'Completed':
        result = _tasks.where((t) => t.isActive && uid != null && t.doneByUids.contains(uid)).toList();
        break;
      case 'Deleted':
        result = _tasks.where((t) => !t.isActive).toList();
        break;
      case 'Due Soon':
        result = _tasks.where((t) {
          if (t.deadline == null || !t.isActive) return false;
          if (uid != null && t.doneByUids.contains(uid)) return false;
          return _isDueSoon(t);
        }).toList();
        break;
      case 'Overdue':
        result = _tasks.where((t) {
          if (t.deadline == null || !t.isActive) return false;
          if (uid != null && t.doneByUids.contains(uid)) return false;
          return _isOverdue(t);
        }).toList();
        break;
      default: // 'All'
        result = List.from(_tasks);
        break;
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((t) {
        return t.title.toLowerCase().contains(_searchQuery) ||
            t.description.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return result;
  }

  // --- Sorting ---
  List<Task> _sortTasks(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);
    switch (_activeSort) {
      case 'Oldest First':
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'Due Date':
        sorted.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          return a.deadline!.compareTo(b.deadline!);
        });
        break;
      case 'Alphabetical':
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      default: // 'Newest First'
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return sorted;
  }

  // --- Section extraction ---
  List<Task> _getSectionTasks(List<Task> filtered, bool isDeleted, bool isDone) {
    final uid = _userId;
    return filtered.where((t) {
      if (isDeleted) return !t.isActive;
      if (isDone) return t.isActive && uid != null && t.doneByUids.contains(uid);
      return t.isActive && (uid == null || !t.doneByUids.contains(uid));
    }).toList();
  }

  // --- Search highlight ---
  Widget _highlightedText(String text, {TextStyle? style}) {
    if (_searchQuery.isEmpty) {
      return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final lower = text.toLowerCase();
    final query = _searchQuery;
    final idx = lower.indexOf(query);
    if (idx < 0) {
      return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style ?? const TextStyle(fontSize: 14),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: (style ?? const TextStyle()).copyWith(
              backgroundColor: AppColors.doneGreen.withValues(alpha: 0.25),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }

  // --- Filter chips config ---
  static const List<_FilterChipData> _filterChips = [
    _FilterChipData('All', Icons.all_inclusive),
    _FilterChipData('Completed', Icons.check_circle_outline),
    _FilterChipData('Deleted', Icons.delete_outline),
    _FilterChipData('Due Soon', Icons.schedule),
    _FilterChipData('Overdue', Icons.warning_amber),
  ];

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Trigger seen flag if not already marked.
  void _maybeMarkSeen(Task task) {
    final uid = _userId;
    if (uid == null) return;
    final key = '${task.id}:$uid';
    if (_seenSent.contains(key)) return;
    final response = task.studentResponses[uid];
    if (response != null && response.seen) return;
    _seenSent.add(key);
    _taskService.setSeen(task.id, uid);
  }

  /// Open faculty acknowledgment status bottom sheet.
  void _openAckStatusSheet(Task task) {
    if (_userRole != 'faculty' || task.createdBy != _userId) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AcknowledgmentStatusSheet(
        task: task,
        chatId: task.chatId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Updates & Tasks',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No tasks yet',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Tasks will appear here when faculty create them',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      );
    }

    final allFiltered = _sortTasks(_getFilteredTasks());
    final activeTasks = _getSectionTasks(allFiltered, false, false);
    final doneTasks = _getSectionTasks(allFiltered, false, true);
    final deletedTasks = _getSectionTasks(allFiltered, true, false);

    final showActive = _activeFilter == 'All' && activeTasks.isNotEmpty;
    final showDone = doneTasks.isNotEmpty;
    final showDeleted = deletedTasks.isNotEmpty;

    final nothingToShow = !showActive && !showDone && !showDeleted;

    return Column(
      children: [
        // Search bar
        _buildSearchBar(),
        // Filter chips + sort
        _buildFilterRow(),
        // Subtle divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, color: Colors.grey[200]),
        ),
        // List
        Expanded(
          child: nothingToShow
              ? _buildEmptyState()
              : _buildTaskList(activeTasks, doneTasks, deletedTasks, showActive, showDone, showDeleted),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search tasks...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontSize: 14),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildFilterRow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Filter chips row
        Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: _filterChips.map((chip) {
                final isActive = _activeFilter == chip.label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      chip.label,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : Colors.grey[700],
                      ),
                    ),
                    selected: isActive,
                    onSelected: (_) => setState(() => _activeFilter = chip.label),
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.grey[50],
                    side: BorderSide(
                      color: isActive ? AppColors.primary : Colors.grey[300]!,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Sort row
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _showSortSheet_(context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_vert, size: 18, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _activeSort,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSortSheet_(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sort by',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ..._sortOptions.map((option) {
                final isSelected = _activeSort == option;
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? AppColors.primary : Colors.grey[400],
                    size: 20,
                  ),
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.primary : Colors.grey[800],
                    ),
                  ),
                  onTap: () {
                    setState(() => _activeSort = option);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No results found',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Try adjusting your search or filters',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(
    List<Task> activeTasks,
    List<Task> doneTasks,
    List<Task> deletedTasks,
    bool showActive,
    bool showDone,
    bool showDeleted,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        // Active tasks section (only in 'All' view)
        if (showActive)
          _AnimatedSection(
            key: ValueKey('active-${activeTasks.length}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                ...activeTasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildTaskCard(task),
                )),
              ],
            ),
          ),

        // Completed section
        if (showDone)
          _AnimatedSection(
            key: ValueKey('done-${doneTasks.length}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  icon: Icons.check_circle,
                  label: 'Completed',
                  count: doneTasks.length,
                  color: AppColors.doneGreen,
                ),
                const SizedBox(height: 4),
                ...doneTasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildTaskCard(task, isDone: true),
                )),
              ],
            ),
          ),

        // Deleted section
        if (showDeleted)
          _AnimatedSection(
            key: ValueKey('deleted-${deletedTasks.length}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildSectionHeader(
                  icon: Icons.delete_outline,
                  label: 'Deleted',
                  count: deletedTasks.length,
                  color: Colors.grey,
                ),
                const SizedBox(height: 4),
                ...deletedTasks.map((task) => _buildSwipeableDeletedCard(task)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeableDeletedCard(Task task) {
    return Dismissible(
      key: ValueKey('restore-${task.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.doneGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.restore, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        _restoreTask(task);
        return true;
      },
      child: _buildTaskCard(task, isDeleted: true),
    );
  }

  Widget _buildTaskCard(Task task, {bool isDone = false, bool isDeleted = false}) {
    final uid = _userId;
    final response = uid != null ? task.studentResponses[uid] : null;
    final isAcknowledged = response?.acknowledged ?? false;
    final isCreator = task.createdBy == _userId;
    final isFaculty = _userRole == 'faculty';
    final overdue = _isOverdue(task);
    final deadlineColor = isDeleted ? Colors.grey[500]! : _getDeadlineColor(task);

    return VisibilityDetector(
      key: ValueKey('task-vis-${task.id}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.8 && !isDeleted && !isDone) {
          _maybeMarkSeen(task);
        }
      },
      child: GestureDetector(
      onTap: isFaculty && task.createdBy == _userId && !isDone && !isDeleted
          ? () => _openAckStatusSheet(task)
          : null,
      onLongPress: isDone || isDeleted
          ? null
          : () {
              if (uid != null) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Mark as done?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _toggleTaskDone(task);
                        },
                        child: const Text('Mark done'),
                      ),
                    ],
                  ),
                );
              }
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDeleted
                  ? Colors.grey[300]!
                  : isDone
                      ? AppColors.doneGreen.withValues(alpha: 0.3)
                      : overdue
                          ? AppColors.urgentRed.withValues(alpha: 0.3)
                          : AppColors.divider,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDeleted
                      ? Colors.grey[100]!
                      : isDone
                          ? AppColors.doneGreen.withValues(alpha: 0.05)
                          : overdue
                              ? AppColors.urgentRed.withValues(alpha: 0.05)
                              : AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDeleted
                            ? Colors.grey[300]
                            : isDone
                                ? AppColors.doneGreen.withValues(alpha: 0.1)
                                : overdue
                                    ? AppColors.urgentRed.withValues(alpha: 0.1)
                                    : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isDeleted ? Icons.delete_outline : isDone ? Icons.check_circle : Icons.assignment,
                        color: isDeleted
                            ? Colors.grey[500]
                            : isDone
                                ? AppColors.doneGreen
                                : overdue
                                    ? AppColors.urgentRed
                                    : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _highlightedText(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: isDone || isDeleted ? TextDecoration.lineThrough : null,
                              color: isDeleted ? Colors.grey[600] : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'By ${task.creatorName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDeleted ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    isDeleted
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[400]!,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('DELETED',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5)),
                          )
                        : overdue && !isDone
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.urgentRed,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('OVERDUE',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5)),
                              )
                            : const SizedBox.shrink(),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _highlightedText(
                      task.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDeleted ? Colors.grey[500]! : AppColors.textPrimary,
                        decoration: isDeleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: deadlineColor),
                        const SizedBox(width: 6),
                        Text(
                          'Due: ${_formatDate(task.deadline)}',
                          style: TextStyle(fontSize: 12, color: deadlineColor),
                        ),
                        const SizedBox(width: 8),
                        if (!isDone && !isDeleted && !overdue)
                          Text(
                            _daysLeftText(task),
                            style: TextStyle(
                                fontSize: 11, color: deadlineColor, fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    if (!isDeleted && task.links.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: task.links.map((link) => InkWell(
                          onTap: () => _launchLink(link.url),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  link.title,
                                  style: const TextStyle(fontSize: 11, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              if (!isDone && !isDeleted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Row(
                    children: [
                      if (isFaculty && isCreator) ...[
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _editTask(task),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _confirmDelete(task),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.urgentRed,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                      if (isFaculty && !isCreator) ...[
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _ignoreTask(task),
                            icon: const Icon(Icons.visibility_off, size: 16),
                            label: const Text('Ignore'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                      if (!isFaculty && uid != null && !isDone && !isDeleted)
                        Expanded(
                          child: AcknowledgeButton(
                            taskId: task.id,
                            uid: uid,
                            isAcknowledged: isAcknowledged,
                            compact: false,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
      );
  }

  String _daysLeftText(Task task) {
    if (task.deadline == null) return '';
    if (!task.isActive) return '';
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final deadlineDay = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
    final daysLeft = deadlineDay.difference(today).inDays;
    if (daysLeft <= 0) return 'Due today';
    if (daysLeft == 1) return '1 day left';
    return '$daysLeft days left';
  }

  Future<void> _editTask(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditTaskScreen(task: task),
      ),
    );
    _tasksSubscription?.cancel();
    _setupTasksStream();
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: const Text(
                'Delete this task for everyone? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.urgentRed),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await _deleteTask(task);
  }
}

/// Wraps a section in an animation that fades+slides on appearance.
class _AnimatedSection extends StatelessWidget {
  final Widget child;

  const _AnimatedSection({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: child,
    );
  }
}

/// Data holder for filter chip definition.
class _FilterChipData {
  final String label;
  final IconData icon;
  const _FilterChipData(this.label, this.icon);
}

// ============================================================
// Inline edit task screen (unchanged from original)
// ============================================================

/// Inline edit task screen for faculty to update task fields.
class _EditTaskScreen extends StatefulWidget {
  final Task task;

  const _EditTaskScreen({required this.task});

  @override
  State<_EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<_EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  DateTime? _deadline;
  bool _isSaving = false;
  final List<TaskLink> _links = [];
  final _taskService = TaskService();

  Future<void> _openLink(TaskLink link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null || !uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid URL: ${link.url}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No app available to open this link'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open link'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description);
    _deadline = widget.task.deadline;
    _links.addAll(widget.task.links);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _deadline = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  Future<void> _addLink() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final result = await showDialog<TaskLink>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Link Name',
                hintText: 'e.g., Course Materials',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              if (name.isEmpty || url.isEmpty) return;
              Navigator.pop(ctx, TaskLink(title: name, url: url));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _links.add(result));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _taskService.updateTask(
        taskId: widget.task.id,
        title: _titleController.text,
        description: _descController.text,
        deadline: _deadline != null
            ? DateFormat('yyyy-MM-ddTHH:mm:ss').format(_deadline!)
            : null,
        clearDeadline: _deadline == null,
        links: _links,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Task updated'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Edit Task',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Task Information
              _EditSectionCard(
                icon: Icons.assignment,
                title: 'Task Information',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: _editInputDecoration(
                        label: 'Task Title',
                        hint: 'Enter task title...',
                        icon: Icons.title,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Title required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 500,
                      decoration: _editInputDecoration(
                        label: 'Description',
                        hint: 'Describe the task...',
                        icon: Icons.description_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Deadline
              _EditSectionCard(
                icon: Icons.calendar_month,
                title: 'Deadline',
                child: InkWell(
                  onTap: _selectDeadline,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.calendar_today,
                              size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _deadline == null
                                    ? 'No deadline set'
                                    : DateFormat('EEEE, MMMM d, y')
                                        .format(_deadline!),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: _deadline == null
                                      ? Colors.grey[500]
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (_deadline != null)
                                Text(
                                  '${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                ),
                            ],
                          ),
                        ),
                        if (_deadline != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _deadline = null),
                            splashRadius: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Links
              _EditSectionCard(
                icon: Icons.link,
                title: 'Attached Links',
                trailing: TextButton.icon(
                  onPressed: _addLink,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Link'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                child: _links.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.link_off,
                                size: 16, color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            Text('No links attached',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 13)),
                          ],
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _links.map((link) {
                          return InkWell(
                            onTap: () => _openLink(link),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link,
                                      size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(link.title,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _links.remove(link)),
                                    child: Icon(Icons.close,
                                        size: 14, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 24),

              // Delete button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Delete Task'),
                        content: const Text(
                            'Delete this task for everyone? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.urgentRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _taskService.deleteTask(widget.task.id);
                      if (!mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete this task'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.urgentRed,
                    side: BorderSide(color: AppColors.urgentRed.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _editInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      counterText: '',
    );
  }
}

class _EditSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _EditSectionCard({
    required this.icon,
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1, indent: 18, endIndent: 18),
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }
}