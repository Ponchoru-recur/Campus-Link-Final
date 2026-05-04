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

/// The main Chats / Channels screen shown after login.
/// Contains the navigation drawer and the list of group chats + instructor DMs.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<ChatItem> _groupChats = [];
  bool _isCreatingGroup = false;
  StreamSubscription<QuerySnapshot>? _groupChatsSubscription;
  String _userRole = 'student';
  bool _isDisposed = false;

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
    _fetchUserRole();
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
            return ChatItem(
              id: doc.id,
              name: doc['name'] ?? '',
              lastMessage: doc['lastMessage'] ?? '',
              time: doc['time'] ?? 'Now',
              type: ChatType.groupChat,
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

  @override
  void dispose() {
    _isDisposed = true;
    _groupChatsSubscription?.cancel();
    super.dispose();
  }


  void _openGroupChat(ChatItem chat) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupChatScreen(chat: chat)),
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

      // Delete all messages in the subcollection
      final messagesSnapshot = await groupChatRef.collection('messages').get();

      // Process in batches of 500 (Firestore batch limit)
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

      // Delete the group chat document
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

  // ─────────────────────────────────────────────
  // Drawer
  // ─────────────────────────────────────────────
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
                          'assets/images/avatar.png'), // Replace with actual image
                      onBackgroundImageError: (_, _) {},
                      child: const Icon(Icons.person,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    // "?" help button placeholder
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

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Chats',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        actions: [
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
      body: ListView(
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
          // ── Divider ──
          const Divider(height: 1, color: AppColors.divider),
          // ── Create Group Chat Button (Faculty only) ──
          if (_userRole == 'faculty') CreateGroupChatButton(onTap: _onCreateGroupChat),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Drawer Item
// ─────────────────────────────────────────────
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

