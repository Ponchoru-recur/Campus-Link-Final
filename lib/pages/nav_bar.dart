import 'package:flutter/material.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
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
          ListTile(
            leading: Icon(Icons.school_outlined),
            title: Text("Profile"),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.school_outlined),
            title: Text("Channels"),
            onTap: () {
              Navigator.pushNamed(context, '/channel');
            },
          ),
          ListTile(
            leading: Icon(Icons.school_outlined),
            title: Text("Assigments"),
            onTap: () {},
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
          ListTile(
            leading: Icon(Icons.school_outlined),
            title: Text("Announcements"),
            onTap: () {},
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text("Settings"),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.description),
            title: Text("Policies"),
            onTap: () {},
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.share),
            title: Text("Share"),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text("Log out"),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
