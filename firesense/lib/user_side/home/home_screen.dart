import 'package:firesense/user_side/devices/devices_screen.dart';
import 'package:firesense/user_side/devices/device_detail_screen.dart';
import 'package:firesense/user_side/devices/edit_device_screen.dart';
import 'package:firesense/user_side/materials/material_screen.dart';
import 'package:firesense/user_side/emergency/emergency_dial_screen.dart';
import 'package:firesense/user_side/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import '../contacts/contacts_list_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firesense/services/alarm_widget.dart';
import 'package:firesense/services/sensor_alarm_services.dart';
import 'package:firesense/services/fire_prediction_services.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<DocumentSnapshot>>? _contactsFuture;
  StreamSubscription? _alarmSubscription;
  bool _showAlarm = false;
  String? _alarmDeviceName;
  String? _alarmDeviceId;
  Map<String, dynamic>? _alarmSensorAnalysis;

  @override
  void initState() {
    super.initState();
    refreshContacts();

    // Initialize global alarm monitoring
    SensorAlarmService().startListeningToAllUserDevices();

    // Initialize fire prediction service and start listening to all user devices
    _initializeFirePredictionService();

    // Listen to alarm stream
    _alarmSubscription = SensorAlarmService().alarmStream.listen(
      (alarmData) async {
        if (mounted) {
          final deviceId = alarmData['deviceId'];
          final deviceName = alarmData['deviceName'];
          
          // Fetch sensor analysis for this device
          Map<String, dynamic>? sensorAnalysis;
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && deviceId != null) {
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
                  final lastPrediction = data['lastPrediction'] as Map<String, dynamic>?;
                  if (lastPrediction != null &&
                      lastPrediction.containsKey('sensorAnalysis') &&
                      lastPrediction['sensorAnalysis'] != null) {
                    sensorAnalysis = lastPrediction['sensorAnalysis'] as Map<String, dynamic>?;
                  }
                }
              }
            } catch (e) {
              print('HomeScreen: Error fetching sensor analysis: $e');
              // Continue without sensor analysis - not critical
            }
          }

          if (mounted) {
            setState(() {
              _showAlarm = true;
              _alarmDeviceName = deviceName;
              _alarmDeviceId = deviceId;
              _alarmSensorAnalysis = sensorAnalysis;
            });
          }
        }
      },
      onError: (error) {
        print('Alarm stream error in HomeScreen: $error');
        // Don't crash the app on stream errors
      },
    );
  }

  /// Initialize fire prediction service and start listening to all user devices
  Future<void> _initializeFirePredictionService() async {
    try {
      print('HomeScreen: Initializing fire prediction service...');
      await FirePredictionService().startListeningToAllUserDevices();
      print('HomeScreen: Fire prediction service initialized successfully');
    } catch (e, stackTrace) {
      print('HomeScreen: Error initializing fire prediction service: $e');
      print('Stack trace: $stackTrace');
      // Don't crash the app if prediction service fails to initialize
    }
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    // Don't stop fire prediction service here - it should run across all navigation tabs
    // The service will be stopped when user logs out or app closes
    super.dispose();
  }

  void refreshContacts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _contactsFuture = Future.value([]);
    } else {
      _contactsFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .orderBy('name')
          .get()
          .timeout(const Duration(seconds: 10))
          .then((snapshot) => snapshot.docs)
          .catchError((e) {
            print('Error loading contacts: $e');
            return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          });
    }
    setState(() {});
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Clean the phone number - remove all non-digit characters except +
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // If it starts with +63, keep it as is
    // If it starts with 63, add +
    // If it starts with 0, replace with +63
    if (cleanNumber.startsWith('+63')) {
      // Already in correct format
    } else if (cleanNumber.startsWith('63')) {
      cleanNumber = '+$cleanNumber';
    } else if (cleanNumber.startsWith('0')) {
      cleanNumber = '+63${cleanNumber.substring(1)}';
    } else {
      // For local numbers without country code, add +63
      cleanNumber = '+63$cleanNumber';
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      print('Attempting to call: $phoneNumber');
      print('Cleaned number: $cleanNumber');
      print('URI: $phoneUri');

      // Try multiple approaches for better emulator compatibility
      try {
        // First try: Direct launch with external application mode
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
        print('Launch URL successful with external application mode');
        return;
      } catch (e1) {
        print('External application mode failed: $e1');

        // Second try: Platform default mode
        try {
          await launchUrl(phoneUri);
          print('Launch URL successful with platform default mode');
          return;
        } catch (e2) {
          print('Platform default mode failed: $e2');
          throw e2;
        }
      }
    } catch (e) {
      print('All launch methods failed: $e');
      // Fallback: show a dialog with the number
      _showPhoneNumberDialog(cleanNumber);
    }
  }

  void _showPhoneNumberDialog(String phoneNumber) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Phone Number'),
          content: Text('Call: $phoneNumber'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDevicesCarousel() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final devicesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices');

    return StreamBuilder<QuerySnapshot>(
      stream: devicesRef.orderBy('created_at', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 140,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF8B0000),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            height: 140,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices_outlined,
                    size: 50,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No devices yet',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        final devices = snapshot.data!.docs;
        final deviceCount = devices.length;

        return SizedBox(
          height: 140,
          child: PageView.builder(
            itemCount: deviceCount,
            controller: PageController(viewportFraction: 1.0),
            itemBuilder: (context, index) {
              final deviceDoc = devices[index];
              final deviceData = deviceDoc.data() as Map<String, dynamic>;
              final deviceId = deviceData['deviceId'] ?? deviceDoc.id;
              final deviceName = deviceData['name'] ?? 'Unnamed Device';

              return _DeviceStatusCard(
                deviceId: deviceId,
                deviceName: deviceName,
                primaryRed: const Color(0xFF8B0000),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);
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
              'Home',
              style: TextStyle(
                color: Color(0xFF8B0000),
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.people, color: Colors.black87),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ContactsListScreen(
                            onContactsChanged: refreshContacts,
                          ),
                    ),
                  );
                },
              ),
            ],
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  // Hero Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryRed,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [primaryRed, const Color(0xFFB22222)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Welcome to FireSense',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'An IoT-Based Fire Detection application with Automated Alarm and Emergency SMS.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.white,
                          size: 52,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Devices Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Devices',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DevicesScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8B0000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Devices Carousel
                  _buildDevicesCarousel(),
                  const SizedBox(height: 28),

                  // Contacts Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Emergency Contacts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ContactsListScreen(
                                    onContactsChanged: refreshContacts,
                                  ),
                            ),
                          );
                          refreshContacts(); // Refresh contacts after returning
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8B0000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Contacts List (Firebase) - Limited to first 3
                  FutureBuilder<List<DocumentSnapshot>>(
                    future: _contactsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final allContacts = snapshot.data ?? [];
                      final contacts =
                          allContacts.take(3).toList(); // Limit to first 3

                      if (contacts.isEmpty) {
                        return Center(
                          child: Text(
                            'No contacts yet.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        );
                      }

                      return Column(
                        children:
                            contacts.map((contact) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardWhite,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: const Color(0xFFD9A7A7),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            contact['name'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            contact['phone'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                              color: Color(0xFF8B0000),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Emergency Contact',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed:
                                          () => _makePhoneCall(
                                            contact['phone'] ?? '',
                                          ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryRed,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        minimumSize: const Size(0, 32),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Call',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Hotlines',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  // Bureau of Fire Protection Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/BPF.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bureau of Fire Protection',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '(02) 8426-0246',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: Color(0xFF8B0000),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Urdaneta City, Philippines',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _makePhoneCall('(02) 8426-0246'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 32),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Call',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Philippine National Police Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/PNP.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Philippine National Police',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '0998 598 5134',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: Color(0xFF8B0000),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Urdaneta City, Philippines',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _makePhoneCall('0998 598 5134'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 32),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Call',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Urdaneta District Hospital Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/district.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Urdaneta District Hospital',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '0943 700 5740',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: Color(0xFF8B0000),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Urdaneta City, Philippines',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _makePhoneCall('0943 700 5740'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 32),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Call',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Urdaneta Sacred Heart Hospital Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/sacred.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Urdaneta Sacred Heart Hospital',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '(075) 203 1000',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: Color(0xFF8B0000),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '24-hour Emergency Service',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _makePhoneCall('(075) 203 1000'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 32),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Call',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // City Disaster Risk Reduction & Management Office Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/cdmo.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'City DRRM Office',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '0912 345 6789',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: Color(0xFF8B0000),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Disaster Response & Management',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _makePhoneCall('0912 345 6789'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 32),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Call',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: primaryRed,
              unselectedItemColor: Colors.black54,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu_book),
                  label: 'Materials',
                ),

                // 👉 NEW DEVICE TAB
                BottomNavigationBarItem(
                  icon: Icon(Icons.sensors),
                  label: 'Devices',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.phone_in_talk),
                  label: 'Emergency Dial',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
              currentIndex: 0,
              onTap: (index) {
                if (index == 1) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MaterialScreen(),
                    ),
                  );
                } else if (index == 2) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DevicesScreen(),
                    ),
                  );
                } else if (index == 3) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyDialScreen(),
                    ),
                  );
                } else if (index == 4) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                }
              },
            ),
          ),
        ),
        if (_showAlarm)
          AlarmOverlay(
            deviceName: _alarmDeviceName,
            deviceId: _alarmDeviceId,
            sensorAnalysis: _alarmSensorAnalysis,
            onClose: () {
              setState(() {
                _showAlarm = false;
                _alarmSensorAnalysis = null;
              });
              SensorAlarmService().clearAlarm();
            },
          ),
      ],
    );
  }
}

/// Widget that displays a device card with status, online/offline, and view button
class _DeviceStatusCard extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final Color primaryRed;

  const _DeviceStatusCard({
    required this.deviceId,
    required this.deviceName,
    required this.primaryRed,
  });

  @override
  State<_DeviceStatusCard> createState() => _DeviceStatusCardState();
}

class _DeviceStatusCardState extends State<_DeviceStatusCard> {
  StreamSubscription<DatabaseEvent>? _statusSubscription;
  StreamSubscription<DocumentSnapshot>? _alarmTypeSubscription;
  Timer? _onlineCheckTimer;
  bool _isOnline = false;
  String? _alarmType; // 'normal', 'smoke', 'fire', or null
  bool _testAlarm = false;
  DateTime? _lastUpdateTime;
  bool _hasReceivedInitialData = false;
  final dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _startListening();
    _startAlarmTypeListening();
    _startOnlineCheckTimer();
  }

  void _startListening() {
    final dbRef = FirebaseDatabase.instance.ref();
    _statusSubscription = dbRef
        .child('Devices/${widget.deviceId}')
        .onValue
        .listen((event) {
          if (mounted) {
            final data = event.snapshot.value;

            if (data != null && data is Map) {
              // Check test alarm status
              final testAlarm = data['TestAlarm'] == true;

              if (_hasReceivedInitialData) {
                // This is a new update after initial load - device is online
                _lastUpdateTime = DateTime.now();
                setState(() {
                  _isOnline = true;
                  _testAlarm = testAlarm;
                });
              } else {
                // First time seeing data
                _hasReceivedInitialData = true;
                setState(() {
                  _isOnline = false; // Wait for next update to confirm online
                  _testAlarm = testAlarm;
                });
              }
            } else {
              // Data is null, definitely offline
              _hasReceivedInitialData = false;
              setState(() {
                _isOnline = false;
                _testAlarm = false;
                _lastUpdateTime = null;
              });
            }
          }
        });
  }

  void _startAlarmTypeListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _alarmTypeSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(widget.deviceId)
        .snapshots()
        .listen((snapshot) {
          if (mounted && snapshot.exists) {
            final data = snapshot.data();
            final alarmType = data?['alarmType'] as String?;
            setState(() {
              _alarmType = alarmType;
            });
          } else if (mounted) {
            setState(() {
              _alarmType = null;
            });
          }
        });
  }

  void _startOnlineCheckTimer() {
    // Check every 2 seconds if device is still online
    _onlineCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_lastUpdateTime != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
        // Consider offline if no update in last 5 minutes (300 seconds)
        final shouldBeOnline = timeSinceLastUpdate.inSeconds < 300;

        if (_isOnline != shouldBeOnline) {
          setState(() {
            _isOnline = shouldBeOnline;
          });
        }
      } else if (_isOnline) {
        // No last update time but was online, mark as offline
        setState(() {
          _isOnline = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _alarmTypeSubscription?.cancel();
    _onlineCheckTimer?.cancel();
    super.dispose();
  }

  String _getDeviceStatus() {
    if (_alarmType == 'fire') {
      return 'Fire';
    } else if (_alarmType == 'smoke') {
      return 'Smoke';
    } else if (_alarmType == 'normal') {
      return 'Normal';
    } else {
      // No alarmType set yet or device offline
      return 'Unknown';
    }
  }

  Color _getStatusColor() {
    if (_alarmType == 'fire') {
      return Colors.red;
    } else if (_alarmType == 'smoke') {
      return Colors.orange; // Warning yellow/orange
    } else if (_alarmType == 'normal') {
      return Colors.green;
    } else {
      // Default to grey if no alarmType
      return Colors.grey;
    }
  }

  Future<void> _toggleTestAlarm() async {
    try {
      final newValue = !_testAlarm;
      await dbRef
          .child('Devices/${widget.deviceId}/TestAlarm')
          .set(newValue)
          .timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          _testAlarm = newValue;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue ? 'Test alarm activated' : 'Test alarm deactivated',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: widget.primaryRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToEditScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDeviceScreen(deviceId: widget.deviceId),
      ),
    );
  }

  Future<void> _disconnectDevice() async {
    // Show confirmation dialog with improved UI
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B0000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                const Text(
                  'Disconnect Device',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  'Are you sure you want to disconnect "${widget.deviceName}"?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B0000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Disconnect',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(widget.deviceId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device disconnected successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _getDeviceStatus();
    final statusColor = _getStatusColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // First Row: Device Icon, Device Name, Three-dot Menu
            Row(
              children: [
                // Device Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.sensors,
                    color: widget.primaryRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Device Name
                Expanded(
                  child: Text(
                    widget.deviceName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Three-dot menu
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: const PopupMenuThemeData(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.black54,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToEditScreen();
                      } else if (value == 'test_alarm') {
                        _toggleTestAlarm();
                      } else if (value == 'disconnect') {
                        _disconnectDevice();
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  color: Colors.black87,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Edit Device',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'test_alarm',
                            child: Row(
                              children: [
                                Icon(
                                  _testAlarm
                                      ? Icons.warning_amber_rounded
                                      : Icons.warning_outlined,
                                  color:
                                      _testAlarm
                                          ? Colors.orange
                                          : Colors.black87,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _testAlarm
                                      ? 'Deactivate Test Alarm'
                                      : 'Test Alarm',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'disconnect',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link_off,
                                  color: Color(0xFF8B0000),
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Disconnect Device',
                                  style: TextStyle(
                                    color: Color(0xFF8B0000),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Second Row: Device Status Badge and Button
            Row(
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Online/Offline Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isOnline
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              _isOnline
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // View Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                DeviceDetailsScreen(deviceId: widget.deviceId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 32),
                    elevation: 0,
                  ),
                  child: const Text('View', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
