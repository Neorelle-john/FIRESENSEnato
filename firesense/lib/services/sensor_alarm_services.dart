import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/services/sms_alarm_service.dart';
import 'package:firesense/services/notification_service.dart';

/// A singleton service that listens to Realtime Database sensor data
/// and notifies listeners when an alarm occurs from any user device.
class SensorAlarmService {
  static final SensorAlarmService _instance = SensorAlarmService._internal();
  factory SensorAlarmService() => _instance;
  SensorAlarmService._internal();

  final dbRef = FirebaseDatabase.instance.ref();
  final List<StreamSubscription> _listeners = [];
  final _alarmController = StreamController<Map<String, String>>.broadcast();

  /// Stream that emits alarm events with deviceId and deviceName
  Stream<Map<String, String>> get alarmStream => _alarmController.stream;

  /// Current alarm state
  Map<String, String>? _currentAlarm;
  Map<String, String>? get currentAlarm => _currentAlarm;

  /// Callback to notify the UI when alarm occurs (for backward compatibility)
  VoidCallback? onAlarmTriggered;

  /// Start listening to all devices for the current user
  void startListeningToAllUserDevices() {
    stopListening(); // Stop any existing listeners

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch all user devices from Firestore
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .get()
        .then((snapshot) {
          for (var doc in snapshot.docs) {
            final deviceId = doc.data()['deviceId'] as String?;
            final deviceName =
                doc.data()['name'] as String? ?? 'Unknown Device';

            if (deviceId != null) {
              _startListeningToDevice(deviceId, deviceName);
            }
          }
        })
        .catchError((error) {
          print('Error fetching user devices: $error');
          // Don't let Firestore errors crash the app
        });
  }

  /// Start listening to a specific device
  void _startListeningToDevice(String deviceId, String deviceName) {
    final listener = dbRef
        .child('Devices/$deviceId')
        .onValue
        .listen(
          (event) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;

            if (data == null) return;

            // Check if "alarm" field is true
            if (data['Alarm'] == true) {
              // Only trigger if this is a new alarm (not already triggered)
              if (_currentAlarm == null ||
                  _currentAlarm!['deviceId'] != deviceId) {
                _currentAlarm = {
                  'deviceId': deviceId,
                  'deviceName': deviceName,
                };

                // Emit alarm event (with error handling)
                try {
                  _alarmController.add(_currentAlarm!);
                } catch (e) {
                  print('Error emitting alarm event: $e');
                }

                // Send notification (fire and forget with error handling)
                Future.microtask(() async {
                  try {
                    await NotificationService().showNotification(
                      title: '🔥 Fire Alarm Triggered',
                      body: 'Fire detected by $deviceName. Please evacuate immediately!',
                      deviceId: deviceId,
                    );
                  } catch (error) {
                    print('Error showing notification: $error');
                  }
                });

                // Send SMS to emergency contacts (fire and forget with error handling)
                // Use unawaited to explicitly mark as fire-and-forget
                // Wrap in additional try-catch for extra safety
                Future.microtask(() async {
                  try {
                    await _sendAlarmSms(deviceId, deviceName);
                  } catch (error, stackTrace) {
                    print('Error in SMS sending (isolated catch): $error');
                    print('Stack trace: $stackTrace');
                    // Double safety - catch any errors that somehow got through
                  }
                });

                // Callback for backward compatibility
                try {
                  if (onAlarmTriggered != null) {
                    onAlarmTriggered!();
                  }
                } catch (e) {
                  print('Error in alarm callback: $e');
                }
              }
            } else {
              // Alarm is false, clear current alarm if it was from this device
              if (_currentAlarm != null &&
                  _currentAlarm!['deviceId'] == deviceId) {
                _currentAlarm = null;
              }
            }
          },
          onError: (error) {
            print('Realtime Database listener error: $error');
            // Don't let database errors crash the app
          },
        );

    _listeners.add(listener);
  }

  /// Send SMS to emergency contacts when alarm is triggered
  Future<void> _sendAlarmSms(String deviceId, String deviceName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('SMS Alarm: User not logged in, skipping SMS');
        return;
      }

      // Get device location from Firestore
      Map<String, double>? deviceLocation;
      try {
        final deviceDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(deviceId)
            .get()
            .timeout(const Duration(seconds: 10));

        if (deviceDoc.exists) {
          final data = deviceDoc.data()!;
          final lat = data['lat'];
          final lng = data['lng'];
          if (lat != null && lng != null) {
            deviceLocation = {
              'lat': (lat as num).toDouble(),
              'lng': (lng as num).toDouble(),
            };
          }
        }
      } on TimeoutException catch (e) {
        print('SMS Alarm: Timeout fetching device location: $e');
        // Continue without location - not critical
      } catch (e) {
        print('SMS Alarm: Error fetching device location: $e');
        // Continue without location - not critical
      }

      // Send SMS using SMS Alarm Service with timeout
      final result = await SmsAlarmService()
          .sendAlarmSms(
            deviceName: deviceName,
            deviceId: deviceId,
            deviceLocation: deviceLocation,
          )
          .timeout(const Duration(seconds: 30));

      print(
        'SMS Alarm: Sent ${result['success']} messages, '
        '${result['failed']} failed',
      );
    } on TimeoutException catch (e) {
      print('SMS Alarm: Timeout sending SMS: $e');
      // Don't rethrow - we don't want SMS errors to crash the app
    } catch (e, stackTrace) {
      print('SMS Alarm: Error sending alarm SMS: $e');
      print('SMS Alarm: Stack trace: $stackTrace');
      // Don't rethrow - we don't want SMS errors to crash the app
    }
  }

  /// Start listening to a specific device (for backward compatibility)
  void startListening(String deviceId) {
    // For backward compatibility, still support single device listening
    stopListening();

    final listener = dbRef.child('Devices/$deviceId').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) return;

      if (data['Alarm'] == true && onAlarmTriggered != null) {
        onAlarmTriggered!();
      }
    });

    _listeners.add(listener);
  }

  /// Stop listening to all devices
  void stopListening() {
    for (var listener in _listeners) {
      listener.cancel();
    }
    _listeners.clear();
    _currentAlarm = null;
  }

  /// Clear current alarm (when user acknowledges)
  void clearAlarm() {
    _currentAlarm = null;
  }

  void dispose() {
    stopListening();
    _alarmController.close();
  }
}
