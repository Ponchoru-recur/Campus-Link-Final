import 'package:flutter/material.dart';
import 'package:luminescence/pages/auth/auth_service.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  // Logout the user
  void logout() {
    final auth = AuthService();
    auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text('Sam Varela'),
            accountEmail: Text('sam.varela@carsu.edu.ph'),
            currentAccountPicture: CircleAvatar(
              child: ClipOval(
                child: Image.asset(
                  'assets/images/joker.png',
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              image: DecorationImage(
                image: AssetImage('assets/images/dragon.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 15.0),
            child: ListTile(
              leading: Icon(Icons.school),
              title: Text("Profile"),
              onTap: () {
                Navigator.pushNamed(context, '/profile');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15.0),
            child: ListTile(
              leading: Icon(Icons.book),
              title: Text("Channels"),
              onTap: () {
                Navigator.pushNamed(context, '/channel');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15.0),
            child: ListTile(
              leading: Icon(Icons.assignment),
              title: Text("Assigments"),
              onTap: () {
                Navigator.pushNamed(context, '/assignment');
              },
              trailing: ClipOval(
                child: Container(
                  color: Colors.redAccent,
                  width: 20,
                  height: 20,
                  child: Center(
                    child: Text(
                      "8",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 15.0),
            child: ListTile(
              leading: Icon(Icons.settings),
              title: Text("Settings"),
              onTap: () {
                Navigator.pushNamed(context, '/setting');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15.0),
            child: ListTile(
              leading: Icon(Icons.description),
              title: Text("Policies"),
              onTap: () {},
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 15.0),
            child: ListTile(
              leading: Icon(Icons.share),
              title: Text("Share"),
              onTap: () {},
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15.0),
            child: ListTile(
              leading: Icon(Icons.logout),
              title: Text("Log out"),
              onTap: () {
                // Log user out and return to home screemn
                logout();
              },
            ),
          ),
        ],
      ),
    );
  }
}
