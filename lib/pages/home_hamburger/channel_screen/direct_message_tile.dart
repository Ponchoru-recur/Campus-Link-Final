import 'package:flutter/material.dart';
import 'package:luminescence/themes/app_colors.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/direct_message_item.dart';

/// A list tile for displaying a direct message conversation.
class DirectMessageTile extends StatelessWidget {
  final DirectMessageItem chat;
  final VoidCallback onTap;

  const DirectMessageTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.isArchived = false,
    this.isLocallyUnread = false,
    this.onLongPress,
    this.onMarkUnread,
  });

  final bool isArchived;
  final bool isLocallyUnread;
  final VoidCallback? onLongPress;
  final VoidCallback? onMarkUnread;

  @override
  Widget build(BuildContext context) {
    final isFaculty = chat.otherParticipantRole == 'faculty';
    final effectiveUnread = chat.unreadCount > 0 || isLocallyUnread;
    final avatarBg = isFaculty
        ? AppColors.instructorPurple.withValues(alpha: 0.15)
        : Colors.grey[400]!.withValues(alpha: 0.15);
    final iconColor = isFaculty ? AppColors.instructorPurple : Colors.grey[600]!;
    final unreadColor = isFaculty ? AppColors.instructorPurple : Colors.grey[600]!;

    return Container(
      decoration: BoxDecoration(
        color: isArchived ? Colors.grey[100] : null,
        border: isFaculty
            ? const Border(
                left: BorderSide(
                  color: AppColors.instructorPurple,
                  width: 3,
                ),
              )
            : null,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarBg,
          child: Icon(
            Icons.person,
            color: iconColor,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                chat.otherParticipantName,
                style: TextStyle(
                  fontWeight: effectiveUnread ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 15,
                  color: effectiveUnread ? AppColors.primary : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isFaculty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.instructorPurple,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Instructor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          chat.lastMessage,
          style: TextStyle(
            fontSize: 13,
            fontWeight: effectiveUnread ? FontWeight.w600 : FontWeight.normal,
            color: effectiveUnread ? AppColors.primary : AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              chat.time,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            if (effectiveUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: unreadColor,
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
        ),
        onTap: onTap,
        onLongPress: () => _showPopupMenu(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
      ),
    );
  }

  void _showPopupMenu(BuildContext context) {
    final effectiveUnread = chat.unreadCount > 0 || isLocallyUnread;
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              effectiveUnread ? Icons.mark_email_read : Icons.mark_email_unread,
              color: AppColors.primary,
            ),
            title: Text(
              effectiveUnread ? 'Mark as read' : 'Mark as unread',
            ),
            onTap: () {
              Navigator.pop(bottomSheetContext);
              onMarkUnread?.call();
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              isArchived ? Icons.unarchive : Icons.archive,
              color: isArchived ? AppColors.primary : AppColors.urgentRed,
            ),
            title: Text(
              isArchived ? 'Unarchive' : 'Archive',
              style: TextStyle(
                color: isArchived ? null : AppColors.urgentRed,
              ),
            ),
            onTap: () {
              Navigator.pop(bottomSheetContext);
              onLongPress?.call();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
