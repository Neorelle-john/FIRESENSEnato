import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/services/alarm_widget.dart';
import 'package:firesense/services/sensor_alarm_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DeviceDetailsScreen extends StatefulWidget {
  final String deviceId;

  const DeviceDetailsScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  final dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription? deviceListener;
  Map<String, dynamic> sensorData = {};
  String deviceName = "Unknown Device";

  bool _showAlarm = false;

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

    // Fetch device name from Firestore
    FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('devices')
        .doc(widget.deviceId)
        .get()
        .then((snapshot) {
          if (snapshot.exists && mounted) {
            setState(() {
              deviceName = snapshot.data()?['name'] ?? "Unknown Device";
            });
          }
        });

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
        });
      }
    });
  }

  @override
  void dispose() {
    // FIXED: Properly cancel listener
    deviceListener?.cancel();
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
          ),

          body: ListView(
            padding: const EdgeInsets.all(16),
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
                    Text(
                      deviceName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Device ID: ${widget.deviceId}",
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // SENSOR VALUES (debug)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Device Information",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),

                    sensorData.isEmpty
                        ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              "No sensor data available yet",
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        )
                        : Column(
                          children:
                              sensorData.entries.map((entry) {
                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  elevation: 2,
                                  child: ListTile(
                                    title: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: Text(
                                      entry.value.toString(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_showAlarm)
          AlarmOverlay(
            onClose: () {
              setState(() {
                _showAlarm = false; // manually close overlay
              });
            },
          ),
      ],
    );
  }
}
