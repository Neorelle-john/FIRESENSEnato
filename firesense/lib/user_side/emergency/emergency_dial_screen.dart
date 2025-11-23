import 'package:firesense/user_side/contacts/add_contact_screen.dart';
import 'package:firesense/user_side/contacts/contacts_list_screen.dart';
import 'package:firesense/user_side/devices/devices_screen.dart';
import 'package:firesense/user_side/home/home_screen.dart';
import 'package:firesense/user_side/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firesense/user_side/materials/material_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyDialScreen extends StatelessWidget {
  const EmergencyDialScreen({Key? key}) : super(key: key);

  static Future<void> _makePhoneCall(
    String phoneNumber,
    BuildContext context,
  ) async {
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
      _showPhoneNumberDialog(cleanNumber, context);
    }
  }

  static void _showPhoneNumberDialog(String phoneNumber, BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);
    final Color lightGrey = const Color(0xFFF5F5F5);
    final Color cardWhite = Colors.white;

    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: lightGrey,
        elevation: 0,
        title: const Text(
          'Emergency Dial',
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
                  builder: (context) => const ContactsListScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddContactScreen(),
                ),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListView(
          children: [
            // Card 1
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              height: 240,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/BPF.png',
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.grey,
                            ),
                            onPressed:
                                () => _makePhoneCall('(02) 8426-0246', context),
                          ),
                          SizedBox(height: 30),
                          ElevatedButton(
                            onPressed:
                                () => _makePhoneCall('(02) 8426-0246', context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 0,
                              ),
                              minimumSize: const Size(0, 32),
                              elevation: 0,
                            ),
                            child: const Text('Call'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 0),
                  const Text(
                    'Bureau of Fire Protection',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(
                    'Old Urdaneta City Hall, Urdaneta City, Philippines',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Text(
                    'Emergency Contact No.: (02) 8426-0246',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Card 2
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              height: 240,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/PNP.png',
                          width: 110,
                          height: 110,
                          fit: BoxFit.fill,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.grey,
                            ),
                            onPressed:
                                () => _makePhoneCall('(02) 8426-0246', context),
                          ),
                          SizedBox(height: 30),
                          ElevatedButton(
                            onPressed:
                                () => _makePhoneCall(
                                  '(+63) 998 598 5134',
                                  context,
                                ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 0,
                              ),
                              minimumSize: const Size(0, 32),
                              elevation: 0,
                            ),
                            child: const Text('Call'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  const Text(
                    'Philippine National Police',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(
                    'Poblacion, Urdaneta City, Philippines',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Text(
                    'Emergency Contact No.: (+63) 998 598 5134',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Card 3 - Urdaneta District Hospital
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              height: 240,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/district.png',
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.grey,
                            ),
                            onPressed:
                                () => _makePhoneCall('(02) 8426-0246', context),
                          ),
                          SizedBox(height: 30),
                          ElevatedButton(
                            onPressed:
                                () => _makePhoneCall('0943-700 5740', context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 0,
                              ),
                              minimumSize: const Size(0, 32),
                              elevation: 0,
                            ),
                            child: const Text('Call'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 0),
                  const Text(
                    'Urdaneta District Hospital',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(
                    'Urdaneta City, Philippines',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Text(
                    'Emergency Contact No.: 0943-700 5740',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Card 4 - Urdaneta Sacred Heart Hospital
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              height: 240,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/sacred.png',
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.grey,
                            ),
                            onPressed:
                                () => _makePhoneCall('(02) 8426-0246', context),
                          ),
                          SizedBox(height: 30),
                          ElevatedButton(
                            onPressed:
                                () => _makePhoneCall('(075) 203 1000', context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 0,
                              ),
                              minimumSize: const Size(0, 32),
                              elevation: 0,
                            ),
                            child: const Text('Call'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 0),
                  const Text(
                    'Urdaneta Sacred Heart Hospital',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(
                    '24-hour Emergency Service, Urdaneta City, Philippines',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Text(
                    'Emergency Contact No.: (075) 203 1000',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Card 5 - City DRRM Office
            Container(
              height: 240,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/cdmo.png',
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.grey,
                            ),
                            onPressed:
                                () => _makePhoneCall('(02) 8426-0246', context),
                          ),
                          SizedBox(height: 30),
                          ElevatedButton(
                            onPressed:
                                () => _makePhoneCall('0912 345 6789', context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 0,
                              ),
                              minimumSize: const Size(0, 32),
                              elevation: 0,
                            ),
                            child: const Text('Call'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 0),
                  const Text(
                    'City DRRM Office',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(
                    'Disaster Response & Management, Urdaneta City, Philippines',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Text(
                    'Emergency Contact No.: 0912 345 6789',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
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
          currentIndex: 3,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
            else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MaterialScreen()),
              );
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DevicesScreen()),
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
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'Materials',
            ),
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
        ),
      ),
    );
  }
}
