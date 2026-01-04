import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firesense/user_side/contacts/add_contact_screen.dart';
import 'package:firesense/user_side/contacts/edit_contact_screen.dart';
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
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Card(
                  elevation: 3,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: primaryRed.withOpacity(0.1),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: primaryRed,
                        child: Text(
                          _initialsFromName(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      _toTitleCase(name),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    subtitle: Text(
                      phone,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF606060),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 6,
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
                            PopupMenuItem(
                              value: 'edit',
                              padding: EdgeInsets.zero,
                              child: _HoverMenuChild(
                                label: 'Edit',
                                hoverBackground: primaryRed,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              padding: EdgeInsets.zero,
                              child: _HoverMenuChild(
                                label: 'Delete',
                                hoverBackground: primaryRed,
                              ),
                            ),
                          ],
                    ),
                  ),
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

String _toTitleCase(String text) {
  if (text.isEmpty) return text;

  // Split by spaces to handle multiple words (like "Juan Carlos")
  List<String> words = text.trim().split(' ');
  List<String> titleCaseWords = [];

  for (String word in words) {
    if (word.isNotEmpty) {
      // Capitalize first letter and make rest lowercase
      String titleCaseWord =
          word[0].toUpperCase() + word.substring(1).toLowerCase();
      titleCaseWords.add(titleCaseWord);
    }
  }

  return titleCaseWords.join(' ');
}

String _initialsFromName(String name) {
  final parts = name.trim().split(RegExp(r"\s+"));
  if (parts.isEmpty) return '?';
  final first = parts.first.isNotEmpty ? parts.first[0] : '';
  final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
  final result = (first + last).toUpperCase();
  return result.isEmpty ? '?' : result;
}

class _HoverMenuChild extends StatefulWidget {
  final String label;
  final Color hoverBackground;

  const _HoverMenuChild({required this.label, required this.hoverBackground});

  @override
  State<_HoverMenuChild> createState() => _HoverMenuChildState();
}

class _HoverMenuChildState extends State<_HoverMenuChild> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final Color defaultText = const Color(0xFF1E1E1E);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovering ? widget.hoverBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: _isHovering ? Colors.white : defaultText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
