
import 'package:firesense/add_contact_screen.dart';
import 'package:firesense/contacts_list_screen.dart';
import 'package:firesense/home_screen.dart';
import 'package:firesense/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firesense/material_screen.dart';

class EmergencyDialScreen extends StatelessWidget {
  const EmergencyDialScreen({Key? key}) : super(key: key);

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
        title: const Text('Emergency Dial', style: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold)),
       actions: [
          IconButton(
            icon: const Icon(Icons.people, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactsListScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddContactScreen()),
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
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            onPressed: () {},
                          ),
                          SizedBox(height: 30,),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
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
                  const Text('Bureau of Fire Protection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Old Urdaneta City Hall, Urdaneta City, Philippines', style: TextStyle(fontSize: 13)),
                  const Text('Emergency Contact No.: (02) 8426-0246', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                ],
              ),
            ),
            // Card 2
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
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            onPressed: () {},
                          ),
                            SizedBox(height: 30,),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
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
                  const Text('Philippine National Police', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Poblacion, Urdaneta City, Philippines', style: TextStyle(fontSize: 13)),
                  const Text('Emergency Contact No.: (+63) 998 598 5134', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
          currentIndex: 2,
          onTap: (index) {
            if (index == 0) {
               Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MaterialScreen()),
              );
            } else if (index == 2) {
              // Already on Emergency Dial
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'Materials',
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