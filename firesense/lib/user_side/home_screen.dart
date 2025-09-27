import 'package:firesense/user_side/material_screen.dart';
import 'package:firesense/user_side/emergency_dial_screen.dart';
import 'package:firesense/user_side/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firesense/user_side/add_contact_screen.dart';
import 'contacts_list_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _contactsPageController = PageController(
    viewportFraction: 0.88,
  );
  int _currentContactsPage = 0;
  Future<List<DocumentSnapshot>>? _contactsFuture;

  @override
  void initState() {
    super.initState();
    refreshContacts();
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
          .then((snapshot) => snapshot.docs);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _contactsPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);
    final Color lightRed = const Color(0xFFD9A7A7);
    final Color bgGrey = const Color(0xFFF5F5F5);
    final Color cardWhite = Colors.white;

    return Scaffold(
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
                  builder: (context) => ContactsListScreen(onContactsChanged: refreshContacts),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.black87),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddContactScreen(onContactsChanged: refreshContacts),
                ),
              );
              refreshContacts(); // Refresh contacts after adding
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Hero Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Quickly reach your emergency contacts and hotlines.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 48,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Contacts Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Contacts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactsListScreen(),
                        ),
                      );
                    },
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Contacts Slider (Firebase)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(
                  height: 140,
                  child: FutureBuilder<List<DocumentSnapshot>>(
                    future: _contactsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final contacts = snapshot.data ?? [];
                      if (contacts.isEmpty) {
                        return Center(
                          child: Text(
                            'No contacts yet.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        );
                      }
                      if (contacts.length == 1) {
                        final contact = contacts.first;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                                radius: 26,
                                backgroundColor: const Color(0xFFD9A7A7),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      contact['name'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      contact['phone'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.phone,
                                  color: const Color(0xFF8B0000),
                                ),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        );
                      } else {
                        return PageView.builder(
                          controller: _contactsPageController,
                          itemCount: contacts.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentContactsPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final contact = contacts[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                left: index == 0 ? 0 : 8,
                                right: index == contacts.length - 1 ? 0 : 8,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
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
                                      radius: 26,
                                      backgroundColor: const Color(0xFFD9A7A7),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            contact['name'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            contact['phone'] ?? '',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.phone,
                                        color: const Color(0xFF8B0000),
                                      ),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Dots indicator (dynamic)
              FutureBuilder<List<DocumentSnapshot>>(
                future: _contactsFuture,
                builder: (context, snapshot) {
                  final contacts = snapshot.data ?? [];
                  if (contacts.length <= 1) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      contacts.length,
                      (dotIndex) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              dotIndex == _currentContactsPage
                                  ? Colors.black87
                                  : Colors.black26,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Hotlines',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              // Hotline 1
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
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
                      backgroundColor: lightRed,
                      child: const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '(02) 8426-0246',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.call, color: primaryRed),
                      label: Text('Call', style: TextStyle(color: primaryRed)),
                      style: TextButton.styleFrom(foregroundColor: primaryRed),
                    ),
                  ],
                ),
              ),
              // Hotline 2
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
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
                      backgroundColor: lightRed,
                      child: const Icon(Icons.local_phone, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '(+63) 998 598 5134',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.call, color: primaryRed),
                      label: Text('Call', style: TextStyle(color: primaryRed)),
                      style: TextButton.styleFrom(foregroundColor: primaryRed),
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
                MaterialPageRoute(builder: (context) => const MaterialScreen()),
              );
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencyDialScreen(),
                ),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }
            // You can add navigation for other tabs as needed
          },
        ),
      ),
    );
  }
}
