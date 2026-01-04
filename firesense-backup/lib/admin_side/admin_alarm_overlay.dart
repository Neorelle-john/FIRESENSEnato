import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Admin-specific alarm overlay widget
class AdminAlarmOverlay extends StatelessWidget {
  final String? deviceName;
  final String? deviceId;
  final VoidCallback onClose;
  final VoidCallback? onOpenAlert;

  const AdminAlarmOverlay({
    super.key,
    this.deviceName,
    this.deviceId,
    required this.onClose,
    this.onOpenAlert,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenSize.width - 48,
              maxHeight: screenSize.height * 0.9,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _fetchAlertData(deviceId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final alertData = snapshot.data;
                  final userName =
                      alertData?['userName'] as String? ?? 'Loading...';
                  final deviceLocation =
                      alertData?['deviceLocation'] as Map<String, dynamic>?;

                  // Try to get timestamp - prefer computed timestamp if available, otherwise use stored timestamp
                  Timestamp? timestamp =
                      alertData?['_computedTimestamp'] as Timestamp?;
                  if (timestamp == null) {
                    timestamp = alertData?['timestamp'] as Timestamp?;
                  }
                  if (timestamp == null) {
                    timestamp = alertData?['createdAt'] as Timestamp?;
                  }
                  // If still null, use current time
                  if (timestamp == null) {
                    timestamp = Timestamp.now();
                  }

                  String locationText = 'Not specified';
                  if (deviceLocation != null) {
                    final lat = deviceLocation['lat'];
                    final lng = deviceLocation['lng'];
                    if (lat != null && lng != null) {
                      locationText =
                          'Lat: ${(lat as num).toStringAsFixed(6)}, Lng: ${(lng as num).toStringAsFixed(6)}';
                    }
                  }

                  // Optimized timestamp calculation - timestamp is guaranteed to be non-null at this point
                  String timeText = 'Just now';
                  try {
                    final now = DateTime.now();
                    final alertTime = timestamp.toDate();

                    // Validate timestamp - if it's in the future or more than 5 minutes in the past,
                    // it might be incorrect, so use "Just now"
                    final difference = now.difference(alertTime);

                    // If timestamp is in the future or more than 5 minutes old when alert just triggered,
                    // it's likely incorrect, so show "Just now"
                    if (difference.isNegative || difference.inMinutes > 5) {
                      timeText = 'Just now';
                    } else if (difference.inSeconds < 10) {
                      timeText = 'Just now';
                    } else if (difference.inSeconds < 60) {
                      timeText =
                          '${difference.inSeconds} second${difference.inSeconds > 1 ? 's' : ''} ago';
                    } else if (difference.inMinutes < 60) {
                      timeText =
                          '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
                    } else if (difference.inHours < 24) {
                      timeText =
                          '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
                    } else {
                      timeText =
                          '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
                    }
                  } catch (e) {
                    print('Admin Alarm Overlay: Error parsing timestamp: $e');
                    timeText = 'Just now';
                  }

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Alert Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryRed.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: primaryRed,
                            size: 64,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Alert Title
                        const Text(
                          "ALERT",
                          style: TextStyle(
                            color: Color(0xFF1E1E1E),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                        const SizedBox(height: 20),
                        // Alert Message
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            deviceName != null && deviceName!.isNotEmpty
                                ? "Alert detected from $deviceName"
                                : "Alert detected from device",
                            style: const TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Alert Details Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow('User Name', userName),
                              const SizedBox(height: 12),
                              _buildDetailRow('Device Location', locationText),
                              const SizedBox(height: 12),
                              _buildDetailRow('Timestamp', timeText),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Open Alert Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (onOpenAlert != null) {
                                onOpenAlert!();
                              }
                              onClose();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              "Open Alert",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  /// Fetch alert data from Firestore based on deviceId
  Future<Map<String, dynamic>?> _fetchAlertData(String? deviceId) async {
    if (deviceId == null || deviceId.isEmpty) {
      return null;
    }

    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      return null;
    }

    try {
      // Find the most recent alert for this device
      final alertsSnapshot = await FirebaseFirestore.instance
          .collection('admin')
          .doc(adminUser.uid)
          .collection('alerts')
          .where('deviceId', isEqualTo: deviceId)
          .get()
          .timeout(const Duration(seconds: 5));

      if (alertsSnapshot.docs.isEmpty) {
        return null;
      }

      // Sort by timestamp descending (most recent first)
      final alerts = alertsSnapshot.docs.toList();
      alerts.sort((a, b) {
        // Try both timestamp and createdAt fields
        final aTimestamp =
            a.data()['timestamp'] as Timestamp? ??
            a.data()['createdAt'] as Timestamp?;
        final bTimestamp =
            b.data()['timestamp'] as Timestamp? ??
            b.data()['createdAt'] as Timestamp?;
        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;
        return bTimestamp.compareTo(aTimestamp);
      });

      final alertData = alerts.first.data();

      // If timestamp is null or seems incorrect, add current timestamp
      final timestamp =
          alertData['timestamp'] as Timestamp? ??
          alertData['createdAt'] as Timestamp?;

      // If no timestamp exists or it's more than 5 minutes old (likely incorrect),
      // add current time as a fallback
      if (timestamp == null) {
        alertData['_computedTimestamp'] = Timestamp.now();
      } else {
        final now = DateTime.now();
        final alertTime = timestamp.toDate();
        final difference = now.difference(alertTime);

        // If timestamp is more than 5 minutes old or in the future, use current time
        if (difference.inMinutes > 5 || difference.isNegative) {
          alertData['_computedTimestamp'] = Timestamp.now();
        }
      }

      return alertData;
    } catch (e) {
      print('Admin Alarm Overlay: Error fetching alert data: $e');
      return null;
    }
  }
}
