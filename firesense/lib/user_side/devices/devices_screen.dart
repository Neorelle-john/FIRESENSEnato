import 'package:firesense/user_side/devices/add_device_screen.dart';
import 'package:firesense/user_side/devices/device_detail_screen.dart';
import 'package:firesense/user_side/emergency/emergency_dial_screen.dart';
import 'package:firesense/user_side/home/home_screen.dart';
import 'package:firesense/user_side/materials/material_screen.dart';
import 'package:firesense/user_side/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/services/alarm_widget.dart';
import 'package:firesense/services/sensor_alarm_services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  StreamSubscription? _alarmSubscription;
  bool _showAlarm = false;
  String? _alarmDeviceName;
  String? _alarmDeviceId;

  @override
  void initState() {
    super.initState();
    // Initialize global alarm monitoring
    SensorAlarmService().startListeningToAllUserDevices();

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
        print('Alarm stream error in DevicesScreen: $error');
        // Don't crash the app on stream errors
      },
    );
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    super.dispose();
  }

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

    return Stack(
      children: [
        Scaffold(
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
            stream:
                devicesRef.orderBy('created_at', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryRed),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading devices...',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: primaryRed.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.devices_outlined,
                            size: 64,
                            color: primaryRed,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Devices Yet',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first device to start monitoring',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddDeviceScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Device'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final devices = snapshot.data!.docs;
              final deviceCount = devices.length;

              return Column(
                children: [
                  // Header with device count
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.sensors,
                            color: primaryRed,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Devices',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                '$deviceCount ${deviceCount == 1 ? 'Device' : 'Devices'}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Device List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device =
                            devices[index].data() as Map<String, dynamic>;
                        final deviceName = device['name'] ?? 'Unnamed Device';
                        final deviceId = device['deviceId'] ?? 'No ID';
                        final createdAt = device['created_at'] as Timestamp?;

                        return _DeviceCardWidget(
                          deviceName: deviceName,
                          deviceId: deviceId,
                          createdAt: createdAt,
                          primaryRed: primaryRed,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        DeviceDetailsScreen(deviceId: deviceId),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
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
                    MaterialPageRoute(
                      builder: (context) => const MaterialScreen(),
                    ),
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
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                }
              },
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

/// Separate StatefulWidget for device card that manages its own subscription
class _DeviceCardWidget extends StatefulWidget {
  final String deviceName;
  final String deviceId;
  final Timestamp? createdAt;
  final Color primaryRed;
  final VoidCallback onTap;

  const _DeviceCardWidget({
    required this.deviceName,
    required this.deviceId,
    required this.createdAt,
    required this.primaryRed,
    required this.onTap,
  });

  @override
  State<_DeviceCardWidget> createState() => _DeviceCardWidgetState();
}

class _DeviceCardWidgetState extends State<_DeviceCardWidget> {
  StreamSubscription<DatabaseEvent>? _statusSubscription;
  Timer? _onlineCheckTimer;
  bool _isOnline = false;
  DateTime? _lastUpdateTime;
  bool _hasReceivedInitialData = false;

  @override
  void initState() {
    super.initState();
    _startListening();
    _startOnlineCheckTimer();
  }

  void _startListening() {
    final dbRef = FirebaseDatabase.instance.ref();
    _statusSubscription = dbRef
        .child('Devices/${widget.deviceId}')
        .onValue
        .listen((event) {
          if (mounted) {
            final data = event.snapshot.value;
            
            if (data != null) {
              if (_hasReceivedInitialData) {
                // This is a new update after initial load - device is online
                _lastUpdateTime = DateTime.now();
                setState(() {
                  _isOnline = true;
                });
              } else {
                // First time seeing data - could be stale from before app restart
                // Don't set timestamp yet, wait for next update to confirm it's fresh
                _hasReceivedInitialData = true;
                // Don't set _lastUpdateTime or _isOnline yet
                // Will be set when next update arrives (if device is actually online)
                setState(() {
                  _isOnline = false;
                });
              }
            } else {
              // Data is null, definitely offline
              _hasReceivedInitialData = false;
              setState(() {
                _isOnline = false;
                _lastUpdateTime = null;
              });
            }
          }
        });
  }

  void _startOnlineCheckTimer() {
    // Check every 2 seconds if device is still online
    _onlineCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_lastUpdateTime != null) {
        final timeSinceLastUpdate =
            DateTime.now().difference(_lastUpdateTime!);
        // Consider offline if no update in last 5 minutes (300 seconds)
        // This prevents constant status changes from online to offline
        final shouldBeOnline = timeSinceLastUpdate.inSeconds < 300;

        if (_isOnline != shouldBeOnline) {
          setState(() {
            _isOnline = shouldBeOnline;
          });
        }
      } else if (_isOnline) {
        // No last update time but was online, mark as offline
        setState(() {
          _isOnline = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _onlineCheckTimer?.cancel();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _isOnline;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Device Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.sensors,
                    color: widget.primaryRed,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Device Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.deviceName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isOnline
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Added ${_formatDate(widget.createdAt!.toDate())}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Arrow Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: widget.primaryRed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
