import 'package:flutter/material.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_item.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/group_chat_tile.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/instructor_chat_tile.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/group_chat_screen.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/instructor_chat_screen.dart';

/// The main Chats / Channels screen shown after login.
/// Contains the navigation drawer and the list of group chats + instructor DMs.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  // ── Sample Data ── Replace with real data source / API calls later
  final List<ChatItem> _groupChats = const [
    ChatItem(
      id: 'g1',
      name: 'ITE16 - NO1',
      lastMessage: 'Welcome to the group!',
      time: '9:30 AM',
      type: ChatType.groupChat,
    ),
    ChatItem(
      id: 'g2',
      name: 'ITE14 - FJ1',
      lastMessage: "Don't forget the deadline",
      time: '9:15 AM',
      type: ChatType.groupChat,
      unreadCount: 2,
    ),
    ChatItem(
      id: 'g3',
      name: 'CSC - 103',
      lastMessage: 'Meeting at 2pm tomorrow',
      time: '8:45 AM',
      type: ChatType.groupChat,
    ),
    ChatItem(
      id: 'g4',
      name: 'CSC - 104',
      lastMessage: 'Check the new assignment',
      time: '8:30 AM',
      type: ChatType.groupChat,
      unreadCount: 1,
    ),
    ChatItem(
      id: 'g5',
      name: 'PATFIT4 - A12',
      lastMessage: 'See you all next week',
      time: 'Yesterday',
      type: ChatType.groupChat,
    ),
    ChatItem(
      id: 'g6',
      name: 'CSC106 - BCG1',
      lastMessage: 'Great work everyone!',
      time: 'Yesterday',
      type: ChatType.groupChat,
    ),
  ];

  final List<ChatItem> _instructorChats = const [
    ChatItem(
      id: 'i1',
      name: 'Prof. Maria Santos',
      lastMessage: 'Your midterm exam is scheduled for next week',
      time: '10:30 AM',
      type: ChatType.instructor,
      unreadCount: 1,
    ),
    ChatItem(
      id: 'i2',
      name: 'Dr. John Rivera',
      lastMessage: 'Please review the lecture notes I sent',
      time: '9:50 AM',
      type: ChatType.instructor,
    ),
  ];

  void _openGroupChat(ChatItem chat) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupChatScreen(chat: chat)),
    );
  }

  void _openInstructorChat(ChatItem chat) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InstructorChatScreen(chat: chat)),
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
                const Text(
                  'Sam Varela',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'sam.varela@carsu.edu.ph',
                  style: TextStyle(
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
                    // TODO: navigate to Settings
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
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: handle logout
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
      ),
      drawer: _buildDrawer(),
      body: ListView(
        children: [
          // ── Group Chats ──
          ..._groupChats.map(
            (chat) => GroupChatTile(
              chat: chat,
              onTap: () => _openGroupChat(chat),
            ),
          ),
          // ── Divider ──
          const Divider(height: 1, color: AppColors.divider),
          // ── Instructor DMs ──
          ..._instructorChats.map(
            (chat) => InstructorChatTile(
              chat: chat,
              onTap: () => _openInstructorChat(chat),
            ),
          ),
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
