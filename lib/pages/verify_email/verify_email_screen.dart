import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? email;
  final String? role;

  const VerifyEmailScreen({super.key, this.email, this.role});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _timeoutMinutes = 10;
  int _remainingSeconds = _timeoutMinutes * 60;
  bool _isVerified = false;
  bool _isChecking = false;
  bool _isTimedOut = false;
  bool _isInitialized = false;
  String? _errorMessage;
  SharedPreferences? _prefs;
  String _email = '';
  String _role = 'student';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (widget.email != null) {
        _email = widget.email!;
        if (widget.role != null) {
          _role = widget.role!;
        } else {
          _role = _prefs!.getString('pending_role') ?? 'student';
        }
        await _prefs!.setString('pending_email', _email);
        await _prefs!.setString('pending_role', _role);
      } else {
        _email = _prefs!.getString('pending_email') ?? '';
        _role = _prefs!.getString('pending_role') ?? 'student';
      }
    } catch (e) {
      _errorMessage = 'Failed to load data: $e';
    } finally {
      if (mounted) {
        setState(() => _isInitialized = true);
        if (_email.isNotEmpty) {
          _startPolling();
          _startTimer();
        }
      }
    }
  }

  void _startPolling() {
    Future.doWhile(() async {
      if (!mounted) return false;
      if (_isVerified || _isTimedOut) return false;

      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return false;
      try {
        final user = FirebaseAuth.instance.currentUser;
        await user?.reload();
        if (user != null && user.emailVerified) {
          if (mounted) setState(() => _isVerified = true);
          await _onVerified(user);
          return false;
        }
      } catch (_) {}
      return true;
    });
  }

  void _startTimer() {
    Future.doWhile(() async {
      if (!mounted) return false;
      if (_isVerified) return false;

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _isTimedOut = true;
        }
      });

      if (_isTimedOut) {
        await _onTimeout();
        return false;
      }
      return true;
    });
  }

  Future<void> _onVerified(User user) async {
    setState(() => _isChecking = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'email': _email,
            'role': _role,
            'createdAt': FieldValue.serverTimestamp(),
            'emailVerified': true,
            'isApproved': _role == 'student' ? true : false,
            'isRevoked': false,
          });

      await _prefs!.remove('pending_email');
      await _prefs!.remove('pending_role');

      if (mounted) {
        if (_role == 'faculty') {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/pendingApproval',
            (route) => false,
          );
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/today',
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to complete signup: $e';
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _onTimeout() async {
    try {
      await _prefs!.remove('pending_email');
      await _prefs!.remove('pending_role');
      final user = FirebaseAuth.instance.currentUser;
      await user?.delete();
    } catch (_) {}
  }

  Future<void> _deleteUserAndGoToRoleSelection() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.delete();
    } catch (_) {}
    try {
      await _prefs!.remove('pending_email');
      await _prefs!.remove('pending_role');
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/roleSelection',
        (route) => false,
      );
    }
  }

  Future<void> _cancelAndRetry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Verification?'),
        content: const Text(
          'This will delete the current account and let you sign up with a different email. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _deleteUserAndGoToRoleSelection();
  }

  Future<void> _checkNow() async {
    setState(() => _isChecking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (user != null && user.emailVerified) {
        setState(() => _isVerified = true);
        await _onVerified(user);
      } else {
        if (mounted) {
          setState(() => _isChecking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email not verified yet. Please check your inbox.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _errorMessage = 'Error checking verification: $e';
        });
      }
    }
  }

  Future<void> _resendEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email resent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to resend: $e')));
      }
    }
  }

  String get _timerDisplay {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_email.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
          title: const Text('Verify Email'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'No pending verification found.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please sign up again.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _deleteUserAndGoToRoleSelection(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back to Sign Up',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Verify Email'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Verify Your Email',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'A verification email has been sent to:\n$_email',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 32),

              if (!_isVerified && !_isTimedOut)
                Column(
                  children: [
                    Text(
                      _timerDisplay,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Time remaining to verify',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),

              if (_isTimedOut)
                Column(
                  children: [
                    const Icon(Icons.timer_off, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text(
                      'Verification timed out',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'The account was not verified within 10 minutes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),

              if (_isVerified)
                Column(
                  children: [
                    const Icon(Icons.check_circle, size: 48, color: Colors.green),
                    const SizedBox(height: 8),
                    const Text(
                      'Email verified!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 32),

              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 16),
              ],

              if (!_isVerified && !_isTimedOut)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _checkNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "I've Verified My Email",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

              if (!_isVerified && !_isTimedOut) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _resendEmail,
                  child: const Text('Resend Verification Email'),
                ),
                TextButton(
                  onPressed: _cancelAndRetry,
                  child: const Text(
                    'Cancel & Try Different Email',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],

              if (_isTimedOut) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _deleteUserAndGoToRoleSelection(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Back to Sign Up',
                      style: TextStyle(fontSize: 15, color: Colors.white),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
