import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// A singleton service that listens to Realtime Database sensor data
/// and notifies listeners when an alarm occurs.
class SensorAlarmService {
  static final SensorAlarmService _instance = SensorAlarmService._internal();
  factory SensorAlarmService() => _instance;
  SensorAlarmService._internal();

  final dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription? _listener;

  /// Callback to notify the UI when alarm occurs
  VoidCallback? onAlarmTriggered;

  /// Start listening to a specific device
  void startListening(String deviceId) {
    _listener?.cancel(); // Cancel previous listener if exists

    _listener = dbRef.child('Devices/$deviceId').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) return;

      // Check if "alarm" field is true
      if (data['Alarm'] == true && onAlarmTriggered != null) {
        onAlarmTriggered!();
      }
    });
  }

  /// Stop listening (call on dispose)
  void stopListening() {
    _listener?.cancel();
    _listener = null;
  }
}
