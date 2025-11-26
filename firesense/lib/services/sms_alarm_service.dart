import 'dart:async';
import 'dart:convert';
import 'dart:io' show HandshakeException, SocketException;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Service that handles sending SMS messages to emergency contacts
/// using Semaphore API
class SmsAlarmService {
  static final SmsAlarmService _instance = SmsAlarmService._internal();
  factory SmsAlarmService() => _instance;
  SmsAlarmService._internal();

  /// 🔐 Add your SEMAPHORE API KEY here
  final String semaphoreApiKey = "587a6c6f530b1a22926bf5568ee84e8c";

  /// Send SMS to all emergency contacts when alarm is triggered
  Future<Map<String, int>> sendAlarmSms({
    required String deviceName,
    required String deviceId,
    Map<String, double>? deviceLocation,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('SMS Service: User not logged in');
      return {'success': 0, 'failed': 0};
    }

    try {
      final messageTemplate = await _getMessageTemplate(user.uid);
      final contacts = await _getEmergencyContacts(user.uid);

      if (contacts.isEmpty) {
        print('SMS Service: No emergency contacts found');
        return {'success': 0, 'failed': 0};
      }

      final formattedMessage = _formatMessage(
        template: messageTemplate,
        deviceName: deviceName,
        deviceId: deviceId,
        deviceLocation: deviceLocation,
      );

      int successCount = 0;
      int failedCount = 0;

      for (final contact in contacts) {
        try {
          final phoneNumber = contact['phone'] as String?;
          final contactName = contact['name'] as String? ?? 'Contact';

          if (phoneNumber == null || phoneNumber.isEmpty) {
            print(
              'SMS Service: Skipping contact $contactName - no phone number',
            );
            failedCount++;
            continue;
          }

          try {
            final success = await _sendSmsViaSemaphore(
              phoneNumber,
              formattedMessage,
            );

            if (success) {
              successCount++;
              print('SMS Service: SMS sent to $contactName ($phoneNumber)');
            } else {
              failedCount++;
              print('SMS Service: FAILED to send SMS to $contactName');
            }
          } on HandshakeException catch (e) {
            failedCount++;
            print('SMS Service: SSL error sending to $contactName: $e');
          } on SocketException catch (e) {
            failedCount++;
            print('SMS Service: Network error sending to $contactName: $e');
          } catch (e, stackTrace) {
            failedCount++;
            print('SMS Service: Error sending SMS to $contactName: $e');
            print('SMS Service: Stack trace: $stackTrace');
          }
        } catch (e) {
          // Extra safety net - catch any errors in processing contacts
          failedCount++;
          print('SMS Service: Error processing contact: $e');
        }
      }

      return {'success': successCount, 'failed': failedCount};
    } catch (e) {
      print('SMS Service: Error in sendAlarmSms: $e');
      return {'success': 0, 'failed': 0};
    }
  }

  /// Fetch custom message template
  Future<String> _getMessageTemplate(String userId) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (userDoc.exists && userDoc.data()?['messageTemplate'] != null) {
        return userDoc.data()!['messageTemplate'];
      }

      return _getDefaultTemplate();
    } catch (e) {
      print('SMS Service: Error fetching template: $e');
      return _getDefaultTemplate();
    }
  }

  /// Fetch stored emergency contacts
  Future<List<Map<String, dynamic>>> _getEmergencyContacts(
    String userId,
  ) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('contacts')
              .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('SMS Service: Error fetching contacts: $e');
      return [];
    }
  }

  /// Format message with replacements
  String _formatMessage({
    required String template,
    required String deviceName,
    required String deviceId,
    Map<String, double>? deviceLocation,
  }) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    String location = 'Not specified';

    if (deviceLocation != null &&
        deviceLocation.containsKey('lat') &&
        deviceLocation.containsKey('lng')) {
      final lat = deviceLocation['lat']!;
      final lng = deviceLocation['lng']!;
      location =
          'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
    }

    return template
        .replaceAll('[DEVICE_NAME]', deviceName)
        .replaceAll('[DEVICE_ID]', deviceId)
        .replaceAll('[LOCATION]', location)
        .replaceAll('[TIME]', time)
        .replaceAll('[DATE]', date);
  }

  /// Default emergency message body
  String _getDefaultTemplate() {
    return '''EMERGENCY ALERT

This is an automated emergency message from FireSense.

I may be in danger and need immediate assistance.

Device: [DEVICE_NAME]
Device ID: [DEVICE_ID]
Location: [LOCATION]
Time: [TIME]
Date: [DATE]''';
  }

  // ------------------------------------------------------------------------
  // 🚀 SEMAPHORE SMS API SENDER
  // ------------------------------------------------------------------------
  Future<bool> _sendSmsViaSemaphore(String phoneNumber, String message) async {
    try {
      final formattedNumber = _formatPhoneNumber(phoneNumber);

      final response = await http
          .post(
            Uri.parse("https://semaphore.co/api/v4/messages"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "apikey": semaphoreApiKey,
              "sendername": "Click2Serve",
              "message": message,
              "recipient": [formattedNumber],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print("Semaphore Error (${response.statusCode}): ${response.body}");
        return false;
      }

      final data = jsonDecode(response.body);

      // Expecting list: [{"status": "success", ...}]
      if (data is List && data.isNotEmpty) {
        return data[0]["status"] == "success";
      } else {
        print("SMS Service: Unexpected response: ${response.body}");
        return false;
      }
    } on HandshakeException catch (e) {
      print("SMS Service: SSL/Handshake error: $e");
      return false;
    } on SocketException catch (e) {
      print("SMS Service: Network connection error: $e");
      return false;
    } on TimeoutException catch (e) {
      print("SMS Service: Semaphore send timeout: $e");
      return false;
    } catch (e, stackTrace) {
      print("SMS Service: Semaphore send error: $e");
      print("SMS Service: Stack trace: $stackTrace");
      return false;
    }
  }

  /// Fix phone number formatting for Philippines
  String _formatPhoneNumber(String number) {
    String clean = number.replaceAll(RegExp(r'[^\d+]'), '');

    if (clean.startsWith("+63")) return clean;
    if (clean.startsWith("63")) return "+$clean";
    if (clean.startsWith("0")) return "+63${clean.substring(1)}";

    return "+63$clean";
  }
}
