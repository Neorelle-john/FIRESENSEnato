import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firesense/user_side/emergency/emergency_dial_screen.dart';
import 'package:firesense/user_side/materials/material_screen.dart';
import 'package:firesense/user_side/settings/settings_screen.dart';

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
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Parse the existing name into first and last name
    final fullName = widget.contactDoc['name'] ?? '';
    final nameParts = fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _phoneController = TextEditingController(
      text: widget.contactDoc['phone'] ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _cleanPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except +
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

    return cleanNumber;
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    // Clean the phone number first
    String cleanNumber = _cleanPhoneNumber(phoneNumber);

    // Check if it's a valid Philippine mobile number
    // Should be +63 followed by 10 digits (total 13 characters)
    if (cleanNumber.length != 13) return false;

    // Check if it starts with +63
    if (!cleanNumber.startsWith('+63')) return false;

    // Check if the next digit is 9 (Philippine mobile numbers start with 9)
    if (cleanNumber.length >= 4 && cleanNumber[3] != '9') return false;

    return true;
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

  Future<void> _updateContact() async {
    if (!_formKey.currentState!.validate()) return;

    final firstName = _toTitleCase(_firstNameController.text.trim());
    final lastName = _toTitleCase(_lastNameController.text.trim());
    final phone = _phoneController.text.trim();

    // Combine first and last name
    final fullName = lastName.isEmpty ? firstName : '$firstName $lastName';

    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      _showErrorDialog('Not logged in.');
      return;
    }

    try {
      final contactsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('contacts');

      // Clean the phone number before saving
      final cleanPhone = _cleanPhoneNumber(phone);

      // Check if phone number already exists (excluding current contact)
      final existingContacts =
          await contactsRef.where('phone', isEqualTo: cleanPhone).get();

      if (existingContacts.docs.isNotEmpty) {
        // Check if the existing contact is not the current one being edited
        final isCurrentContact = existingContacts.docs.any(
          (doc) => doc.id == widget.contactDoc.id,
        );

        if (!isCurrentContact) {
          setState(() => _loading = false);
          final existingContact = existingContacts.docs.first.data();
          final existingName = existingContact['name'] ?? 'Unknown Contact';
          _showErrorDialog(
            'This phone number is already saved to "$existingName". Please use a different number.',
          );
          return;
        }
      }

      await contactsRef.doc(widget.contactDoc.id).update({
        'name': fullName,
        'firstName': firstName,
        'lastName': lastName,
        'phone': cleanPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _loading = false);

      _showSuccessDialog('Contact updated successfully!');
    } catch (e) {
      setState(() => _loading = false);
      _showErrorDialog('Failed to update contact. Please try again.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            contentPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            content: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon and close button
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.red.shade600,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Error',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Message content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1E1E1E),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B0000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            contentPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            content: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon and close button
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade600,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Success!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            Navigator.pop(context); // Close the dialog
                            widget.onContactsChanged
                                ?.call(); // Notify contacts list to update
                            Navigator.pop(context); // Go back to contacts list
                          },
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Message content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1E1E1E),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close the dialog
                          widget.onContactsChanged
                              ?.call(); // Notify contacts list to update
                          Navigator.pop(context); // Go back to contacts list
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: primaryRed.withOpacity(0.12),
                            child: const Icon(
                              Icons.edit,
                              color: Color(0xFF8B0000),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Update contact details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Keep your contact information accurate so we can reach them quickly.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 3,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _firstNameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'First Name *',
                              hintText: 'e.g. Juan',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              filled: true,
                              fillColor: Colors.white,
                              border: border,
                              enabledBorder: border,
                              focusedBorder: border,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'First name is required';
                              }
                              if (value.trim().length < 2) {
                                return 'First name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _lastNameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Last Name (Optional)',
                              hintText: 'e.g. Dela Cruz',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              filled: true,
                              fillColor: Colors.white,
                              border: border,
                              enabledBorder: border,
                              focusedBorder: border,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                            validator: (value) {
                              if (value != null &&
                                  value.trim().isNotEmpty &&
                                  value.trim().length < 2) {
                                return 'Last name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Phone Number *',
                              hintText: 'e.g. 09xxxxxxxxx or +63 9xx xxx xxxx',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              filled: true,
                              fillColor: Colors.white,
                              border: border,
                              enabledBorder: border,
                              focusedBorder: border,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              helperText:
                                  'Must be 11 digits (09xxxxxxxxx) or 13 digits (+63xxxxxxxxxx)',
                              helperStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Phone number is required';
                              }
                              if (!_isValidPhoneNumber(value)) {
                                return 'Please enter a valid Philippine mobile number (09xxxxxxxxx or +63xxxxxxxxxx)';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _updateContact,
                    icon:
                        _loading
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.save_outlined),
                    label: Text(
                      _loading ? 'Updating...' : 'Update Contact',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
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
