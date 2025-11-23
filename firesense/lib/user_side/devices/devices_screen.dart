import 'package:firesense/user_side/devices/add_device_screen.dart';
import 'package:firesense/user_side/devices/device_detail_screen.dart';
import 'package:firesense/user_side/emergency/emergency_dial_screen.dart';
import 'package:firesense/user_side/home/home_screen.dart';
import 'package:firesense/user_side/materials/material_screen.dart';
import 'package:firesense/user_side/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);
    final Color bgGrey = const Color(0xFFF5F5F5);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final devicesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices');

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: bgGrey,
        elevation: 0,
        title: const Text(
          "My Devices",
          style: TextStyle(
            color: Color(0xFF8B0000),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.control_point_duplicate_outlined,
              color: Colors.black87,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddDeviceScreen(),
                ),
              );
            },
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: devicesRef.orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No devices added yet"));
          }

          final devices = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index].data() as Map<String, dynamic>;
              final deviceName = device['name'] ?? 'Unnamed Device';
              final deviceId = device['deviceId'] ?? 'No ID';

              return Card(
                elevation: 3,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: primaryRed.withOpacity(0.1),
                    child: const Icon(Icons.devices, color: Color(0xFF8B0000)),
                  ),
                  title: Text(
                    deviceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text("ID: $deviceId"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceDetailsScreen(deviceId: deviceId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'Materials',
            ),

            // 👉 NEW DEVICE TAB
            BottomNavigationBarItem(
              icon: Icon(Icons.sensors),
              label: 'Devices',
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
          currentIndex: 2,
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
              // Already on Devices screen
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencyDialScreen(),
                ),
              );
            } else if (index == 4) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }
          },
        ),
      ),
    );
  }
}
