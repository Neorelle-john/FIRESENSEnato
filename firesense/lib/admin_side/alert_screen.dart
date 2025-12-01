import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firesense/services/admin_alert_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminAlertScreen extends StatefulWidget {
  const AdminAlertScreen({Key? key}) : super(key: key);

  @override
  State<AdminAlertScreen> createState() => _AdminAlertScreenState();
}

class _AdminAlertScreenState extends State<AdminAlertScreen> {
  /// Static method to show alert details from anywhere
  static void showAlertDetails(
    BuildContext context,
    Map<String, dynamic> alert,
    String alertId,
  ) {
    _showAlertDetailsStatic(context, alert, alertId);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);
    const Color lightGrey = Color(0xFFF5F5F5);

    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      return Scaffold(
        backgroundColor: lightGrey,
        appBar: AppBar(
          backgroundColor: primaryRed,
          elevation: 0,
          title: const Text(
            'Alert Management',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: Text('Please log in to view alerts')),
      );
    }

    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: primaryRed,
        elevation: 0,
        title: const Text(
          'Alert Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {
                // Refresh alerts
                setState(() {});
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Refresh Alerts',
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('admin')
                .doc(adminUser.uid)
                .collection('alerts')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading alerts: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Column(
              children: [
                // Header Stats
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryRed, Color(0xFFB22222)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryRed.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Active Alerts',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '0',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.warning_amber_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildEmptyState()),
              ],
            );
          }

          final alerts = snapshot.data!.docs;
          final activeAlerts =
              alerts.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] != 'Resolved';
              }).length;

          return Column(
            children: [
              // Header Stats
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryRed, Color(0xFFB22222)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryRed.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Alerts',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$activeAlerts',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_amber_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),

              // Alerts List
              Expanded(
                child: ListView.builder(
                  itemCount: alerts.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final alertDoc = alerts[index];
                    final alert = alertDoc.data() as Map<String, dynamic>;
                    return _buildAlertCard(alert, alertDoc.id);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No active alerts at this time',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, String alertId) {
    const Color primaryRed = Color(0xFF8B0000);

    final status = alert['status'] as String? ?? 'Active';
    final deviceName = alert['deviceName'] as String? ?? 'Unknown Device';
    final userName = alert['userName'] as String? ?? 'Unknown User';
    final timestamp = alert['timestamp'] as Timestamp?;

    // Use fire icon for all alerts
    const alertIcon = Icons.local_fire_department;
    const alertIconColor = Colors.red;

    Color statusColor;
    switch (status) {
      case 'Active':
        statusColor = Colors.red;
        break;
      case 'Investigating':
        statusColor = Colors.orange;
        break;
      case 'Resolved':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    String timeAgo = 'Just now';
    if (timestamp != null) {
      final now = DateTime.now();
      final alertTime = timestamp.toDate();
      final difference = now.difference(alertTime);

      if (difference.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes} mins ago';
      } else if (difference.inHours < 24) {
        timeAgo =
            '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else {
        timeAgo =
            '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          _showAlertDetails(context, alert, alertId);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: alertIconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      alertIcon,
                      color: alertIconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fire Alarm - $deviceName',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'User: $userName',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status text in top right (no background, just colored text)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Time in bottom left
                  Text(
                    timeAgo,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const Spacer(),
                  // View Details button in bottom right with red background
                  ElevatedButton.icon(
                    onPressed: () {
                      _showAlertDetails(context, alert, alertId);
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlertDetails(
    BuildContext context,
    Map<String, dynamic> alert,
    String alertId,
  ) {
    _showAlertDetailsStatic(context, alert, alertId);
  }

  static void _showAlertDetailsStatic(
    BuildContext context,
    Map<String, dynamic> alert,
    String alertId,
  ) {
    const Color primaryRed = Color(0xFF8B0000);

    final deviceName = alert['deviceName'] as String? ?? 'Unknown Device';
    final deviceId = alert['deviceId'] as String? ?? 'Unknown';
    final deviceAddress = alert['deviceAddress'] as String? ?? 'Not specified';
    final deviceLocation = alert['deviceLocation'] as Map<String, dynamic>?;

    final userName = alert['userName'] as String? ?? 'Unknown User';
    final userEmail = alert['userEmail'] as String? ?? 'Not specified';
    final userPhone = alert['userPhone'] as String? ?? 'Not specified';
    final userAddress = alert['userAddress'] as String? ?? 'Not specified';
    final userLocation = alert['userLocation'] as Map<String, dynamic>?;

    final status = alert['status'] as String? ?? 'Active';
    final timestamp = alert['timestamp'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryRed, Color(0xFFB22222)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alert Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (timestamp != null)
                              Text(
                                '${timestamp.toDate().toString().substring(0, 19)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Section
                        _buildDetailSection('Status', [
                          _buildDetailRow(
                            'Current Status',
                            status,
                            status == 'Active'
                                ? Colors.red
                                : status == 'Investigating'
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // User Information Section
                        _buildDetailSection('User Information', [
                          _buildDetailRow('Name', userName),
                          _buildDetailRow('Email', userEmail),
                          _buildDetailRow('Phone', userPhone),
                          _buildDetailRow('Address', userAddress),
                          if (userLocation != null)
                            _buildDetailRow(
                              'Location',
                              'Lat: ${userLocation['lat']?.toStringAsFixed(6) ?? 'N/A'}, Lng: ${userLocation['lng']?.toStringAsFixed(6) ?? 'N/A'}',
                            ),
                        ]),

                        const SizedBox(height: 24),

                        // Device Information Section
                        _buildDetailSection('Device Information', [
                          _buildDetailRow('Device Name', deviceName),
                          _buildDetailRow('Device ID', deviceId),
                          _buildDetailRow('Device Address', deviceAddress),
                          if (deviceLocation != null)
                            _buildDetailRow(
                              'Device Location',
                              'Lat: ${deviceLocation['lat']?.toStringAsFixed(6) ?? 'N/A'}, Lng: ${deviceLocation['lng']?.toStringAsFixed(6) ?? 'N/A'}',
                            ),
                          if (deviceLocation != null) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 200,
                                width: double.infinity,
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                      (deviceLocation['lat'] as num).toDouble(),
                                      (deviceLocation['lng'] as num).toDouble(),
                                    ),
                                    zoom: 15,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId(
                                        'device_location',
                                      ),
                                      position: LatLng(
                                        (deviceLocation['lat'] as num)
                                            .toDouble(),
                                        (deviceLocation['lng'] as num)
                                            .toDouble(),
                                      ),
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueRed,
                                          ),
                                    ),
                                  },
                                  zoomControlsEnabled: false,
                                  myLocationButtonEnabled: false,
                                  scrollGesturesEnabled: true,
                                  rotateGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  zoomGesturesEnabled: true,
                                  mapToolbarEnabled: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _openInGoogleMaps(
                                    context,
                                    (deviceLocation['lat'] as num).toDouble(),
                                    (deviceLocation['lng'] as num).toDouble(),
                                  );
                                },
                                icon: const Icon(Icons.map, size: 18),
                                label: const Text('Open in Google Maps'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B0000),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ]),

                        const SizedBox(height: 24),

                        // Actions
                        if (status != 'Resolved') ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _updateAlertStatusStatic(
                                      context,
                                      alertId,
                                      'Investigating',
                                    );
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.search, size: 18),
                                  label: const Text('Mark as Investigating'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B0000),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _updateAlertStatusStatic(
                                      context,
                                      alertId,
                                      'Resolved',
                                    );
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                  ),
                                  label: const Text('Mark as Resolved'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B0000),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  static Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0000),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  static Widget _buildDetailRow(
    String label,
    String value, [
    Color? valueColor,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black87,
                fontWeight:
                    valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _updateAlertStatusStatic(
    BuildContext context,
    String alertId,
    String status,
  ) {
    AdminAlertService().updateAlertStatus(alertId: alertId, status: status);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alert status updated to $status'),
        backgroundColor: const Color(0xFF8B0000),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Future<void> _openInGoogleMaps(
    BuildContext context,
    double lat,
    double lng,
  ) async {
    try {
      // Try to open Google Maps app first using geo: scheme
      final googleMapsAppUrl = Uri.parse("geo:$lat,$lng?q=$lat,$lng(Device)");

      // Fallback to web URL if app is not available
      final googleMapsWebUrl = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
      );

      // Check if we can launch the app URL
      if (await canLaunchUrl(googleMapsAppUrl)) {
        await launchUrl(googleMapsAppUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web URL
        if (await canLaunchUrl(googleMapsWebUrl)) {
          await launchUrl(
            googleMapsWebUrl,
            mode: LaunchMode.externalApplication,
          );
        } else {
          // If neither works, show error message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open Google Maps. Please install Google Maps app or check your internet connection.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error opening Google Maps: $e');
      // Show user-friendly error message without hanging the app
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Google Maps. Please try again later.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Helper class to expose alert details functionality
class AdminAlertHelper {
  /// Show alert details from anywhere in the app
  static void showAlertDetails(
    BuildContext context,
    Map<String, dynamic> alert,
    String alertId,
  ) {
    _AdminAlertScreenState.showAlertDetails(context, alert, alertId);
  }
}
