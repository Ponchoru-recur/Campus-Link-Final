import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey =
      GlobalKey<FormState>(); // No idea what this is but is IMPORTANT
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
                            isStudent = false;
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
                          Icon(
                            Icons.message,
                            size: 60,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(height: 100),
                          Text(
                            "Welcome back, to Campus Link!",
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: 20),
                          TextFormField(
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
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              minimumSize: const Size.fromHeight(50),
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
