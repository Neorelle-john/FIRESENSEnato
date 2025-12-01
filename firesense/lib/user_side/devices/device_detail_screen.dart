import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/services/alarm_widget.dart';
import 'package:firesense/services/sensor_alarm_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firesense/user_side/devices/edit_device_screen.dart';

class DeviceDetailsScreen extends StatefulWidget {
  final String deviceId;

  const DeviceDetailsScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  final dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription? deviceListener;
  StreamSubscription<DocumentSnapshot>? _alarmTypeSubscription;
  Map<String, dynamic> sensorData = {};
  String deviceName = "Unknown Device";
  double? deviceLat;
  double? deviceLng;
  String? deviceAddress;
  String? _alarmType; // 'normal', 'smoke', 'fire', or null

  bool _showAlarm = false;
  bool _testAlarm = false;

  @override
  void initState() {
    super.initState();

    // Start listening to the device alarm
    SensorAlarmService()
      ..onAlarmTriggered = () {
        if (mounted) {
          setState(() {
            _showAlarm = true; // Show alarm overlay
          });
        }
      }
      ..startListening(widget.deviceId);

    // Fetch device data from Firestore
    _loadDeviceData();

    // Start listening to alarmType from Firestore
    _startAlarmTypeListening();

    // FIXED: Save listener to deviceListener so we can cancel it
    deviceListener = dbRef.child('Devices/${widget.deviceId}').onValue.listen((
      event,
    ) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      // Prevent setState after dispose
      if (!mounted) return;

      if (data != null) {
        setState(() {
          sensorData = data.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          // Update test alarm state from RTDB (default to false if not set)
          _testAlarm = data['TestAlarm'] == true;
        });
      } else {
        // If data is null, ensure TestAlarm defaults to false
        if (mounted) {
          setState(() {
            _testAlarm = false;
          });
        }
      }
    });
  }

  Future<void> _loadDeviceData() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('devices')
            .doc(widget.deviceId)
            .get();

    if (snapshot.exists && mounted) {
      final data = snapshot.data()!;
      setState(() {
        deviceName = data['name'] ?? "Unknown Device";
        deviceLat = data['lat']?.toDouble();
        deviceLng = data['lng']?.toDouble();
        deviceAddress = data['address'] as String?;
        _alarmType = data['alarmType'] as String?;
      });
    }
  }

  void _startAlarmTypeListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _alarmTypeSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(widget.deviceId)
        .snapshots()
        .listen((snapshot) {
          if (mounted && snapshot.exists) {
            final data = snapshot.data();
            final alarmType = data?['alarmType'] as String?;
            setState(() {
              _alarmType = alarmType;
            });
          } else if (mounted) {
            setState(() {
              _alarmType = null;
            });
          }
        });
  }

  Color _getStatusColor() {
    if (_alarmType == 'fire') {
      return Colors.red;
    } else if (_alarmType == 'smoke') {
      return Colors.orange; // Warning yellow/orange
    } else if (_alarmType == 'normal') {
      return Colors.green;
    } else {
      // Default to grey if no alarmType
      return Colors.grey;
    }
  }

  String _getStatusText() {
    if (_alarmType == 'fire') {
      return 'Fire';
    } else if (_alarmType == 'smoke') {
      return 'Smoke';
    } else if (_alarmType == 'normal') {
      return 'Normal';
    } else {
      return 'Unknown';
    }
  }

  void _navigateToEditScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDeviceScreen(deviceId: widget.deviceId),
      ),
    );

    // Reload device data after returning from edit screen
    if (mounted) {
      await _loadDeviceData();
    }
  }

  Future<void> _toggleTestAlarm() async {
    try {
      final newValue = !_testAlarm;
      await dbRef
          .child('Devices/${widget.deviceId}/TestAlarm')
          .set(newValue)
          .timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          _testAlarm = newValue;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue ? 'Test alarm activated' : 'Test alarm deactivated',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF8B0000),
          ),
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timeout: Could not update test alarm'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Test alarm toggle timeout: $e');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error toggling test alarm: $e');
    }
  }

  Future<void> _disconnectDevice() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Disconnect Device'),
            content: Text(
              'Are you sure you want to disconnect "$deviceName"?\n\n'
              'This will remove the device from your account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Disconnect'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final user = FirebaseAuth.instance.currentUser!;

      // Verify ownership before disconnecting
      final claimedBySnapshot =
          await dbRef.child('Devices/${widget.deviceId}/claimedBy').get();

      if (claimedBySnapshot.exists) {
        final claimedByUserId = claimedBySnapshot.value as String?;
        if (claimedByUserId != null && claimedByUserId != user.uid) {
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Error: You do not have permission to disconnect this device.',
                ),
                duration: Duration(seconds: 3),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Remove device from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(widget.deviceId)
          .delete()
          .timeout(const Duration(seconds: 10));

      // Remove claim from Realtime Database (release device for other users)
      try {
        await dbRef
            .child('Devices/${widget.deviceId}/claimedBy')
            .remove()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        // Log but don't fail the disconnect if claim removal fails
        print('Warning: Could not remove device claim: $e');
      }

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device disconnected successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Navigate back to devices screen
      if (mounted) {
        Navigator.pop(context); // Close device detail screen
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timeout: Could not disconnect device'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Disconnect device timeout: $e');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error disconnecting device: $e');
    }
  }

  @override
  void dispose() {
    // FIXED: Properly cancel listener
    deviceListener?.cancel();
    _alarmTypeSubscription?.cancel();
    SensorAlarmService().stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgGrey = const Color(0xFFF5F5F5);
    final Color cardWhite = Colors.white;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: bgGrey,
          appBar: AppBar(
            backgroundColor: bgGrey,
            elevation: 0,
            title: const Text(
              "Device Details",
              style: TextStyle(
                color: Color(0xFF8B0000),
                fontWeight: FontWeight.bold,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
            actions: [
              Theme(
                data: Theme.of(context).copyWith(
                  popupMenuTheme: const PopupMenuThemeData(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  onSelected: (value) {
                    if (value == 'test_alarm') {
                      _toggleTestAlarm();
                    } else if (value == 'disconnect') {
                      _disconnectDevice();
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'test_alarm',
                          child: Row(
                            children: [
                              Icon(
                                _testAlarm
                                    ? Icons.warning_amber_rounded
                                    : Icons.warning_outlined,
                                color:
                                    _testAlarm ? Colors.orange : Colors.black87,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _testAlarm
                                    ? 'Deactivate Test Alarm'
                                    : 'Test Alarm',
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'disconnect',
                          child: Row(
                            children: [
                              Icon(Icons.link_off, color: Colors.red),
                              SizedBox(width: 12),
                              Text(
                                'Disconnect Device',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ),
            ],
          ),

          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    // DEVICE HEADER
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardWhite,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Device Name and ID
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deviceName,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "ID: ${widget.deviceId}",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Alarm Type Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor().withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _getStatusText(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _getStatusColor(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (deviceLat != null && deviceLng != null) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Location',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            if (deviceAddress != null &&
                                deviceAddress!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B0000,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF8B0000,
                                    ).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Color(0xFF8B0000),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        deviceAddress!,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                height: 250,
                                width: double.infinity,
                                child: GoogleMap(
                                  key: ValueKey(
                                    '${deviceLat!.toStringAsFixed(6)}_${deviceLng!.toStringAsFixed(6)}',
                                  ),
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(deviceLat!, deviceLng!),
                                    zoom: 15,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId(
                                        'device_location',
                                      ),
                                      position: LatLng(deviceLat!, deviceLng!),
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueRed,
                                          ),
                                    ),
                                  },
                                  zoomControlsEnabled: false,
                                  myLocationButtonEnabled: false,
                                  scrollGesturesEnabled: false,
                                  rotateGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  zoomGesturesEnabled: false,
                                  mapToolbarEnabled: false,
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.location_off,
                                      size: 48,
                                      color: Colors.black38,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Location not set',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom Edit Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToEditScreen,
                      icon: const Icon(Icons.edit, size: 20),
                      label: const Text(
                        'Edit Device',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B0000),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showAlarm)
          AlarmOverlay(
            deviceName: deviceName,
            deviceId: widget.deviceId,
            onClose: () {
              setState(() {
                _showAlarm = false; // manually close overlay
              });
              SensorAlarmService().clearAlarm();
            },
          ),
      ],
    );
  }
}
