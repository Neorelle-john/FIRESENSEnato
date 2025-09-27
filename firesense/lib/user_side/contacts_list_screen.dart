import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/user_side/add_contact_screen.dart';
import 'package:firesense/user_side/edit_contact_screen.dart';
import 'package:flutter/material.dart';

class ContactsListScreen extends StatelessWidget {
  final VoidCallback? onContactsChanged;

  const ContactsListScreen({Key? key, this.onContactsChanged})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in.'));
    }
    final contactsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('contacts');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Contacts',
          style: TextStyle(
            color: Color(0xFF8B0000),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        iconTheme: const IconThemeData(color: Color(0xFF8B0000)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: contactsRef.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error);
            return const Center(child: Text('Error loading contacts.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No contacts yet.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final name = doc['name'] ?? '';
              final phone = doc['phone'] ?? '';
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                subtitle: Text(phone),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => EditContactScreen(
                                contactDoc: doc,
                                onContactsChanged: onContactsChanged,
                              ),
                        ),
                      );
                      if (onContactsChanged != null) onContactsChanged!();
                    } else if (value == 'delete') {
                      await contactsRef.doc(doc.id).delete();
                      if (onContactsChanged != null) onContactsChanged!();
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryRed,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      AddContactScreen(onContactsChanged: onContactsChanged),
            ),
          );
          if (onContactsChanged != null) onContactsChanged!();
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        shape: const CircleBorder(),
        tooltip: 'Add Contact',
      ),
    );
  }
}
