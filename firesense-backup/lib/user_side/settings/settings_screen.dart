import 'package:firesense/user_side/contacts/contacts_list_screen.dart';
import 'package:firesense/user_side/devices/devices_screen.dart';
import 'package:flutter/material.dart';
import 'package:firesense/user_side/home/home_screen.dart';
import 'package:firesense/user_side/materials/material_screen.dart';
import 'package:firesense/user_side/emergency/emergency_dial_screen.dart';
import 'package:firesense/user_side/settings/profile_screen.dart';
import 'package:firesense/user_side/settings/message_template_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/credentials/signin_screen.dart';
import 'package:firesense/services/alarm_widget.dart';
import 'package:firesense/services/sensor_alarm_services.dart';
import 'package:firesense/services/fire_prediction_services.dart';
import 'package:firesense/services/notification_service.dart';
import 'dart:async';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isLoadingNotificationPref = true;
  StreamSubscription? _alarmSubscription;
  bool _showAlarm = false;
  String? _alarmDeviceName;
  String? _alarmDeviceId;

  @override
  void initState() {
    super.initState();
    // Initialize global alarm monitoring
    SensorAlarmService().startListeningToAllUserDevices();

    // Initialize fire prediction service and start listening to all user devices
    _initializeFirePredictionService();

    // Listen to alarm stream
    _alarmSubscription = SensorAlarmService().alarmStream.listen(
      (alarmData) {
        if (mounted) {
          setState(() {
            _showAlarm = true;
            _alarmDeviceName = alarmData['deviceName'];
            _alarmDeviceId = alarmData['deviceId'];
          });
        }
      },
      onError: (error) {
        print('Alarm stream error in SettingsScreen: $error');
        // Don't crash the app on stream errors
      },
    );

    // Load notification preference
    _loadNotificationPreference();
  }

  /// Initialize fire prediction service and start listening to all user devices
  Future<void> _initializeFirePredictionService() async {
    try {
      print('SettingsScreen: Initializing fire prediction service...');
      await FirePredictionService().startListeningToAllUserDevices();
      print('SettingsScreen: Fire prediction service initialized successfully');
    } catch (e, stackTrace) {
      print('SettingsScreen: Error initializing fire prediction service: $e');
      print('Stack trace: $stackTrace');
      // Don't crash the app if prediction service fails to initialize
    }
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotificationPreference() async {
    setState(() {
      _isLoadingNotificationPref = true;
    });

    try {
      // Refresh preference from Firestore
      await NotificationService().refreshPreference();

      if (mounted) {
        setState(() {
          _notificationsEnabled = NotificationService().areNotificationsEnabled;
          _isLoadingNotificationPref = false;
        });
      }
    } catch (e) {
      print('Error loading notification preference: $e');
      if (mounted) {
        setState(() {
          _notificationsEnabled = true; // Default to enabled on error
          _isLoadingNotificationPref = false;
        });
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });

    try {
      await NotificationService().setNotificationsEnabled(value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Notifications enabled' : 'Notifications disabled',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF8B0000),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _notificationsEnabled = !value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating notification settings: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    // Stop fire prediction service before logout
    FirePredictionService().stopAllRealtimePredictions();
    // Stop sensor alarm service
    SensorAlarmService().stopListening();
    
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
    final Color cardWhite = Colors.white;

    Widget settingsTile({
      required String title,
      required IconData icon,
      String? subtitle,
      VoidCallback? onTap,
      Widget? trailing,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: primaryRed, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[trailing, const SizedBox(width: 8)],
                  if (onTap != null && trailing == null)
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget sectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.grey.shade800,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: lightGrey,
          appBar: AppBar(
            backgroundColor: lightGrey,
            elevation: 0,
            title: const Text(
              'Settings',
              style: TextStyle(
                color: Color(0xFF8B0000),
                fontWeight: FontWeight.bold,
              ),
            ),
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Account Section
                  sectionHeader('Account'),
                  settingsTile(
                    title: 'Profile',
                    icon: Icons.person_outline,
                    subtitle: 'Manage your personal information',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),

                  // Device Section
                  sectionHeader('Device'),
                  settingsTile(
                    title: 'View Devices',
                    icon: Icons.devices_other,
                    subtitle: 'Manage your connected devices',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DevicesScreen(),
                        ),
                      );
                    },
                  ),

                  // Alert and Notification Section
                  sectionHeader('Notifications'),
                  settingsTile(
                    title:
                        _notificationsEnabled
                            ? 'Turn off notifications'
                            : 'Turn on notifications',
                    icon:
                        _notificationsEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                    subtitle:
                        _notificationsEnabled
                            ? 'You\'ll receive fire alarm alerts'
                            : 'Notifications are currently disabled',
                    trailing:
                        _isLoadingNotificationPref
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Switch(
                              value: _notificationsEnabled,
                              onChanged: _toggleNotifications,
                              activeColor: Colors.white,
                              activeTrackColor: primaryRed,
                              inactiveThumbColor: Colors.grey.shade300,
                              inactiveTrackColor: Colors.grey.shade200,
                            ),
                  ),

                  // Emergency Contacts Section
                  sectionHeader('Emergency'),
                  settingsTile(
                    title: 'Manage Contacts',
                    icon: Icons.contacts_outlined,
                    subtitle: 'Add or edit emergency contacts',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactsListScreen(),
                        ),
                      );
                    },
                  ),
                  settingsTile(
                    title: 'Message Template',
                    icon: Icons.message_outlined,
                    subtitle: 'Customize emergency message content',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MessageTemplateScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Logout Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryRed.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
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
              currentIndex: 4,
              onTap: (index) {
                if (index == 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                } else if (index == 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MaterialScreen(),
                    ),
                  );
                } else if (index == 2) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DevicesScreen(),
                    ),
                  );
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
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu_book),
                  label: 'Materials',
                ),
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
            ),
          ),
        ),
        if (_showAlarm)
          AlarmOverlay(
            deviceName: _alarmDeviceName,
            deviceId: _alarmDeviceId,
            onClose: () {
              setState(() {
                _showAlarm = false;
              });
              SensorAlarmService().clearAlarm();
            },
          ),
      ],
    );
  }
}
