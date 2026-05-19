import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/themes/app_colors.dart';

/// Read-only view of a faculty member's profile.
/// Shown when tapping on a faculty member in group chats or DMs.
class FacultyProfileViewScreen extends StatefulWidget {
  final String facultyUid;
  final String facultyName;

  const FacultyProfileViewScreen({
    super.key,
    required this.facultyUid,
    required this.facultyName,
  });

  @override
  State<FacultyProfileViewScreen> createState() =>
      _FacultyProfileViewScreenState();
}

class _FacultyProfileViewScreenState extends State<FacultyProfileViewScreen> {
  bool _isLoading = true;
  String? _building;
  String? _office;
  String? _additionalInfo;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.facultyUid)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final data = doc.data();
      final profile = data?['facultyProfile'] as Map<String, dynamic>?;
      _email = data?['email'] ?? '';
      _building = profile?['building'] as String?;
      _office = profile?['office'] as String?;
      _additionalInfo = profile?['additionalInfo'] as String?;
    } catch (e) {
      debugPrint('Error loading faculty profile: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.instructorPurple,
        foregroundColor: Colors.white,
        title: const Text('Faculty Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        AppColors.instructorPurple.withValues(alpha: 0.15),
                    child: Text(
                      widget.facultyName.isNotEmpty
                          ? widget.facultyName[0]
                          : 'F',
                      style: const TextStyle(
                        fontSize: 28,
                        color: AppColors.instructorPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.facultyName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          AppColors.instructorPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Faculty',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.instructorPurple,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_building != null && _building!.isNotEmpty) ...[
                    _InfoTile(
                      icon: Icons.business,
                      label: 'Building',
                      value: _building!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_office != null && _office!.isNotEmpty) ...[
                    _InfoTile(
                      icon: Icons.meeting_room,
                      label: 'Office / Room',
                      value: _office!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_additionalInfo != null &&
                      _additionalInfo!.isNotEmpty) ...[
                    _InfoTile(
                      icon: Icons.info_outline,
                      label: 'Additional Information',
                      value: _additionalInfo!,
                      multiline: true,
                    ),
                  ],
                  if ((_building == null || _building!.isEmpty) &&
                      (_office == null || _office!.isEmpty) &&
                      (_additionalInfo == null ||
                          _additionalInfo!.isEmpty))
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Column(
                        children: [
                          Icon(Icons.person_outline,
                              size: 48, color: AppColors.textSecondary),
                          SizedBox(height: 8),
                          Text(
                            'No profile information yet.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.instructorPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}