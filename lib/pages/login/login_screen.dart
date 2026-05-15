import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/pages/signup/sign_up_screen.dart';
import 'package:luminescence/pages/reset_password/reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  String _role = 'student'; // default
  bool _isLoading = false;

  static final _emailRegex = RegExp(r'^[a-zA-Z]+\.[a-zA-Z]+@carsu\.edu\.ph$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String) {
      setState(() {
        _role = args;
      });
    }
  }

  // 🔍 Email validation (Carsu format)
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

  // 🔍 Password validation
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Password is required";
    }

    if (value.length < 6) {
      return "Password must be at least 6 characters";
    }

    return null;
  }

  void handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/chatScreen', (route) => false);
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Login failed';
        if (e.code == 'user-not-found') {
          message = 'No account found for this email';
        } else if (e.code == 'wrong-password') {
          message = 'Incorrect password';
        } else if (e.code == 'invalid-email') {
          message = 'Invalid email format';
        } else if (e.code == 'invalid-credential') {
          message = 'Invalid email or password';
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

  // Goes to Sign up area
  void handleSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SignUpScreen(role: _role)),
    );
  }

  // Goes to Help area
  void handleHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Email Format:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Use: FirstName.LastName@carsu.edu.ph'),
              Text('• Example: Juan.DelaCruz@carsu.edu.ph'),
              SizedBox(height: 12),
              Text(
                'Password Requirements:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• At least 6 characters long'),
              SizedBox(height: 12),
              Text(
                'Don\'t have an account?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Tap "Sign up here" below the login button'),
              SizedBox(height: 12),
              Text(
                'Forgot Password?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Use the "Forgot Password?" link on login screen'),
              SizedBox(height: 12),
              Text(
                'Need more help?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Contact IT Support: support@carsu.edu.ph'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
          onPressed: () {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/roleSelection', (route) => false);
          },
          tooltip: 'Back to Role Selection',
        ),
        title: null,
        actions: [
          TextButton(
            onPressed: handleHelp,
            child: const Text(
              '?',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 60),

                // 🔵 Title
                const Text(
                  "Log in",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Enter your Carsu and press login to securely access your account and manage your services.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),

                const SizedBox(height: 40),

                // 📧 Email
                TextFormField(
                  controller: _emailController,
                  validator: validateEmail,
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

                const SizedBox(height: 20),

                // 🔒 Password
                TextFormField(
                  controller: _passwordController,
                  validator: validatePassword,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 🟢 Login Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : handleLogin,
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
                        : const Text("Login", style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 10),

                // 🔑 Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResetPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "By continuing, you agree to our Terms of Service",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // 🔗 Sign up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: handleSignup,
                      child: const Text(
                        "Sign up here",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
