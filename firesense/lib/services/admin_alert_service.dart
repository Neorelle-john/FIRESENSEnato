import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Service that handles sending alerts to admin when alarms are detected
class AdminAlertService {
  static final AdminAlertService _instance = AdminAlertService._internal();
  factory AdminAlertService() => _instance;
  AdminAlertService._internal();

  // Cache admin UID to avoid repeated queries
  String? _cachedAdminUid;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidity = Duration(minutes: 5);

  /// Get admin UID by finding user with admin email
  Future<String?> _getAdminUid() async {
    try {
      // Check cache first
      if (_cachedAdminUid != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheValidity) {
        print('Admin Alert Service: Using cached admin UID');
        return _cachedAdminUid;
      }

      // First, check if current user is admin (if we're in admin context)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email == 'admin@gmail.com') {
        _cachedAdminUid = currentUser.uid;
        _cacheTimestamp = DateTime.now();
        return currentUser.uid;
      }

      // Query users collection to find admin by email
      try {
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: 'admin@gmail.com')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5));

        if (usersSnapshot.docs.isNotEmpty) {
          _cachedAdminUid = usersSnapshot.docs.first.id;
          _cacheTimestamp = DateTime.now();
          return _cachedAdminUid;
        }
      } catch (e) {
        print('Admin Alert Service: Error querying users collection: $e');
      }

      // Last resort: query all users and find admin (with timeout)
      try {
        final allUsersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .get()
            .timeout(const Duration(seconds: 5));

        for (var doc in allUsersSnapshot.docs) {
          final data = doc.data();
          if (data['email'] == 'admin@gmail.com') {
            _cachedAdminUid = doc.id;
            _cacheTimestamp = DateTime.now();
            return _cachedAdminUid;
          }
        }
      } catch (e) {
        print('Admin Alert Service: Error querying all users: $e');
      }

      print('Admin Alert Service: Admin user not found');
      return null;
    } catch (e) {
      print('Admin Alert Service: Error finding admin: $e');
      return null;
    }
  }

  /// Send alert to admin when alarm is detected
  Future<void> sendAlarmAlert({
    required String deviceId,
    required String deviceName,
  }) async {
    try {
      // Wrap entire operation in timeout to prevent hanging (increased for reliability)
      await _sendAlarmAlertInternal(
        deviceId,
        deviceName,
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      // Handle timeout gracefully - don't crash the app
      print('Admin Alert Service: Operation timed out after 30 seconds');
      print('Admin Alert Service: This is normal on slow networks/emulators');
      // Silently handle timeout - alert sending is best-effort
      return;
    } catch (e, stackTrace) {
      print('Admin Alert Service: Error sending alert: $e');
      print('Admin Alert Service: Stack trace: $stackTrace');
      // Don't rethrow - we don't want alert errors to crash the app
    }
  }

  /// Internal method to send alert (with reduced timeouts for emulator compatibility)
  Future<void> _sendAlarmAlertInternal(
    String deviceId,
    String deviceName,
  ) async {
    print('Admin Alert Service: Starting to send alert for device $deviceId');

    final adminUid = await _getAdminUid().timeout(const Duration(seconds: 10));
    if (adminUid == null) {
      print('Admin Alert Service: Cannot send alert - admin not found');
      return;
    }
    print('Admin Alert Service: Admin UID found: $adminUid');

    // Get claimedBy from Realtime Database device (with timeout)
    print('Admin Alert Service: Fetching device data from RTDB');
    final dbRef = FirebaseDatabase.instance.ref();
    final deviceSnapshot = await dbRef
        .child('Devices/$deviceId')
        .get()
        .timeout(const Duration(seconds: 10));

    if (!deviceSnapshot.exists) {
      print('Admin Alert Service: Device not found in RTDB');
      return;
    }

    final deviceData = deviceSnapshot.value as Map<dynamic, dynamic>?;
    if (deviceData == null) {
      print('Admin Alert Service: Device data is null');
      return;
    }

    // Get the claimedBy field (user ID who owns this device)
    final claimedBy = deviceData['claimedBy'] as String?;
    if (claimedBy == null || claimedBy.isEmpty) {
      print('Admin Alert Service: Device has no claimedBy field');
      return;
    }

    // Get user information from Firestore using claimedBy (with timeout)
    print('Admin Alert Service: Fetching user data for claimedBy: $claimedBy');
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(claimedBy)
        .get()
        .timeout(const Duration(seconds: 10));

    if (!userDoc.exists) {
      print(
        'Admin Alert Service: User document not found for claimedBy: $claimedBy',
      );
      return;
    }

    final userData = userDoc.data()!;
    final userName = userData['name'] ?? 'Unknown User';
    final userEmail = userData['email'] ?? '';
    final userPhone = userData['phone'] ?? '';
    final userAddress = userData['address'] ?? '';

    // Get user location (lat/lng) if available
    Map<String, double>? userLocation;
    if (userData['lat'] != null && userData['lng'] != null) {
      userLocation = {
        'lat': (userData['lat'] as num).toDouble(),
        'lng': (userData['lng'] as num).toDouble(),
      };
    }

    // Get device information from Firestore (with timeout)
    print('Admin Alert Service: Fetching device data from Firestore');
    final deviceDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(claimedBy)
        .collection('devices')
        .doc(deviceId)
        .get()
        .timeout(const Duration(seconds: 10));

    String deviceAddress = '';
    Map<String, double>? finalDeviceLocation;

    if (deviceDoc.exists) {
      final deviceFirestoreData = deviceDoc.data()!;
      deviceAddress = deviceFirestoreData['address'] ?? '';

      // Get device location from Firestore
      if (deviceFirestoreData['lat'] != null &&
          deviceFirestoreData['lng'] != null) {
        finalDeviceLocation = {
          'lat': (deviceFirestoreData['lat'] as num).toDouble(),
          'lng': (deviceFirestoreData['lng'] as num).toDouble(),
        };
      }
    }

    // Create alert document
    final alertData = {
      'userId': claimedBy,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'userAddress': userAddress,
      'userLocation':
          userLocation != null
              ? {'lat': userLocation['lat'], 'lng': userLocation['lng']}
              : null,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceAddress': deviceAddress,
      'deviceLocation':
          finalDeviceLocation != null
              ? {
                'lat': finalDeviceLocation['lat'],
                'lng': finalDeviceLocation['lng'],
              }
              : null,
      'status': 'Active', // Active, Investigating, Resolved
      'severity': 'High', // High, Medium, Low
      'type': 'fire', // fire, smoke, temperature
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Store alert in admin's alerts collection (with timeout)
    print('Admin Alert Service: Storing alert in Firestore');
    await FirebaseFirestore.instance
        .collection('admin')
        .doc(adminUid)
        .collection('alerts')
        .add(alertData)
        .timeout(const Duration(seconds: 10));

    print('Admin Alert Service: Alert sent to admin successfully');
  }

  /// Update alert status
  Future<void> updateAlertStatus({
    required String alertId,
    required String status, // Active, Investigating, Resolved
  }) async {
    try {
      final adminUid = await _getAdminUid();
      if (adminUid == null) return;

      await FirebaseFirestore.instance
          .collection('admin')
          .doc(adminUid)
          .collection('alerts')
          .doc(alertId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Admin Alert Service: Error updating alert status: $e');
    }
  }
}
