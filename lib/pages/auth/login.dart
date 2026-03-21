import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:hive_ce/hive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey =
      GlobalKey<FormState>(); // No idea what this is but is IMPORTANT
  bool showOptions = true; // This shows the option of either student or faculty

  final emailController = TextEditingController();

  // Class methods
  String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return "Email cannot be empty";
    }
    if (!email.endsWith('@carsu.edu.ph') || !(email.length > 13)) {
      return 'Please use your @carsu.edu.ph email';
    }
    return null;
  }

  void login(String email) {
    print("[LOG] Account does not exist");
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5, // half the screen
          padding: EdgeInsets.all(69),
          // margin: EdgeInsets.all(100),
          child: Column(
            children: [
              Text("Hello, just ask someone."),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close"),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isLoading = false;
  bool _isVerified = false;

  void _handleLogin() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true; // show loading spinner
    });

    // Wait for 3 seconds
    await Future.delayed(Duration(seconds: 3));
    if (!mounted) return;
    setState(() {
      _isLoading = false; // hide spinner
      _isVerified = true; // show verified text
    });

    await Future.delayed(Duration(seconds: 1));
    if (!mounted) return;
    // Navigate using pushNamed
    var userBox = Hive.box("CURRENT_USER");
    userBox.put('email', emailController.text);

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Theme.of(context,
      body: Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 400),
            child: showOptions
                ? Column(
                    key: ValueKey(1),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            showOptions = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                        child: Text("Student"),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            showOptions = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                        child: Text("Faculty"),
                      ),
                    ],
                  )
                : Center(
                    key: ValueKey(2),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Log in",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Enter your Carsu and press login to securely access your account and manage your services.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 30),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Carsu Email",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.email,
                                color: Colors.black87,
                              ),
                            ),
                            validator: validateEmail,
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _isLoading || _isVerified
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      _handleLogin();
                                    }
                                  },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : _isVerified
                                ? Text("Verified")
                                : Text("Login"),
                          ),
                          SizedBox(height: 15),
                          RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(color: Colors.black87),
                              children: [
                                TextSpan(
                                  text: "Sign up here",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed("/register");
                                    },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "By continuing, you agree to our Terms of Service",
                          ),
                          SizedBox(height: 10),
                          GestureDetector(
                            onTap: _showHelp,
                            child: Text(
                              "Need help?",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              var userBox = Hive.box("CURRENT_USER");
                              var groupBox = Hive.box("GROUP_CHATS");
                              var messagesBox = Hive.box("MESSAGES");
                              userBox.clear();
                              groupBox.clear();
                              messagesBox.clear();
                            },
                            child: Text("Reset"),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
