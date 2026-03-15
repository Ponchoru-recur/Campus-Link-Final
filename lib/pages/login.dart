import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Variables
  bool showOptions = true; // This shows the option of either student or faculty
  bool isStudent = false; // Check if it's a student or a faculty

  bool isMailSent = false; // For animation of sending something
  // Class methods
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }

    if (value.contains('admin')) {
      return null;
    }

    if (!value.contains('@carsu.edu.ph')) {
      return 'Please use your @carsu.edu.ph email';
    }

    return null;
  }

  void _gotoGmail() {
    if (!mounted) return;
    Navigator.pushNamed(context, '/gmail');
    setState(() {
      isMailSent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                            isStudent = true;
                            showOptions = false;
                          });
                        },
                        child: Text("Student"),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isStudent = false;
                            showOptions = false;
                          });
                        },
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
                          Text("APP LOGO"),
                          Text("Campus Link"),
                          TextFormField(
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Carsu Email",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            validator: validateEmail,
                          ),
                          ElevatedButton(
                            onPressed: isMailSent
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      //   print("Email : valid!");
                                      setState(() {
                                        isMailSent = true;
                                      });
                                      Future.delayed(
                                        Duration(milliseconds: 400),
                                        _gotoGmail,
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlueAccent,
                            ),
                            child: isMailSent
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text("Send Magic Link"),
                          ),
                          SizedBox(height: 20),
                          Text(
                            "By continuing, you agree to our Terms of Service",
                          ),
                          SizedBox(height: 40),
                          Text("[ Need help? ]"),
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
