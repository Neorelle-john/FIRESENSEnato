import 'package:flutter/material.dart';
import 'package:firesense/home_screen.dart';
import 'package:firesense/material_screen.dart';
import 'package:firesense/emergency_dial_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/signin_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool fireAlerts = true;
  bool notificationTone = true;
  bool vibrationMode = true;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);
    final Color lightGrey = const Color(0xFFF5F5F5);
    final Color cardGrey = const Color(0xFFD9D9D9);
    final Color cardWhite = Colors.white;

    Widget settingsTile({required String title, VoidCallback? onTap, Widget? trailing}) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cardGrey,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (trailing != null) trailing,
            if (onTap != null && trailing == null)
              const Icon(Icons.chevron_right, size: 28, color: Colors.black87),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: lightGrey,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            const Text('Account', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            const SizedBox(height: 8),
            settingsTile(title: 'Profile', onTap: () {}),
            const SizedBox(height: 8),
            const Text('Device', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            const SizedBox(height: 8),
            settingsTile(title: 'Connected Devices', onTap: () {}),
            settingsTile(title: 'Test alarm', onTap: () {}),
            const SizedBox(height: 8),
            const Text('Alert and Notification', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            const SizedBox(height: 8),
            settingsTile(
              title: 'Enable Fire alerts',
              trailing: Switch(
                value: fireAlerts,
                onChanged: (val) => setState(() => fireAlerts = val),
                activeColor: Colors.white,
                activeTrackColor: const Color.fromARGB(206, 118, 15, 15),
                inactiveThumbColor: primaryRed,
                inactiveTrackColor: Colors.grey[300],
              ),
            ),
            settingsTile(
              title: 'Notification tone',
              trailing: Switch(
                value: notificationTone,
                onChanged: (val) => setState(() => notificationTone = val),
                  activeColor: Colors.white,
                activeTrackColor: const Color.fromARGB(206, 118, 15, 15),
                inactiveThumbColor: primaryRed,
                inactiveTrackColor: Colors.grey[300],
              ),
            ),
            settingsTile(
              title: 'Vibration  mode',
              trailing: Switch(
                value: vibrationMode,
                onChanged: (val) => setState(() => vibrationMode = val),
                activeColor: Colors.white,
                activeTrackColor: const Color.fromARGB(206, 118, 15, 15),
                inactiveThumbColor: primaryRed,
                inactiveTrackColor: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Emergency Contacts', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            const SizedBox(height: 8),
            settingsTile(title: 'Manage Contacts', onTap: () {}),
            settingsTile(title: 'Emergency message template', onTap: () {}),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Log out'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: primaryRed,
          unselectedItemColor: Colors.black54,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          currentIndex: 3,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MaterialScreen()),
              );
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const EmergencyDialScreen()),
              );
            } else if (index == 3) {
              // Already on Settings
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'Materials',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.phone_in_talk),
              label: 'Emergency Dial',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
} 