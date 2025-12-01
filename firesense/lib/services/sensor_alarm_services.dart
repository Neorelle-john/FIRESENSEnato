import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/services/sms_alarm_service.dart';
import 'package:firesense/services/notification_service.dart';
import 'package:firesense/services/admin_alert_service.dart';

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

  /// Track processed alarms to prevent duplicate processing
  final Set<String> _processedAlarms = {};
  Timer? _debounceTimer;

  /// Debounce delay to prevent rapid-fire alarm triggers (especially on emulator)
  static const Duration _debounceDelay = Duration(milliseconds: 2000);

  /// Maximum time for any async operation
  static const Duration _maxOperationTimeout = Duration(seconds: 15);

  /// Start listening to all devices for the current user
  void startListeningToAllUserDevices() {
    stopListening(); // Stop any existing listeners

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Sensor Alarm Service: No user logged in, cannot start listening');
      return;
    }

    print(
      'Sensor Alarm Service: Starting to listen to all devices for user ${user.uid}',
    );

    // Fetch all user devices from Firestore
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .get()
        .then((snapshot) {
          print(
            'Sensor Alarm Service: Found ${snapshot.docs.length} devices in Firestore',
          );
          if (snapshot.docs.isEmpty) {
            print(
              'Sensor Alarm Service: No devices found for user. Consider using startListeningToAllDevices() for admin.',
            );
          }
          for (var doc in snapshot.docs) {
            final deviceId = doc.data()['deviceId'] as String?;
            final deviceName =
                doc.data()['name'] as String? ?? 'Unknown Device';

            if (deviceId != null) {
              _startListeningToDevice(deviceId, deviceName);
            } else {
              print(
                'Sensor Alarm Service: Device document ${doc.id} has no deviceId',
              );
            }
          }
        })
        .catchError((error) {
          print('Sensor Alarm Service: Error fetching user devices: $error');
          // Don't let Firestore errors crash the app
        });
  }

  /// Start listening to ALL devices in RTDB (useful for admin or testing)
  /// This listens to the Devices node and monitors all devices
  void startListeningToAllDevices() {
    stopListening(); // Stop any existing listeners

    print('Sensor Alarm Service: Starting to listen to ALL devices in RTDB');

    // Listen to the entire Devices node
    final listener = dbRef
        .child('Devices')
        .onValue
        .listen(
          (event) {
            final devicesData = event.snapshot.value as Map<dynamic, dynamic>?;

            if (devicesData == null) {
              print('Sensor Alarm Service: Devices node is null');
              return;
            }

            // Check each device for alarm
            devicesData.forEach((deviceId, deviceData) {
              if (deviceData is Map) {
                final alarmValue = deviceData['Alarm'] ?? deviceData['alarm'];
                final isAlarm = alarmValue == true;

                if (isAlarm) {
                  // Get device name from Firestore if available, otherwise use deviceId
                  final deviceName =
                      deviceData['name'] as String? ?? deviceId.toString();

                  // Only trigger if this is a new alarm (not already triggered)
                  if (_currentAlarm == null ||
                      _currentAlarm!['deviceId'] != deviceId.toString()) {
                    print(
                      'Sensor Alarm Service: Alarm detected for device $deviceId via all-devices listener!',
                    );

                    // Check if we've already processed this alarm recently (debounce)
                    if (_processedAlarms.contains(deviceId.toString())) {
                      print(
                        'Sensor Alarm Service: Alarm for device $deviceId already being processed, skipping duplicate',
                      );
                      return;
                    }

                    _currentAlarm = {
                      'deviceId': deviceId.toString(),
                      'deviceName': deviceName,
                    };

                    // Mark as processing
                    _processedAlarms.add(deviceId.toString());

                    // Clear the processed flag after debounce delay
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(_debounceDelay, () {
                      _processedAlarms.remove(deviceId.toString());
                    });

                    // Emit alarm event (synchronous, non-blocking)
                    try {
                      _alarmController.add(_currentAlarm!);
                      print(
                        'Sensor Alarm Service: Alarm event emitted successfully',
                      );
                    } catch (e) {
                      print(
                        'Sensor Alarm Service: Error emitting alarm event: $e',
                      );
                    }

                    // Process alarm actions with delays to prevent overwhelming the emulator
                    _processAlarmActions(deviceId.toString(), deviceName);
                  }
                } else {
                  // Alarm is false, clear current alarm if it was from this device
                  if (_currentAlarm != null &&
                      _currentAlarm!['deviceId'] == deviceId.toString()) {
                    _currentAlarm = null;
                  }
                }
              }
            });
          },
          onError: (error) {
            print(
              'Sensor Alarm Service: Realtime Database listener error: $error',
            );
          },
        );

    _listeners.add(listener);
    print('Sensor Alarm Service: All-devices listener started');
  }

  /// Start listening to a specific device
  void _startListeningToDevice(String deviceId, String deviceName) {
    print(
      'Sensor Alarm Service: Starting to listen to device $deviceId ($deviceName)',
    );
    final listener = dbRef
        .child('Devices/$deviceId')
        .onValue
        .listen(
          (event) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;

            if (data == null) {
              print('Sensor Alarm Service: Device $deviceId data is null');
              return;
            }

            // Debug: print current alarm state
            final alarmValue = data['Alarm'];
            print(
              'Sensor Alarm Service: Device $deviceId - Alarm value: $alarmValue (type: ${alarmValue.runtimeType})',
            );

            // Check if "alarm" field is true (case-insensitive check for both 'Alarm' and 'alarm')
            final isAlarm = data['Alarm'] == true || data['alarm'] == true;
            if (isAlarm) {
              print(
                'Sensor Alarm Service: Alarm detected for device $deviceId!',
              );
              // Only trigger if this is a new alarm (not already triggered)
              if (_currentAlarm == null ||
                  _currentAlarm!['deviceId'] != deviceId) {
                print(
                  'Sensor Alarm Service: Triggering new alarm for device $deviceId',
                );

                // Check if we've already processed this alarm recently (debounce)
                if (_processedAlarms.contains(deviceId)) {
                  print(
                    'Sensor Alarm Service: Alarm for device $deviceId already being processed, skipping duplicate',
                  );
                  return;
                }

                _currentAlarm = {
                  'deviceId': deviceId,
                  'deviceName': deviceName,
                };

                // Mark as processing
                _processedAlarms.add(deviceId);

                // Clear the processed flag after debounce delay
                _debounceTimer?.cancel();
                _debounceTimer = Timer(_debounceDelay, () {
                  _processedAlarms.remove(deviceId);
                });

                // Emit alarm event (synchronous, non-blocking)
                try {
                  _alarmController.add(_currentAlarm!);
                  print(
                    'Sensor Alarm Service: Alarm event emitted successfully',
                  );
                } catch (e) {
                  print('Sensor Alarm Service: Error emitting alarm event: $e');
                }

                // Process alarm actions with delays to prevent overwhelming the emulator
                _processAlarmActions(deviceId, deviceName);
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

  /// Process alarm actions with delays to prevent overwhelming the system
  /// This method spreads out async operations to prevent blocking
  void _processAlarmActions(String deviceId, String deviceName) {
    // Check if current user is admin
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email == 'admin@gmail.com';

    // Send notification immediately (lightweight operation)
    Future.microtask(() async {
      try {
        if (isAdmin) {
          // Admin notification - more informative and action-oriented
          await NotificationService()
              .showNotification(
                title: '🚨 Alert Detected',
                body: 'Alert from $deviceName. Tap to view details.',
                deviceId: deviceId,
                isAdmin: true,
              )
              .timeout(_maxOperationTimeout);
        } else {
          // User notification - evacuation focused
          await NotificationService()
              .showNotification(
                title: '🔥 Fire Alarm Triggered',
                body:
                    'Fire detected by $deviceName. Please evacuate immediately!',
                deviceId: deviceId,
                isAdmin: false,
              )
              .timeout(_maxOperationTimeout);
        }
      } catch (error) {
        print('Sensor Alarm Service: Error showing notification: $error');
      }
    });

    // TEMPORARILY DISABLED: Send SMS after a short delay (to prevent simultaneous network calls)
    // Commented out for emulator demonstration
    // Future.delayed(const Duration(milliseconds: 500), () {
    //   Future.microtask(() async {
    //     try {
    //       final user = FirebaseAuth.instance.currentUser;
    //       if (user != null) {
    //         // Check if this device belongs to the current user (with timeout)
    //         final deviceDoc = await FirebaseFirestore.instance
    //             .collection('users')
    //             .doc(user.uid)
    //             .collection('devices')
    //             .doc(deviceId)
    //             .get()
    //             .timeout(const Duration(seconds: 5));
    //
    //         if (deviceDoc.exists) {
    //           await _sendAlarmSms(deviceId, deviceName);
    //         }
    //       }
    //     } catch (error) {
    //       print('Sensor Alarm Service: Error in SMS sending: $error');
    //     }
    //   });
    // });

    // Send alert to admin after another delay (spread out network operations)
    Future.delayed(const Duration(milliseconds: 1000), () {
      Future.microtask(() async {
        try {
          print(
            'Sensor Alarm Service: Sending admin alert for device $deviceId',
          );
          // AdminAlertService handles its own timeout, so we don't need another timeout here
          await AdminAlertService().sendAlarmAlert(
            deviceId: deviceId,
            deviceName: deviceName,
          );
          print('Sensor Alarm Service: Admin alert sent successfully');
        } catch (error, stackTrace) {
          print('Sensor Alarm Service: Admin Alert error: $error');
          print('Sensor Alarm Service: Stack trace: $stackTrace');
          // Don't rethrow - we don't want alert errors to crash the app
        }
      });
    });

    // Callback for backward compatibility (synchronous, safe)
    try {
      if (onAlarmTriggered != null) {
        onAlarmTriggered!();
      }
    } catch (e) {
      print('Sensor Alarm Service: Error in alarm callback: $e');
    }
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

      // Send SMS using SMS Alarm Service with timeout (SMS service has internal 25s timeout)
      // This outer timeout is a safety net in case the internal timeout doesn't work
      final result = await SmsAlarmService()
          .sendAlarmSms(
            deviceName: deviceName,
            deviceId: deviceId,
            deviceLocation: deviceLocation,
          )
          .timeout(const Duration(seconds: 20));

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
    print(
      'Sensor Alarm Service: Starting to listen to single device $deviceId',
    );

    final listener = dbRef
        .child('Devices/$deviceId')
        .onValue
        .listen(
          (event) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;

            if (data == null) {
              print('Sensor Alarm Service: Device $deviceId data is null');
              return;
            }

            final alarmValue = data['Alarm'] ?? data['alarm'];
            print(
              'Sensor Alarm Service: Device $deviceId - Alarm value: $alarmValue',
            );

            if (alarmValue == true) {
              print(
                'Sensor Alarm Service: Alarm detected for device $deviceId via single device listener',
              );
              if (onAlarmTriggered != null) {
                onAlarmTriggered!();
              }
            }
          },
          onError: (error) {
            print(
              'Sensor Alarm Service: Error listening to device $deviceId: $error',
            );
          },
        );

    _listeners.add(listener);
  }

  /// Start listening to a specific device by ID (useful for testing)
  void startListeningToDevice(String deviceId, {String? deviceName}) {
    print('Sensor Alarm Service: Starting to listen to device $deviceId');
    final name = deviceName ?? deviceId;
    _startListeningToDevice(deviceId, name);
  }

  /// Stop listening to all devices
  void stopListening() {
    for (var listener in _listeners) {
      listener.cancel();
    }
    _listeners.clear();
    _currentAlarm = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _processedAlarms.clear();
  }

  /// Clear current alarm (when user acknowledges)
  void clearAlarm() {
    _currentAlarm = null;
  }

  void dispose() {
    stopListening();
    _alarmController.close();
    _debounceTimer?.cancel();
  }
}
