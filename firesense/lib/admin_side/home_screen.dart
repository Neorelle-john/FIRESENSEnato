import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'client_screen.dart';
import 'alert_screen.dart';
import 'settings.dart';
import '../credentials/signin_screen.dart';
import '../services/sensor_alarm_services.dart';
import '../services/admin_alert_service.dart';
import 'admin_alarm_overlay.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _alarmSubscription;
  bool _showAlarm = false;
  String? _alarmDeviceName;
  String? _alarmDeviceId;

  @override
  void initState() {
    super.initState();
    // Start listening to all devices for admin alerts
    // This ensures admin receives alerts from all devices, not just their own
    SensorAlarmService().startListeningToAllDevices();

    // Listen to alarm stream for overlay display
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
        print('Alarm stream error in AdminHomeScreen: $error');
        // Don't crash the app on stream errors
      },
    );
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    // Don't stop listening when admin navigates - keep monitoring
    // SensorAlarmService().stopListening();
    super.dispose();
  }

  /// Find and open alert details for the given device ID
  Future<void> _openAlertForDevice(String? deviceId) async {
    if (deviceId == null || deviceId.isEmpty) {
      print('Admin: Cannot open alert - deviceId is null or empty');
      return;
    }

    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      print('Admin: Cannot open alert - user not logged in');
      return;
    }

    try {
      // Find the most recent active alert for this device
      // Query by deviceId only to avoid composite index requirement
      final alertsSnapshot = await FirebaseFirestore.instance
          .collection('admin')
          .doc(adminUser.uid)
          .collection('alerts')
          .where('deviceId', isEqualTo: deviceId)
          .get()
          .timeout(const Duration(seconds: 5));

      // Filter for active alerts and sort by timestamp in memory
      final activeAlerts =
          alertsSnapshot.docs.where((doc) {
            final data = doc.data();
            return data['status'] == 'Active';
          }).toList();

      // Sort by timestamp descending (most recent first)
      activeAlerts.sort((a, b) {
        final aTimestamp = a.data()['timestamp'] as Timestamp?;
        final bTimestamp = b.data()['timestamp'] as Timestamp?;
        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;
        return bTimestamp.compareTo(aTimestamp);
      });

      if (activeAlerts.isNotEmpty) {
        final alertDoc = activeAlerts.first;
        final alertData = alertDoc.data();

        if (mounted) {
          // Show alert details
          AdminAlertHelper.showAlertDetails(context, alertData, alertDoc.id);
        }
      } else {
        // If no active alert found, try to find any alert for this device
        // Sort all alerts by timestamp
        final allAlerts = alertsSnapshot.docs.toList();
        allAlerts.sort((a, b) {
          final aTimestamp = a.data()['timestamp'] as Timestamp?;
          final bTimestamp = b.data()['timestamp'] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp);
        });

        if (allAlerts.isNotEmpty) {
          final alertDoc = allAlerts.first;
          final alertData = alertDoc.data();

          if (mounted) {
            AdminAlertHelper.showAlertDetails(context, alertData, alertDoc.id);
          }
        } else {
          print('Admin: No alert found for device $deviceId');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Alert not found for this device'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Admin: Error finding alert for device $deviceId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening alert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  final List<Widget> _screens = [
    // Dashboard
    _AdminDashboard(),
    // Clients
    AdminClientsScreen(),
    // Alerts
    AdminAlertScreen(),
    // Settings
    AdminSettingsScreen(),
  ];

  final List<String> _titles = [
    'Admin Dashboard',
    'Clients',
    'Alerts',
    'Settings',
  ];

  void _onDrawerTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close the drawer
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: primaryRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                const Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  'Are you sure you want to log out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _logout(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: primaryRed,
        elevation: 2,
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: true,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // Enhanced Header
            Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryRed, Color(0xFFB22222)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Admin Panel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'FireSense Management',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'System Administrator',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
            // Navigation Items
            Expanded(
              child: Container(
                color: const Color(0xFFF8F9FA),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.dashboard_outlined,
                      title: 'Dashboard',
                      subtitle: 'Overview & Statistics',
                      index: 0,
                      isSelected: _selectedIndex == 0,
                    ),
                    _buildDrawerItem(
                      icon: Icons.people_outline,
                      title: 'Clients',
                      subtitle: 'Manage Client Accounts',
                      index: 1,
                      isSelected: _selectedIndex == 1,
                    ),
                    _buildDrawerItem(
                      icon: Icons.warning_amber_outlined,
                      title: 'Alerts',
                      subtitle: 'Emergency Notifications',
                      index: 2,
                      isSelected: _selectedIndex == 2,
                    ),
                    _buildDrawerItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'System Preferences',
                      index: 3,
                      isSelected: _selectedIndex == 3,
                    ),
                  ],
                ),
              ),
            ),
            // Footer with Sign Out
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Sign Out Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showLogoutDialog(context),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SafeArea(child: _screens[_selectedIndex]),
          // Alarm Overlay - shows when alarm is detected
          if (_showAlarm)
            AdminAlarmOverlay(
              deviceName: _alarmDeviceName,
              deviceId: _alarmDeviceId,
              onClose: () {
                setState(() {
                  _showAlarm = false;
                });
                SensorAlarmService().clearAlarm();
              },
              onOpenAlert: () {
                // Open alert details for this device
                _openAlertForDevice(_alarmDeviceId);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required int index,
    required bool isSelected,
  }) {
    const Color primaryRed = Color(0xFF8B0000);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? primaryRed.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
                ? Border.all(color: primaryRed.withOpacity(0.3), width: 1)
                : null,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? primaryRed : primaryRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : primaryRed,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 15,
            color: isSelected ? primaryRed : const Color(0xFF495057),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color:
                isSelected ? primaryRed.withOpacity(0.7) : Colors.grey.shade600,
          ),
        ),
        onTap: () => _onDrawerTap(index),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

// Enhanced Dashboard widget with comprehensive data
class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard();

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  int _clientCount = 0;
  int _deviceCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen becomes visible
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Load client count from Firestore
      final clientsSnapshot =
          await FirebaseFirestore.instance
              .collection('admin')
              .doc(adminUser.uid)
              .collection('clients')
              .get();

      // Load device count from Realtime Database
      final dbRef = FirebaseDatabase.instance.ref();
      final devicesSnapshot = await dbRef.child('Devices').get();

      int deviceCount = 0;
      if (devicesSnapshot.exists && devicesSnapshot.value != null) {
        final devices = devicesSnapshot.value as Map<dynamic, dynamic>?;
        if (devices != null) {
          deviceCount = devices.length;
        }
      }

      if (mounted) {
        setState(() {
          _clientCount = clientsSnapshot.docs.length;
          _deviceCount = deviceCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);
    const Color cardWhite = Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Enhanced Map View Button - Primary Eye Catcher
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [primaryRed, Color(0xFFB22222)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryRed.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: primaryRed.withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminMapScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 32,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated icon container
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.map_outlined,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Enhanced text with subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'VIEW MAP',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Monitor Fire Sensors',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Arrow indicator
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Statistics Cards Row 1
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people_outline,
                  title: 'Total Clients',
                  value: _isLoading ? '...' : '$_clientCount',
                  subtitle: 'Registered',
                  color: primaryRed,
                  trend: '',
                  trendColor: Colors.transparent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.devices,
                  title: 'Total Devices',
                  value: _isLoading ? '...' : '$_deviceCount',
                  subtitle: 'In System',
                  color: Colors.blue,
                  trend: '',
                  trendColor: Colors.transparent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Statistics Cards Row 2 - Active Alerts and System Status (Dynamic)
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseAuth.instance.currentUser != null
                    ? FirebaseFirestore.instance
                        .collection('admin')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('alerts')
                        .snapshots()
                    : null,
            builder: (context, alertsSnapshot) {
              int activeAlertsCount = 0;
              String systemStatus = 'OK';
              Color statusColor = Colors.green;
              String statusSubtitle = 'All Clear';

              if (alertsSnapshot.hasData && alertsSnapshot.data != null) {
                final alerts = alertsSnapshot.data!.docs;
                activeAlertsCount =
                    alerts.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['status'] != 'Resolved';
                    }).length;

                if (activeAlertsCount > 0) {
                  systemStatus = 'Alert';
                  statusColor = Colors.red;
                  statusSubtitle = '$activeAlertsCount Active';
                }
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.warning_amber_outlined,
                      title: 'Active Alerts',
                      value:
                          alertsSnapshot.connectionState ==
                                  ConnectionState.waiting
                              ? '...'
                              : '$activeAlertsCount',
                      subtitle:
                          activeAlertsCount == 0 ? 'None' : 'Require Attention',
                      color: Colors.orange,
                      trend: '',
                      trendColor: Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.info_outline,
                      title: 'System Status',
                      value:
                          alertsSnapshot.connectionState ==
                                  ConnectionState.waiting
                              ? '...'
                              : systemStatus,
                      subtitle: statusSubtitle,
                      color: statusColor,
                      trend: '',
                      trendColor: Colors.transparent,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Recent Alerts Section - Dynamic
          _buildSectionHeader('Recent Alerts'),
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseAuth.instance.currentUser != null
                    ? FirebaseFirestore.instance
                        .collection('admin')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('alerts')
                        .orderBy('timestamp', descending: true)
                        .limit(5)
                        .snapshots()
                    : null,
            builder: (context, alertsSnapshot) {
              if (alertsSnapshot.connectionState == ConnectionState.waiting) {
                return Container(
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
                  child: const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (!alertsSnapshot.hasData ||
                  alertsSnapshot.data == null ||
                  alertsSnapshot.data!.docs.isEmpty) {
                return Container(
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
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Active Alerts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All systems are operating normally',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final alerts = alertsSnapshot.data!.docs;
              return Container(
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
                child: Column(
                  children: [
                    ...alerts.map((alertDoc) {
                      final alert = alertDoc.data() as Map<String, dynamic>;
                      final deviceName =
                          alert['deviceName'] as String? ?? 'Unknown Device';
                      final userName =
                          alert['userName'] as String? ?? 'Unknown User';
                      final status = alert['status'] as String? ?? 'Active';
                      final timestamp = alert['timestamp'] as Timestamp?;

                      Color statusColor;
                      switch (status) {
                        case 'Active':
                          statusColor = Colors.red;
                          break;
                        case 'Investigating':
                          statusColor = Colors.orange;
                          break;
                        case 'Resolved':
                          statusColor = Colors.green;
                          break;
                        default:
                          statusColor = Colors.grey;
                      }

                      String timeAgo = 'Just now';
                      if (timestamp != null) {
                        final now = DateTime.now();
                        final alertTime = timestamp.toDate();
                        final difference = now.difference(alertTime);

                        if (difference.inMinutes < 1) {
                          timeAgo = 'Just now';
                        } else if (difference.inMinutes < 60) {
                          timeAgo = '${difference.inMinutes} mins ago';
                        } else if (difference.inHours < 24) {
                          timeAgo =
                              '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
                        } else {
                          timeAgo =
                              '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
                        }
                      }

                      return Container(
                        margin: EdgeInsets.only(
                          top: alerts.indexOf(alertDoc) == 0 ? 16 : 0,
                          bottom:
                              alerts.indexOf(alertDoc) == alerts.length - 1
                                  ? 16
                                  : 0,
                          left: 16,
                          right: 16,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.local_fire_department,
                                color: statusColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    deviceName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'User: $userName',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (alerts.length >= 5)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextButton.icon(
                          onPressed: () {
                            // Navigate to alerts screen
                            // The parent widget should handle navigation
                            // For now, just show a message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'View all alerts in the Alerts tab',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('View All Alerts'),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryRed,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
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

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required String trend,
    required Color trendColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon without background
              Icon(icon, color: color, size: 24),
              const Spacer(),
              if (trend.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: trendColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: trendColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// Map screen with alert markers
class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({Key? key}) : super(key: key);

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  // Default location: Urdaneta City, Pangasinan
  static const LatLng _defaultLocation = LatLng(15.9761, 120.5711);
  String? _selectedAlertId;
  Map<String, dynamic>? _selectedAlert;

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);
    final adminUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryRed,
        elevation: 10,
        title: const Text(
          'Map View',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            adminUser != null
                ? FirebaseFirestore.instance
                    .collection('admin')
                    .doc(adminUser.uid)
                    .collection('alerts')
                    .snapshots()
                : null,
        builder: (context, alertsSnapshot) {
          Set<Marker> markers = {};
          Map<String, Map<String, dynamic>> alertsMap = {};

          if (alertsSnapshot.hasData && alertsSnapshot.data != null) {
            for (var alertDoc in alertsSnapshot.data!.docs) {
              final alert = alertDoc.data() as Map<String, dynamic>;
              final alertId = alertDoc.id;
              final deviceLocation =
                  alert['deviceLocation'] as Map<String, dynamic>?;

              if (deviceLocation != null &&
                  deviceLocation['lat'] != null &&
                  deviceLocation['lng'] != null) {
                final lat = (deviceLocation['lat'] as num).toDouble();
                final lng = (deviceLocation['lng'] as num).toDouble();
                final deviceName =
                    alert['deviceName'] as String? ?? 'Unknown Device';
                final userName = alert['userName'] as String? ?? 'Unknown User';
                final status = alert['status'] as String? ?? 'Active';

                alertsMap[alertId] = alert;

                // Determine marker color based on status
                BitmapDescriptor markerIcon;
                switch (status) {
                  case 'Active':
                    markerIcon = BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    );
                    break;
                  case 'Investigating':
                    markerIcon = BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange,
                    );
                    break;
                  case 'Resolved':
                    markerIcon = BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    );
                    break;
                  default:
                    markerIcon = BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    );
                }

                markers.add(
                  Marker(
                    markerId: MarkerId(alertId),
                    position: LatLng(lat, lng),
                    icon: markerIcon,
                    infoWindow: InfoWindow(
                      title: deviceName,
                      snippet: 'User: $userName',
                    ),
                    onTap: () {
                      setState(() {
                        _selectedAlertId = alertId;
                        _selectedAlert = alert;
                      });
                    },
                  ),
                );
              }
            }
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultLocation,
                  zoom: 13,
                ),
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
              ),
              // Alert detail widget when marker is selected
              if (_selectedAlertId != null && _selectedAlert != null)
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: _buildAlertInfoCard(
                    _selectedAlert!,
                    _selectedAlertId!,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlertInfoCard(Map<String, dynamic> alert, String alertId) {
    const Color primaryRed = Color(0xFF8B0000);

    final deviceName = alert['deviceName'] as String? ?? 'Unknown Device';
    final userName = alert['userName'] as String? ?? 'Unknown User';
    final status = alert['status'] as String? ?? 'Active';
    final timestamp = alert['timestamp'] as Timestamp?;

    Color statusColor;
    switch (status) {
      case 'Active':
        statusColor = Colors.red;
        break;
      case 'Investigating':
        statusColor = Colors.orange;
        break;
      case 'Resolved':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    String timeAgo = 'Just now';
    if (timestamp != null) {
      final now = DateTime.now();
      final alertTime = timestamp.toDate();
      final difference = now.difference(alertTime);

      if (difference.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes} mins ago';
      } else if (difference.inHours < 24) {
        timeAgo =
            '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else {
        timeAgo =
            '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      }
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Show alert details modal without closing the map
          _showAlertDetailsFromMap(context, alert, alertId);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'User: $userName',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedAlertId = null;
                        _selectedAlert = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeAgo,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showAlertDetailsFromMap(context, alert, alertId);
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlertDetailsFromMap(
    BuildContext context,
    Map<String, dynamic> alert,
    String alertId,
  ) {
    const Color primaryRed = Color(0xFF8B0000);

    final deviceName = alert['deviceName'] as String? ?? 'Unknown Device';
    final deviceId = alert['deviceId'] as String? ?? 'Unknown';
    final deviceAddress = alert['deviceAddress'] as String? ?? 'Not specified';
    final deviceLocation = alert['deviceLocation'] as Map<String, dynamic>?;

    final userName = alert['userName'] as String? ?? 'Unknown User';
    final userEmail = alert['userEmail'] as String? ?? 'Not specified';
    final userPhone = alert['userPhone'] as String? ?? 'Not specified';
    final userAddress = alert['userAddress'] as String? ?? 'Not specified';
    final userLocation = alert['userLocation'] as Map<String, dynamic>?;

    final status = alert['status'] as String? ?? 'Active';
    final timestamp = alert['timestamp'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryRed, Color(0xFFB22222)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alert Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (timestamp != null)
                              Text(
                                '${timestamp.toDate().toString().substring(0, 19)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Section
                        _buildDetailSection('Status', [
                          _buildDetailRow(
                            'Current Status',
                            status,
                            status == 'Active'
                                ? Colors.red
                                : status == 'Investigating'
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // User Information Section
                        _buildDetailSection('User Information', [
                          _buildDetailRow('Name', userName),
                          _buildDetailRow('Email', userEmail),
                          _buildDetailRow('Phone', userPhone),
                          _buildDetailRow('Address', userAddress),
                          if (userLocation != null)
                            _buildDetailRow(
                              'Location',
                              'Lat: ${userLocation['lat']?.toStringAsFixed(6) ?? 'N/A'}, Lng: ${userLocation['lng']?.toStringAsFixed(6) ?? 'N/A'}',
                            ),
                        ]),

                        const SizedBox(height: 24),

                        // Device Information Section
                        _buildDetailSection('Device Information', [
                          _buildDetailRow('Device Name', deviceName),
                          _buildDetailRow('Device ID', deviceId),
                          _buildDetailRow('Device Address', deviceAddress),
                          if (deviceLocation != null)
                            _buildDetailRow(
                              'Device Location',
                              'Lat: ${deviceLocation['lat']?.toStringAsFixed(6) ?? 'N/A'}, Lng: ${deviceLocation['lng']?.toStringAsFixed(6) ?? 'N/A'}',
                            ),
                          if (deviceLocation != null) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 200,
                                width: double.infinity,
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                      (deviceLocation['lat'] as num).toDouble(),
                                      (deviceLocation['lng'] as num).toDouble(),
                                    ),
                                    zoom: 15,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId(
                                        'device_location',
                                      ),
                                      position: LatLng(
                                        (deviceLocation['lat'] as num)
                                            .toDouble(),
                                        (deviceLocation['lng'] as num)
                                            .toDouble(),
                                      ),
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueRed,
                                          ),
                                    ),
                                  },
                                  zoomControlsEnabled: false,
                                  myLocationButtonEnabled: false,
                                  scrollGesturesEnabled: true,
                                  rotateGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  zoomGesturesEnabled: true,
                                  mapToolbarEnabled: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _openInGoogleMaps(
                                    (deviceLocation['lat'] as num).toDouble(),
                                    (deviceLocation['lng'] as num).toDouble(),
                                  );
                                },
                                icon: const Icon(Icons.map, size: 18),
                                label: const Text('Open in Google Maps'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B0000),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ]),

                        const SizedBox(height: 24),

                        // Actions
                        if (status != 'Resolved') ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    AdminAlertService().updateAlertStatus(
                                      alertId: alertId,
                                      status: 'Investigating',
                                    );
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Alert status updated to Investigating',
                                        ),
                                        backgroundColor: Color(0xFF8B0000),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.search, size: 18),
                                  label: const Text('Mark as Investigating'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B0000),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    AdminAlertService().updateAlertStatus(
                                      alertId: alertId,
                                      status: 'Resolved',
                                    );
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Alert status updated to Resolved',
                                        ),
                                        backgroundColor: Color(0xFF8B0000),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                  ),
                                  label: const Text('Mark as Resolved'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B0000),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0000),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black87,
                fontWeight:
                    valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInGoogleMaps(double lat, double lng) async {
    try {
      final googleMapsAppUrl = Uri.parse("geo:$lat,$lng?q=$lat,$lng(Device)");
      final googleMapsWebUrl = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
      );

      if (await canLaunchUrl(googleMapsAppUrl)) {
        await launchUrl(googleMapsAppUrl, mode: LaunchMode.externalApplication);
      } else {
        if (await canLaunchUrl(googleMapsWebUrl)) {
          await launchUrl(
            googleMapsWebUrl,
            mode: LaunchMode.externalApplication,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not open Google Maps. Please install Google Maps app or check your internet connection.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error opening Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open Google Maps. Please try again later.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
