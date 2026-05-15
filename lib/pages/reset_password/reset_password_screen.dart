import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static final _emailRegex = RegExp(r'^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$');
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Email is required";
    }
    final regex = _emailRegex;
    if (!regex.hasMatch(value)) {
      return "Use format: Juan.DelaCruz@carsu.edu.ph";
    }
    return null;
  }

  void handleReset() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _emailController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset link sent! Check your email.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Failed to send reset email';
        if (e.code == 'user-not-found') {
          message = 'No account found for this email';
        } else if (e.code == 'invalid-email') {
          message = 'Invalid email format';
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back to Login',
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.green),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 60),
                const Icon(Icons.lock_reset, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                const Text(
                  "Forgot Your Password?",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Enter your CarSU email and we'll send you a link to reset your password.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  validator: validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "Carsu Email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : handleReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Send Reset Link",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    "Back to Login",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
