import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/components/my_text_field.dart';
import 'package:luminescence/pages/auth/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController(); // Text For email
  final passwordController = TextEditingController(); // Hold the password
  final confirmPasswordController = TextEditingController();
  final idController = TextEditingController(); // Text for ID
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    String? validateEmail(String? email) {
      if (email == null || email.isEmpty) {
        return "Email cannot be empty";
      }
      if (!email.endsWith('@carsu.edu.ph')) {
        return 'Please use your @carsu.edu.ph email';
      }

      return null;
    }

    String? validateID(String? value) {
      if (value == null || value.isEmpty) {
        return "ID cannot be empty";
      }

      final pattern = RegExp(r'^\d{3}-\d{5}$');

      if (!pattern.hasMatch(value)) {
        return "Invalid ID format. Use 000-00000";
      }

      return null; // valid
    }

    String? validatePassword(String? password) {
      if (password == null || password.isEmpty) {
        return "Password cannot be empty";
      }

      if (!(password.length >= 8)) {
        return 'Password minimum 8 characters';
      }
      return null;
    }

    // Register the user
    void register(
      BuildContext context,
      String email,
      String password,
      String confirmPassword,
    ) {
      final auth = AuthService();
      if (email.isEmpty || password.isEmpty) {
        return;
      }
      // Only create account if two passwords matches
      if (password == confirmPassword) {
        try {
          auth.signUpWithEmailPassword(email, password);
          showDialog(
            context: context,
            builder: (context) =>
                SimpleDialog(title: const Text("Account created!")),
          );
          // Clear the typing in the text Form field
          emailController.clear();
          passwordController.clear();
          confirmPasswordController.clear();
          idController.clear();
        } catch (e) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(title: Text(e.toString())),
          );
        }
      }
      // password don't match -> tell user to fix
      else {
        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(title: const Text("Password don't match!")),
        );
      }
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
                      MyTextField(
                        controller: emailController,
                        label: "Email Address",
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: validateEmail,
                      ),
                      SizedBox(height: 15),
                      MyTextField(
                        controller: passwordController,
                        label: "Password",
                        icon: Icons.visibility_off,
                        obscuretext: true,
                        keyboardType: TextInputType.visiblePassword,
                        validator: validatePassword,
                      ),
                      SizedBox(height: 15),
                      MyTextField(
                        controller: confirmPasswordController,
                        label: "Confirm Password",
                        icon: Icons.visibility_off,
                        obscuretext: true,
                        keyboardType: TextInputType.visiblePassword,
                        validator: validatePassword,
                      ),

                      SizedBox(height: 15),
                      MyTextField(
                        controller: idController,
                        label: "Type ID",
                        icon: Icons.perm_identity,
                        keyboardType: TextInputType.text,
                        validator: validateID,
                      ),
                      SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            // Register account
                            register(
                              context,
                              emailController.text,
                              passwordController.text,
                              confirmPasswordController.text,
                            );
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
