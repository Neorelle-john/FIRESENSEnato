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
  bool _alarmState = false; // Current alarm state from RTDB

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
          // Update alarm state from RTDB (default to false if not set)
          _alarmState = data['Alarm'] == true || data['alarm'] == true;
        });
      } else {
        // If data is null, ensure TestAlarm and Alarm default to false
        if (mounted) {
          setState(() {
            _testAlarm = false;
            _alarmState = false;
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

  Future<void> _toggleAlarm() async {
    try {
      final newValue = !_alarmState;
      await dbRef
          .child('Devices/${widget.deviceId}/Alarm')
          .set(newValue)
          .timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          _alarmState = newValue;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'Alarm activated' : 'Alarm deactivated'),
            duration: const Duration(seconds: 2),
            backgroundColor: newValue ? Colors.red : Colors.green,
          ),
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timeout: Could not update alarm'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Alarm toggle timeout: $e');
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
      print('Error toggling alarm: $e');
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
    // Show confirmation dialog with improved UI
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
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
                    color: Color(0xFF8B0000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                const Text(
                  'Disconnect Device',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  'Are you sure you want to disconnect "$deviceName"?',
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
                        onPressed: () => Navigator.of(context).pop(false),
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
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF8B0000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Disconnect',
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

    if (confirmed != true || !mounted) return;

    try {
      // Show loading indicator with improved UI
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF8B0000),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Disconnecting Device...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    // FIXED: Properly cancel listener with exception handling
    try {
      deviceListener?.cancel();
    } catch (e) {
      print('Warning: Error cancelling device listener: $e');
    }
    try {
      _alarmTypeSubscription?.cancel();
    } catch (e) {
      print('Warning: Error cancelling alarm type subscription: $e');
    }
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
                    if (value == 'edit') {
                      _navigateToEditScreen();
                    } else if (value == 'test_alarm') {
                      _toggleTestAlarm();
                    } else if (value == 'disconnect') {
                      _disconnectDevice();
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.black87),
                              SizedBox(width: 12),
                              Text('Edit Device'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
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
                              Icon(Icons.link_off, color: Color(0xFF8B0000)),
                              SizedBox(width: 12),
                              Text(
                                'Disconnect Device',
                                style: TextStyle(color: Color(0xFF8B0000)),
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
              // Bottom Alarm Toggle Button
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
                      onPressed: _toggleAlarm,
                      label: Text(
                        _alarmState ? 'Deactivate Alarm' : 'Activate Alarm',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _alarmState ? Colors.red : const Color(0xFF8B0000),
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
