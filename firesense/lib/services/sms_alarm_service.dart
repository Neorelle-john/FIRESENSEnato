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
  final String semaphoreApiKey = "82455a454f0ce70f298dfe2525f25b36";

  /// Send SMS to all emergency contacts when alarm is triggered
  /// Wrapped with overall timeout to prevent hanging on emulators
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
      // Wrap entire operation in timeout to prevent hanging (especially on emulators)
      return await Future.any([
        _sendAlarmSmsInternal(
          userId: user.uid,
          deviceName: deviceName,
          deviceId: deviceId,
          deviceLocation: deviceLocation,
        ),
        Future.delayed(const Duration(seconds: 25), () {
          print('SMS Service: Overall operation timed out after 25 seconds');
          return {'success': 0, 'failed': 0};
        }),
      ]);
    } on TimeoutException catch (e) {
      print('SMS Service: Timeout sending alarm SMS: $e');
      return {'success': 0, 'failed': 0};
    } catch (e, stackTrace) {
      print('SMS Service: Error in sendAlarmSms: $e');
      print('SMS Service: Stack trace: $stackTrace');
      return {'success': 0, 'failed': 0};
    }
  }

  /// Internal method to send SMS with proper timeout handling
  Future<Map<String, int>> _sendAlarmSmsInternal({
    required String userId,
    required String deviceName,
    required String deviceId,
    Map<String, double>? deviceLocation,
  }) async {
    try {
      // Fetch template and contacts with timeouts
      final messageTemplate = await _getMessageTemplate(
        userId,
      ).timeout(const Duration(seconds: 5));
      final contacts = await _getEmergencyContacts(
        userId,
      ).timeout(const Duration(seconds: 5));

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

      // Collect all valid phone numbers
      final List<String> formattedNumbers = [];

      for (final contact in contacts) {
        try {
          final phoneNumber = contact['phone'] as String?;
          final contactName = contact['name'] as String? ?? 'Contact';

          if (phoneNumber == null || phoneNumber.isEmpty) {
            print(
              'SMS Service: Skipping contact $contactName - no phone number',
            );
            continue;
          }

          final formattedNumber = _formatPhoneNumber(phoneNumber);
          if (formattedNumber.isNotEmpty) {
            formattedNumbers.add(formattedNumber);
          }
        } catch (e) {
          print('SMS Service: Error processing contact: $e');
        }
      }

      if (formattedNumbers.isEmpty) {
        print('SMS Service: No valid phone numbers found');
        return {'success': 0, 'failed': contacts.length};
      }

      // Send SMS to all contacts in a single API call
      try {
        print(
          'SMS Service: Sending to ${formattedNumbers.length} numbers: ${formattedNumbers.join(", ")}',
        );
        final result = await _sendSmsViaSemaphore(
          formattedNumbers,
          formattedMessage,
        ).timeout(const Duration(seconds: 15));

        return result;
      } on HandshakeException catch (e) {
        print('SMS Service: SSL error sending SMS: $e');
        return {'success': 0, 'failed': formattedNumbers.length};
      } on SocketException catch (e) {
        print('SMS Service: Network error sending SMS: $e');
        return {'success': 0, 'failed': formattedNumbers.length};
      } on TimeoutException catch (e) {
        print('SMS Service: Timeout sending SMS: $e');
        return {'success': 0, 'failed': formattedNumbers.length};
      } catch (e, stackTrace) {
        print('SMS Service: Error sending SMS: $e');
        print('SMS Service: Stack trace: $stackTrace');
        return {'success': 0, 'failed': formattedNumbers.length};
      }
    } on TimeoutException catch (e) {
      print('SMS Service: Timeout in internal SMS operation: $e');
      return {'success': 0, 'failed': 0};
    } catch (e, stackTrace) {
      print('SMS Service: Error in internal SMS operation: $e');
      print('SMS Service: Stack trace: $stackTrace');
      return {'success': 0, 'failed': 0};
    }
  }

  /// Fetch custom message template
  Future<String> _getMessageTemplate(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (userDoc.exists && userDoc.data()?['messageTemplate'] != null) {
        return userDoc.data()!['messageTemplate'];
      }

      return _getDefaultTemplate();
    } on TimeoutException catch (e) {
      print('SMS Service: Timeout fetching template: $e');
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
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get()
          .timeout(const Duration(seconds: 5));

      return snapshot.docs.map((doc) => doc.data()).toList();
    } on TimeoutException catch (e) {
      print('SMS Service: Timeout fetching contacts: $e');
      return [];
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
  /// Send SMS to multiple phone numbers using comma-separated format
  /// phoneNumbers: List of formatted phone numbers (e.g., ["639123456789", "639998887777"])
  /// Returns a map with success and failed counts
  Future<Map<String, int>> _sendSmsViaSemaphore(
    List<String> phoneNumbers,
    String message,
  ) async {
    try {
      // Format as comma-separated string: "639123456789,639998887777,639554443333"
      final numberString = phoneNumbers.join(',');

      print(
        "SMS Service: Sending request to Semaphore with numbers: $numberString",
      );

      // Use a shorter timeout for emulator compatibility (10 seconds)
      final response = await http
          .post(
            Uri.parse("https://semaphore.co/api/v4/messages"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "apikey": semaphoreApiKey,
              "sendername": "FireSense",
              "message": message,
              "number": numberString,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'SMS HTTP request timed out after 10 seconds',
              );
            },
          );

      print("SMS Service: Semaphore response status: ${response.statusCode}");
      print("SMS Service: Semaphore response body: ${response.body}");

      if (response.statusCode != 200) {
        print("Semaphore Error (${response.statusCode}): ${response.body}");
        return {'success': 0, 'failed': phoneNumbers.length};
      }

      final data = jsonDecode(response.body);

      // Semaphore API response formats:
      // 1. Array of results: [{"message_id": "...", "number": "...", ...}, ...]
      // 2. Single object: {"message_id": "...", ...} or {"status": "success", ...}
      // 3. Error object: {"error": "...", "message": "..."}

      // Check for error response first
      if (data is Map &&
          (data.containsKey('error') || data.containsKey('message'))) {
        final errorMsg = data['error'] ?? data['message'] ?? 'Unknown error';
        print("SMS Service: Semaphore API error: $errorMsg");
        // Check if it's a validation error that might still allow some messages
        if (errorMsg.toString().toLowerCase().contains('number format')) {
          // If it's a number format error, all failed
          return {'success': 0, 'failed': phoneNumbers.length};
        }
        return {'success': 0, 'failed': phoneNumbers.length};
      }

      // Handle array response (multiple recipients)
      if (data is List) {
        int successCount = 0;
        int failedCount = 0;

        for (var i = 0; i < data.length && i < phoneNumbers.length; i++) {
          final result = data[i];
          final number = phoneNumbers[i];

          if (result is Map) {
            // Success indicators (in order of reliability):
            // 1. message_id exists (most reliable)
            // 2. status is "success", "Queued", "Sent", or "Pending"
            // 3. No error fields present

            bool isSuccess = false;

            if (result.containsKey('message_id')) {
              isSuccess = true;
            } else if (result.containsKey('status')) {
              final status = result['status'].toString().toLowerCase();
              isSuccess =
                  status == 'success' ||
                  status == 'queued' ||
                  status == 'sent' ||
                  status == 'pending' ||
                  status == 'processing';
            } else if (!result.containsKey('error') &&
                !result.containsKey('message')) {
              // If no error fields and no explicit status, assume success
              isSuccess = true;
            }

            if (isSuccess) {
              successCount++;
              print("SMS Service: ✓ Successfully sent to $number");
            } else {
              failedCount++;
              print(
                "SMS Service: ✗ Failed to send to $number - Response: $result",
              );
            }
          } else {
            // Non-map result - treat as failure
            failedCount++;
            print(
              "SMS Service: ✗ Unexpected result format for $number: $result",
            );
          }
        }

        // If we got fewer results than numbers, assume the rest failed
        if (data.length < phoneNumbers.length) {
          failedCount += phoneNumbers.length - data.length;
          print(
            "SMS Service: Warning - Received ${data.length} results for ${phoneNumbers.length} numbers",
          );
        }

        print(
          "SMS Service: Final result - Success: $successCount, Failed: $failedCount",
        );
        return {'success': successCount, 'failed': failedCount};
      }
      // Handle single object response (all recipients in one response)
      else if (data is Map) {
        // Success indicators for single response
        bool isSuccess = false;

        if (data.containsKey('message_id')) {
          isSuccess = true;
        } else if (data.containsKey('status')) {
          final status = data['status'].toString().toLowerCase();
          isSuccess =
              status == 'success' ||
              status == 'queued' ||
              status == 'sent' ||
              status == 'pending' ||
              status == 'processing';
        } else if (!data.containsKey('error') && !data.containsKey('message')) {
          // If no error fields, assume success (HTTP 200 means request was accepted)
          isSuccess = true;
        }

        if (isSuccess) {
          print(
            "SMS Service: ✓ Single response indicates success for all ${phoneNumbers.length} numbers",
          );
          return {'success': phoneNumbers.length, 'failed': 0};
        } else {
          print("SMS Service: ✗ Single response indicates failure: $data");
          return {'success': 0, 'failed': phoneNumbers.length};
        }
      }
      // Unexpected format - but if HTTP 200, assume success (API accepted the request)
      else {
        print(
          "SMS Service: Warning - Unexpected response format, but HTTP 200. Assuming success: ${response.body}",
        );
        // Since HTTP 200 means the request was accepted, assume all succeeded
        // The actual delivery might be async, but the API accepted it
        return {'success': phoneNumbers.length, 'failed': 0};
      }
    } on HandshakeException catch (e) {
      print("SMS Service: SSL/Handshake error: $e");
      return {'success': 0, 'failed': phoneNumbers.length};
    } on SocketException catch (e) {
      print("SMS Service: Network connection error: $e");
      return {'success': 0, 'failed': phoneNumbers.length};
    } on TimeoutException catch (e) {
      print("SMS Service: Semaphore send timeout: $e");
      return {'success': 0, 'failed': phoneNumbers.length};
    } catch (e, stackTrace) {
      print("SMS Service: Semaphore send error: $e");
      print("SMS Service: Stack trace: $stackTrace");
      return {'success': 0, 'failed': phoneNumbers.length};
    }
  }

  String _formatPhoneNumber(String number) {
    // Remove all non-digit characters (including +, spaces, dashes, etc.)
    String clean = number.replaceAll(RegExp(r'[^\d]'), '');

    // If starts with 63 → keep as is (already in correct format)
    if (clean.startsWith("63")) {
      // Ensure it's exactly 12 digits (63 + 10 digits)
      if (clean.length == 12) {
        return clean;
      } else if (clean.length > 12) {
        // Take first 12 digits if longer
        return clean.substring(0, 12);
      } else {
        // If shorter, might be missing digits
        print(
          "SMS Service: Warning - number $number formatted to $clean (length: ${clean.length})",
        );
        return clean;
      }
    }

    // If starts with 0 → convert to 63
    if (clean.startsWith("0")) {
      final withoutZero = clean.substring(1);
      if (withoutZero.length == 10) {
        return "63$withoutZero";
      } else {
        print(
          "SMS Service: Warning - number $number after removing 0 has length ${withoutZero.length}",
        );
        return "63$withoutZero";
      }
    }

    // If already missing leading 0 and has 10 digits
    if (clean.length == 10) {
      return "63$clean";
    }

    // If it's 9 digits, might be missing leading 0
    if (clean.length == 9) {
      return "63$clean";
    }

    print(
      "SMS Service: Warning - number $number formatted to $clean (unexpected length: ${clean.length})",
    );
    return clean;
  }
}
