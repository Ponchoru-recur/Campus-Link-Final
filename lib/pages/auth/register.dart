import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController(); // Text For email
  final idController = TextEditingController(); // Text for ID
  final _formKey = GlobalKey<FormState>();

  String emailtest = '';

  @override
  Widget build(BuildContext context) {
    // Register the user
    void register(String email, String id) {
      if (email.isEmpty || id.isEmpty) {
        print("[Error] could not register account");
        return;
      }
      // Access the box directly
      var userBox = Hive.box("CURRENT_USER");
      userBox.put(email, {"id": id, 'email': email});
      emailtest = email;
    }

    String? validateEmail(String? email) {
      if (email == null || email.isEmpty) {
        return "Email cannot be empty";
      }
      if (!email.endsWith('@carsu.edu.ph')) {
        return 'Please use your @carsu.edu.ph email';
      }

      return null;
    }

    String? validateID(String? id) {
      if (id == null || id.isEmpty) {
        return 'ID cannot be empty';
      }
      if (id.length > 9) {
        return 'ID does not exceed 9 characters';
      }

      return null;
    }

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight(
              child: Align(
                alignment: Alignment(0, -0.6),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Text says create account
                      Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 25),
                      Text(
                        "Create a new account to get started and enjoy seamless access to Campus Link",
                        style: TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: idController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: "Student ID",

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),

                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.grey),
                          ),

                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),

                          prefixIcon: Icon(
                            Icons.power_input,
                            color: Colors.black87,
                          ),
                        ),
                        validator: validateID,
                      ),
                      SizedBox(height: 30),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Email Address",

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),

                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: Colors.grey),
                          ),

                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),

                          prefixIcon: Icon(Icons.email, color: Colors.black87),
                        ),
                        validator: validateEmail,
                      ),
                      SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            register(emailController.text, idController.text);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: Text("Create Account"),
                      ),
                      SizedBox(height: 15),
                      RichText(
                        text: TextSpan(
                          text: "Already have an account? ",
                          style: TextStyle(color: Colors.black87),
                          children: [
                            TextSpan(
                              text: "Sign in here",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.of(context).pop();
                                },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          var userBox = Hive.box("CURRENT_USER");
                          var user = userBox.get(emailtest);

                          print("[LOG] ${user['email']} & ${user['id']}");
                        },
                        child: Text("TEST"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
