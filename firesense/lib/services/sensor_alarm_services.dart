import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/services/sms_alarm_service.dart';
import 'package:firesense/services/notification_service.dart';
import 'package:firesense/services/admin_alert_service.dart';

class SensorAlarmService {
  static final SensorAlarmService _instance = SensorAlarmService._internal();
  factory SensorAlarmService() => _instance;
  SensorAlarmService._internal();

  final dbRef = FirebaseDatabase.instance.ref();
  final List<StreamSubscription> _listeners = [];
  final _alarmController = StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get alarmStream => _alarmController.stream;

  Map<String, String>? _currentAlarm;
  Map<String, String>? get currentAlarm => _currentAlarm;

  VoidCallback? onAlarmTriggered;

  final Set<String> _processedAlarms = {};
  Timer? _debounceTimer;

  static const Duration _debounceDelay = Duration(milliseconds: 2000);

  static const Duration _maxOperationTimeout = Duration(seconds: 15);

  void startListeningToAllUserDevices() {
    stopListening();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Sensor Alarm Service: No user logged in, cannot start listening');
      return;
    }

    print(
      'Sensor Alarm Service: Starting to listen to all devices for user ${user.uid}',
    );

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
        });
  }

  void startListeningToAllDevices() {
    stopListening();

    print('Sensor Alarm Service: Starting to listen to ALL devices in RTDB');

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

            devicesData.forEach((deviceId, deviceData) {
              if (deviceData is Map) {
                final alarmValue = deviceData['Alarm'] ?? deviceData['alarm'];
                final isAlarm = alarmValue == true;

                if (isAlarm) {
                  final deviceName =
                      deviceData['name'] as String? ?? deviceId.toString();

                  if (_currentAlarm == null ||
                      _currentAlarm!['deviceId'] != deviceId.toString()) {
                    print(
                      'Sensor Alarm Service: Alarm detected for device $deviceId via all-devices listener!',
                    );

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

                    _processedAlarms.add(deviceId.toString());

                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(_debounceDelay, () {
                      _processedAlarms.remove(deviceId.toString());
                    });

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

                    _processAlarmActions(deviceId.toString(), deviceName);
                  }
                } else {
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

            final alarmValue = data['Alarm'];
            print(
              'Sensor Alarm Service: Device $deviceId - Alarm value: $alarmValue (type: ${alarmValue.runtimeType})',
            );

            final isAlarm = data['Alarm'] == true || data['alarm'] == true;
            if (isAlarm) {
              print(
                'Sensor Alarm Service: Alarm detected for device $deviceId!',
              );
              if (_currentAlarm == null ||
                  _currentAlarm!['deviceId'] != deviceId) {
                print(
                  'Sensor Alarm Service: Triggering new alarm for device $deviceId',
                );

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

                _processedAlarms.add(deviceId);

                _debounceTimer?.cancel();
                _debounceTimer = Timer(_debounceDelay, () {
                  _processedAlarms.remove(deviceId);
                });

                try {
                  _alarmController.add(_currentAlarm!);
                  print(
                    'Sensor Alarm Service: Alarm event emitted successfully',
                  );
                } catch (e) {
                  print('Sensor Alarm Service: Error emitting alarm event: $e');
                }

                _processAlarmActions(deviceId, deviceName);
              }
            } else {
              if (_currentAlarm != null &&
                  _currentAlarm!['deviceId'] == deviceId) {
                _currentAlarm = null;
              }
            }
          },
          onError: (error) {
            print('Realtime Database listener error: $error');
          },
        );

    _listeners.add(listener);
  }

  void _processAlarmActions(String deviceId, String deviceName) async {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email == 'admin@gmail.com';

    // Fetch sensor analysis from device's last prediction
    Map<String, dynamic>? sensorAnalysis;
    if (!isAdmin && user != null) {
      try {
        final deviceDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(deviceId)
            .get()
            .timeout(const Duration(seconds: 5));

        if (deviceDoc.exists) {
          final data = deviceDoc.data()!;
          if (data.containsKey('lastPrediction') &&
              data['lastPrediction'] != null) {
            final lastPrediction =
                data['lastPrediction'] as Map<String, dynamic>?;
            if (lastPrediction != null &&
                lastPrediction.containsKey('sensorAnalysis') &&
                lastPrediction['sensorAnalysis'] != null) {
              sensorAnalysis =
                  lastPrediction['sensorAnalysis'] as Map<String, dynamic>?;
            }
          }
        }
      } catch (e) {
        print('Sensor Alarm Service: Error fetching sensor analysis: $e');
        // Continue without sensor analysis - not critical
      }
    }

    Future.microtask(() async {
      try {
        if (isAdmin) {
          // Admin notification
          await NotificationService()
              .showNotification(
                title: '🚨 Alert Detected',
                body: 'Alert from $deviceName. Tap to view details.',
                deviceId: deviceId,
                isAdmin: true,
              )
              .timeout(_maxOperationTimeout);
        } else {
          // User notification with sensor analysis
          await NotificationService()
              .showNotification(
                title: '🔥 Fire Alarm Triggered',
                body:
                    'Fire detected by $deviceName. Please evacuate immediately!',
                deviceId: deviceId,
                isAdmin: false,
                sensorAnalysis: sensorAnalysis,
              )
              .timeout(_maxOperationTimeout);
        }
      } catch (error) {
        print('Sensor Alarm Service: Error showing notification: $error');
      }
    });
    
    if (!isAdmin) {
      Future.delayed(const Duration(milliseconds: 500), () {
        Future.microtask(() async {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              // Check if this device belongs to the current user (with timeout)
              final deviceDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('devices')
                  .doc(deviceId)
                  .get()
                  .timeout(const Duration(seconds: 5));

              if (deviceDoc.exists) {
                await _sendAlarmSms(deviceId, deviceName);
              }
            }
          } catch (error) {
            print('Sensor Alarm Service: Error in SMS sending: $error');
          }
        });
      });
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      Future.microtask(() async {
        try {
          print(
            'Sensor Alarm Service: Sending admin alert for device $deviceId',
          );
          await AdminAlertService().sendAlarmAlert(
            deviceId: deviceId,
            deviceName: deviceName,
          );
          print('Sensor Alarm Service: Admin alert sent successfully');
        } catch (error, stackTrace) {
          print('Sensor Alarm Service: Admin Alert error: $error');
          print('Sensor Alarm Service: Stack trace: $stackTrace');
        }
      });
    });

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

      // Get device location and sensor analysis from Firestore
      Map<String, double>? deviceLocation;
      Map<String, dynamic>? sensorAnalysis;
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

          // Get location
          final lat = data['lat'];
          final lng = data['lng'];
          if (lat != null && lng != null) {
            deviceLocation = {
              'lat': (lat as num).toDouble(),
              'lng': (lng as num).toDouble(),
            };
          }

          // Get sensor analysis from last prediction
          if (data.containsKey('lastPrediction') &&
              data['lastPrediction'] != null) {
            final lastPrediction =
                data['lastPrediction'] as Map<String, dynamic>?;
            if (lastPrediction != null &&
                lastPrediction.containsKey('sensorAnalysis') &&
                lastPrediction['sensorAnalysis'] != null) {
              sensorAnalysis =
                  lastPrediction['sensorAnalysis'] as Map<String, dynamic>?;
              print('SMS Alarm: Found sensor analysis for device $deviceId');
            }
          }
        }
      } on TimeoutException catch (e) {
        print('SMS Alarm: Timeout fetching device data: $e');
        // Continue without location/analysis - not critical
      } catch (e) {
        print('SMS Alarm: Error fetching device data: $e');
        // Continue without location/analysis - not critical
      }

      // Send SMS using SMS Alarm Service with timeout (SMS service has internal 25s timeout)
      // This outer timeout is a safety net in case the internal timeout doesn't work
      final result = await SmsAlarmService()
          .sendAlarmSms(
            deviceName: deviceName,
            deviceId: deviceId,
            deviceLocation: deviceLocation,
            sensorAnalysis: sensorAnalysis,
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
      try {
        listener.cancel();
      } catch (e) {
        print('Warning: Error cancelling listener in SensorAlarmService: $e');
      }
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
