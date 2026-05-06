import 'package:flutter/material.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_item.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_avatars.dart';

/// A single tile for a group chat in the Chats list.
class GroupChatTile extends StatelessWidget {
  final ChatItem chat;
  final VoidCallback onTap;
  final bool isFaculty;
  final VoidCallback? onDelete;
  final bool isLocallyUnread;
  final VoidCallback? onMarkUnread;

  const GroupChatTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.isFaculty = false,
    this.onDelete,
    this.isLocallyUnread = false,
    this.onMarkUnread,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUnread = chat.unreadCount > 0 || isLocallyUnread;
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showPopupMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const GroupChatAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.name,
                    style: TextStyle(
                      fontWeight: effectiveUnread ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 15,
                      color: effectiveUnread ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chat.lastMessage,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: effectiveUnread ? FontWeight.w600 : FontWeight.normal,
                      color: effectiveUnread ? AppColors.primary : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat.time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (effectiveUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.unreadBadge,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${isLocallyUnread && chat.unreadCount == 0 ? 1 : chat.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPopupMenu(BuildContext context) {
    final isUnread = chat.unreadCount > 0 || isLocallyUnread;
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              isUnread ? Icons.mark_email_read : Icons.mark_email_unread,
              color: AppColors.primary,
            ),
            title: Text(
              isUnread ? 'Mark as read' : 'Mark as unread',
            ),
            onTap: () {
              Navigator.pop(bottomSheetContext);
              onMarkUnread?.call();
            },
          ),
          if (isFaculty) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete, color: AppColors.urgentRed),
              title: Text(
                'Delete',
                style: TextStyle(color: AppColors.urgentRed),
              ),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                onDelete?.call();
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
