import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/chat_item.dart';
import 'package:luminescence/themes/app_colors.dart';

enum AnnouncementPriority { standard, urgent }

class AnnouncementDialog extends StatefulWidget {
  final List<ChatItem> groupChats;

  const AnnouncementDialog({super.key, required this.groupChats});

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  final _messageController = TextEditingController();
  final Set<String> _selectedGroupIds = {};
  AnnouncementPriority _priority = AnnouncementPriority.standard;
  bool _isSubmitting = false;

  bool get _selectAll => _selectedGroupIds.length == widget.groupChats.length;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedGroupIds.clear();
      } else {
        _selectedGroupIds.addAll(widget.groupChats.map((c) => c.id));
      }
    });
  }

  Future<void> _submitAnnouncement() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an announcement message')),
      );
      return;
    }
    if (_selectedGroupIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one group')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final senderId = user?.uid ?? 'unknown';
      final senderName = user?.displayName ?? 'Admin';
      final priorityStr =
          _priority == AnnouncementPriority.urgent ? 'urgent' : 'standard';

      final announcementRef = await FirebaseFirestore.instance
          .collection('announcements')
          .add({
            'message': message,
            'priority': priorityStr,
            'senderId': senderId,
            'senderName': senderName,
            'timestamp': FieldValue.serverTimestamp(),
            'selectedGroupIds': _selectedGroupIds.toList(),
          });

      final batch = FirebaseFirestore.instance.batch();

      for (final groupId in _selectedGroupIds) {
        final msgRef = FirebaseFirestore.instance
            .collection('groupChats')
            .doc(groupId)
            .collection('messages')
            .doc();

        batch.set(msgRef, {
          'id': msgRef.id,
          'type': 'announcement',
          'text': message,
          'priority': priorityStr,
          'senderId': senderId,
          'senderName': senderName,
          'timestamp': FieldValue.serverTimestamp(),
          'isSystemMessage': true,
          'announcementId': announcementRef.id,
        });

        final membersSnap =
            await FirebaseFirestore.instance
                .collection('groupChats')
                .doc(groupId)
                .collection('members')
                .get();

        for (final memberDoc in membersSnap.docs) {
          final userId = memberDoc.id;
          final updateRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('updates')
              .doc();

          batch.set(updateRef, {
            'id': updateRef.id,
            'type': 'announcement',
            'message': message,
            'priority': priorityStr,
            'announcementId': announcementRef.id,
            'senderName': senderName,
            'groupId': groupId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }

      await batch.commit();

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _priority == AnnouncementPriority.urgent;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.campaign,
            color: isUrgent ? AppColors.urgentRed : AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text('Create Announcement'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Message field
              TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Enter announcement message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 16),

              // Priority selector
              const Text(
                'Priority',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PriorityChip(
                      label: 'Standard',
                      icon: Icons.info_outline,
                      color: AppColors.standardBlue,
                      selected: !isUrgent,
                      onTap:
                          () => setState(
                            () => _priority = AnnouncementPriority.standard,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PriorityChip(
                      label: 'Urgent',
                      icon: Icons.priority_high,
                      color: AppColors.urgentRed,
                      selected: isUrgent,
                      onTap:
                          () => setState(
                            () => _priority = AnnouncementPriority.urgent,
                          ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Group selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Groups',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleSelectAll,
                    child: Text(_selectAll ? 'Deselect All' : 'Select All'),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.groupChats.length,
                  itemBuilder: (context, index) {
                    final chat = widget.groupChats[index];
                    final isSelected = _selectedGroupIds.contains(chat.id);

                    return CheckboxListTile(
                      dense: true,
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedGroupIds.add(chat.id);
                          } else {
                            _selectedGroupIds.remove(chat.id);
                          }
                        });
                      },
                      title: Text(
                        chat.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitAnnouncement,
          style: ElevatedButton.styleFrom(
            backgroundColor: isUrgent ? AppColors.urgentRed : AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text('Announce'),
        ),
      ],
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 31) : Colors.transparent,
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
