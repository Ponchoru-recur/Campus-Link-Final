import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_item.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/group_chat_tile.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/group_chat_screen.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/announcement_button/announcement_dialog.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/create_group_chat_button.dart';
import 'package:luminescence/pages/home_hamburger/settings_screen/settings_screen.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_item.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_tile.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/individual_chat_screen.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chats_refresh.dart';

/// The main Chats / Channels screen shown after login.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<ChatItem> _groupChats = [];
  List<DirectMessageItem> _directMessages = [];
  bool _isCreatingGroup = false;
  StreamSubscription<QuerySnapshot>? _groupChatsSubscription;
  StreamSubscription<QuerySnapshot>? _directMessagesSubscription;
  String _userRole = 'student';
  bool _isDisposed = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _cachedUsers = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<DirectMessageItem> _archivedDMs = [];
  bool _showArchived = false;

  String get _userEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  String get _userName {
    final email = _userEmail;
    if (email.isEmpty) return '';
    final namePart = email.split('@').first;
    return namePart
        .split('.')
        .map((part) => part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    _setupGroupChatsStream();
    _setupDirectMessagesStream();
    _fetchUserRole();
    _fetchAndCacheUsers();
    _searchController.addListener(() {
      _filterSearch(_searchController.text);
    });
  }

  void _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isDisposed) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (_isDisposed) return;
      final role = doc.exists ? (doc['role'] ?? 'student') : 'student';
      if (mounted && !_isDisposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed) {
            setState(() {
              _userRole = role;
            });
          }
        });
      }
    } catch (e) {
      if (!_isDisposed) {
        debugPrint('Error fetching user role: $e');
      }
    }
  }

  Future<void> _fetchAndCacheUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      if (_isDisposed || !mounted) return;
      setState(() {
        _cachedUsers = snapshot.docs.map((doc) {
          final data = doc.data();
          final email = data['email'] ?? '';
          final namePart = email.split('@').first;
          final displayName = namePart
              .split('.')
              .map((part) => part.isEmpty
                  ? part
                  : part[0].toUpperCase() + part.substring(1))
              .join(' ');
          return {
            'uid': doc.id,
            'email': email,
            'role': data['role'] ?? 'student',
            'displayName': displayName,
          };
        }).toList();
      });
    } catch (e) {
      if (!_isDisposed) {
        debugPrint('Error fetching users: $e');
      }
    }
  }

  Future<void> _refreshData() async {
    final refresher = ChatsRefresher(
      firestore: FirebaseFirestore.instance,
      onRoleFetched: (role) {
        if (mounted && !_isDisposed) {
          setState(() => _userRole = role);
        }
      },
      onUsersFetched: (users) {
        if (mounted && !_isDisposed) {
          setState(() => _cachedUsers = users);
        }
      },
      directMessages: _directMessages,
      currentUserId: FirebaseAuth.instance.currentUser?.uid,
    );
    await refresher.refresh();
  }

  void _filterSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    final emailRegex = RegExp(r'^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$');
    final existingContactUids = _directMessages
        .map((dm) => dm.otherParticipantUid)
        .toSet();

    setState(() {
      _searchResults = _cachedUsers.where((user) {
        if (!emailRegex.hasMatch(user['email'])) {
          return false;
        }
        if (existingContactUids.contains(user['uid'])) {
          return false;
        }
        final email = (user['email'] ?? '').toLowerCase();
        final name = (user['displayName'] ?? '').toLowerCase();
        return email.contains(lowerQuery) || name.contains(lowerQuery);
      }).take(50).toList();
    });
  }

  void _setupGroupChatsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isDisposed) return;

    _groupChatsSubscription = FirebaseFirestore.instance
        .collection('group_chats')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        if (_isDisposed || !mounted) return;
        setState(() {
          _groupChats = snapshot.docs.map((doc) {
            final data = doc.data();
            int unreadCount = 0;
            final unreadData = data['unreadCount'];
            if (unreadData is Map) {
              unreadCount = unreadData[user.uid] ?? 0;
            } else if (unreadData is int) {
              unreadCount = unreadData;
            }
            return ChatItem(
              id: doc.id,
              name: data['name'] ?? '',
              lastMessage: data['lastMessage'] ?? '',
              time: data['time'] ?? 'Now',
              type: ChatType.groupChat,
              unreadCount: unreadCount,
            );
          }).toList();
        });
      },
      onError: (e) {
        if (!_isDisposed) {
          debugPrint('Error in group chats stream: $e');
        }
      },
    );
  }

  void _setupDirectMessagesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isDisposed) return;

    _directMessagesSubscription = FirebaseFirestore.instance
        .collection('direct_messages')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        if (_isDisposed || !mounted) return;
        final allDMs = snapshot.docs.map((doc) {
          return DirectMessageItem.fromFirestore(doc, user.uid);
        }).toList();

        setState(() {
          _directMessages = allDMs.where((dm) => !dm.isArchivedByMe).toList();
          _archivedDMs = allDMs.where((dm) => dm.isArchivedByMe).toList();
        });
      },
      onError: (e) {
        if (!_isDisposed) {
          debugPrint('Error in DM stream: $e');
        }
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _groupChatsSubscription?.cancel();
    _directMessagesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }


  void _openGroupChat(ChatItem chat) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupChatScreen(chat: chat)),
    );
  }

  void _openDirectMessage(DirectMessageItem chat) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IndividualChatScreen(chat: chat)),
    );
  }

  Future<void> _confirmAndDeleteGroupChat(ChatItem chat) async {
    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Group Chat'),
        content: Text('Are you sure you want to delete "${chat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.urgentRed),
            ),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;
    if (!mounted) return;

    final bool? secondConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
          'This action is permanent and cannot be undone. '
          'All messages in this group chat will also be deleted. '
          'Are you really sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Yes, Delete Permanently',
              style: TextStyle(color: AppColors.urgentRed),
            ),
          ),
        ],
      ),
    );

    if (secondConfirm == true) {
      await _deleteGroupChat(chat);
    }
  }

  Future<void> _deleteGroupChat(ChatItem chat) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final groupChatRef = firestore.collection('group_chats').doc(chat.id);

      final messagesSnapshot = await groupChatRef.collection('messages').get();

      const batchLimit = 500;
      for (int i = 0; i < messagesSnapshot.docs.length; i += batchLimit) {
        final batch = firestore.batch();
        final end = (i + batchLimit < messagesSnapshot.docs.length)
            ? i + batchLimit
            : messagesSnapshot.docs.length;

        for (int j = i; j < end; j++) {
          batch.delete(messagesSnapshot.docs[j].reference);
        }

        await batch.commit();
      }

      await groupChatRef.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${chat.name} has been deleted'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete group chat: $e'),
            backgroundColor: AppColors.urgentRed,
          ),
        );
      }
    }
  }

  void _onCreateGroupChat() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Group Chat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Group name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isCreatingGroup
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _isCreatingGroup
                  ? null
                  : () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;

                      setDialogState(() => _isCreatingGroup = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('group_chats')
                              .add({
                            'name': name,
                            'lastMessage': '',
                            'time': 'Now',
                            'type': 'groupChat',
                            'createdBy': user.uid,
                            'members': [user.uid],
                            'unreadCount': 0,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        }
                        if (mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to create group: $e')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isCreatingGroup = false);
                        }
                      }
                    },
              child: _isCreatingGroup
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // Archive Methods
  // ─────────────────────────────────────

  Future<void> _archiveDM(DirectMessageItem dm) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(dm.id)
          .update({
        'archivedBy': FieldValue.arrayUnion([user.uid]),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive: $e')),
        );
      }
    }
  }

  Future<void> _unarchiveDM(DirectMessageItem dm) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('direct_messages')
          .doc(dm.id)
          .update({
        'archivedBy': FieldValue.arrayRemove([user.uid]),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unarchive: $e')),
        );
      }
    }
  }

  Future<void> _showArchiveDialog(DirectMessageItem dm, {required bool isArchived}) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isArchived ? 'Unarchive Chat' : 'Archive Chat'),
        content: Text(
          isArchived
              ? 'Move this conversation back to your active messages?'
              : 'Archive this conversation? It will be moved to the Archived section.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
                dialogContext, isArchived ? 'unarchive' : 'archive'),
            child: Text(
              isArchived ? 'Unarchive' : 'Archive',
              style: TextStyle(
                color: isArchived ? AppColors.primary : AppColors.urgentRed,
              ),
            ),
          ),
        ],
      ),
    );

    if (action == 'archive') {
      await _archiveDM(dm);
    } else if (action == 'unarchive') {
      await _unarchiveDM(dm);
    }
  }

  // ─────────────────────────────────────
  // Archived Header Widget
  // ─────────────────────────────────────

  Widget _buildArchivedHeader() {
    if (_archivedDMs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _showArchived = !_showArchived;
          });
        },
        child: Row(
          children: [
            Text(
              'Archived (${_archivedDMs.length})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _showArchived ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  // Drawer
  // ─────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Header
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
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: const AssetImage(
                          'assets/images/avatar.png'),
                      onBackgroundImageError: (_, _) {},
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.question_mark,
                          color: Colors.white, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        _userRole[0].toUpperCase() + _userRole.substring(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _userEmail,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: navigate to Profile screen
                  },
                ),
                _DrawerItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Channels',
                  isActive: true,
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.description_outlined,
                  label: 'Updates & Tasks',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: navigate to Updates & Tasks
                  },
                ),
                _DrawerItem(
                  icon: Icons.campaign_outlined,
                  label: 'Announcements',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: navigate to Announcements
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
                    // TODO: navigate to Policies
                  },
                ),
                _DrawerItem(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: share app
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

  // ─────────────────────────────────────
  // Build
  // ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.15),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              )
            : const Text(
                'Chats',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
        elevation: 0,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close Search',
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _isSearching = false;
                  _searchResults.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search Contacts',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.send_outlined),
              tooltip: 'Create Announcement',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AnnouncementDialog(groupChats: _groupChats),
                );
              },
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ── Group Chats ──
            ..._groupChats.map(
              (chat) => GroupChatTile(
                chat: chat,
                onTap: () => _openGroupChat(chat),
                isFaculty: _userRole == 'faculty',
                onDelete: () => _confirmAndDeleteGroupChat(chat),
              ),
            ),
            // ── Create Group Chat Button (Faculty only) ──
            if (_userRole == 'faculty' && !_isSearching)
              CreateGroupChatButton(onTap: _onCreateGroupChat),
            // ── Divider ──
            const Divider(height: 1, color: AppColors.divider),
            // ── Direct Messages Header ──
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Direct Messages',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // ── Direct Messages List ──
            ..._directMessages.map(
              (dm) => DirectMessageTile(
                chat: dm,
                onTap: () => _openDirectMessage(dm),
                onLongPress: () => _showArchiveDialog(dm, isArchived: false),
              ),
            ),
            if (_directMessages.isEmpty && !_isSearching)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No direct messages yet.\nSearch and add contacts to start chatting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            // ── Archived Header ──
            _buildArchivedHeader(),
            // ── Archived DMs List ──
            if (_showArchived)
              ..._archivedDMs.map(
                (dm) => DirectMessageTile(
                  chat: dm,
                  onTap: () => _openDirectMessage(dm),
                  isArchived: true,
                  onLongPress: () => _showArchiveDialog(dm, isArchived: true),
                ),
              ),
            // ── Search Results (shown when searching) ──
            if (_isSearching) ...[
              const Divider(height: 1, color: AppColors.divider),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Search Results',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No users found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ..._searchResults.map(
                (user) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      (user['displayName'] as String).isNotEmpty
                          ? (user['displayName'] as String)[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    user['displayName'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    user['email'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (user['role'] == 'faculty'
                              ? AppColors.instructorPurple
                              : AppColors.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (user['role'] as String?)?.toUpperCase() ?? 'STUDENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: user['role'] == 'faculty'
                            ? AppColors.instructorPurple
                            : AppColors.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  onTap: () => _addContact(user),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _generateDmDocId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _addContact(Map<String, dynamic> userData) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid == userData['uid']) return;

    final dmDocId = _generateDmDocId(currentUid, userData['uid']);
    final dmRef = FirebaseFirestore.instance.collection('direct_messages').doc(dmDocId);
    final doc = await dmRef.get();

    if (!doc.exists) {
      String currentUserRole = 'student';
      try {
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();
        currentUserRole = currentUserDoc.exists
            ? (currentUserDoc.data()?['role'] ?? 'student')
            : 'student';
      } catch (e) {
        debugPrint('Error fetching current user role: $e');
      }

      await dmRef.set({
        'members': [currentUid, userData['uid']],
        'unreadCount': {currentUid: 0, userData['uid']: 0},
        'lastMessage': '',
        'time': 'Now',
        'createdAt': Timestamp.now(),
        'participantRoles': {
          currentUid: currentUserRole,
          userData['uid']: userData['role'] ?? 'student',
        },
        'participantNames': {
          currentUid: _userName,
          userData['uid']: userData['displayName'] ?? '',
        },
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Contact added'),
        backgroundColor: AppColors.successGreen,
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IndividualChatScreen(
          otherUid: userData['uid'],
          otherName: userData['displayName'] ?? '',
          otherEmail: userData['email'] ?? '',
          otherRole: userData['role'] ?? 'student',
          chatId: dmDocId,
        ),
      ),
    );

    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults.clear();
    });
  }
}

// ─────────────────────────────────────
// Drawer Item
// ─────────────────────────────────────
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
      tileColor: isActive ? AppColors.primary.withOpacity(0.06) : null,
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}
