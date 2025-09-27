import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firesense/user_side/emergency_dial_screen.dart';
import 'package:firesense/user_side/material_screen.dart';
import 'package:firesense/user_side/settings_screen.dart';

class EditContactScreen extends StatefulWidget {
  final DocumentSnapshot contactDoc;
  final VoidCallback? onContactsChanged;

  const EditContactScreen({
    Key? key,
    required this.contactDoc,
    this.onContactsChanged,
  }) : super(key: key);

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.contactDoc['name'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.contactDoc['phone'] ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateContact() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) return;

    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not logged in.')));
      return;
    }

    final contactsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('contacts');

    await contactsRef.doc(widget.contactDoc.id).update({
      'name': name,
      'phone': phone,
    });
    setState(() => _loading = false);

    widget.onContactsChanged?.call(); // Notify contacts list to update

    Navigator.pop(context); // Go back to contacts list
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);
    final Color bgGrey = const Color(0xFFF5F5F5);
    final Color cardWhite = Colors.white;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.grey, width: 1),
    );

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: bgGrey,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8B0000)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Contact',
          style: TextStyle(
            color: Color(0xFF8B0000),
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Contact Name',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: cardWhite,
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: 'Contact Number',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: cardWhite,
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _updateContact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            'Update Contact',
                            style: TextStyle(fontSize: 16),
                          ),
                ),
              ),
              const SizedBox(height: 32),
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
