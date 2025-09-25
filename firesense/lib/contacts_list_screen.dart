import 'package:flutter/material.dart';
import 'add_contact_screen.dart';

class ContactsListScreen extends StatelessWidget {
  const ContactsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);

    // Placeholder data for now. Replace with your stored contacts source.
    final List<Map<String, String>> contacts = [
      {"name": "Jon Mugcal", "phone": "+63 900 000 0001"},
      {"name": "Neollere Tougosa", "phone": "+63 900 000 0002"},
      {"name": "Jonaur Willison", "phone": "+63 900 000 0003"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts', style: TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.add, color: Colors.black87),
        //     onPressed: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (context) => const AddContactScreen()),
        //       );
        //     },
        //   ),
        // ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: contacts.isEmpty
          ? const Center(
              child: Text(
                'No contacts yet. Tap + to add one.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFD9A7A7),
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(contact["name"] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(contact["phone"] ?? ''),
                    trailing: Icon(Icons.more_vert, color: Colors.grey[600]),
                    onTap: () {},
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: contacts.length,
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddContactScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
    );
  }
} 