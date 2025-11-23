import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firesense/user_side/settings/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _currentLocation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Get user data from Firestore
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _emailController.text = user.email ?? '';
        _addressController.text = data['address'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _currentLocation = data['location'] ?? '';
      } else {
        // If no document exists, create one with basic info
        _nameController.text = user.displayName ?? '';
        _emailController.text = user.email ?? '';
        await _createUserDocument();
      }
    } catch (e) {
      _showErrorSnackBar('Error loading profile: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _createUserDocument() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': _nameController.text,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _navigateToEditProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Prepare user data for the edit screen
    final userData = {
      'name': _nameController.text,
      'email': _emailController.text,
      'address': _addressController.text,
      'phone': _phoneController.text,
    };

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditProfileScreen(
              userData: userData,
              currentLocation: _currentLocation,
            ),
      ),
    );

    // If the edit was successful, reload the data
    if (result == true) {
      _loadUserData();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8B0000)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF8B0000),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _navigateToEditProfile,
            child: const Text(
              'Edit',
              style: TextStyle(
                color: Color(0xFF8B0000),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Profile Header
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: primaryRed.withOpacity(0.1),
                              child: Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: primaryRed,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text
                                  : 'User',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _emailController.text,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Personal Information Section
                      _buildSectionHeader('Personal Information'),

                      // Name, Email, and Phone in a single card
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Name Field
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.person_outline,
                                      color: primaryRed,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Full Name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color(0xFF1E1E1E),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _nameController.text.isNotEmpty
                                              ? _nameController.text
                                              : 'Not provided',
                                          style: TextStyle(
                                            color:
                                                _nameController.text.isEmpty
                                                    ? Colors.grey.shade500
                                                    : const Color(0xFF1E1E1E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Divider
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(
                                color: Colors.grey.shade200,
                                height: 32,
                              ),
                            ),

                            // Email Field
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.email_outlined,
                                      color: primaryRed,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Email',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color(0xFF1E1E1E),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _emailController.text,
                                          style: const TextStyle(
                                            color: Color(0xFF1E1E1E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.lock_outline,
                                    color: Colors.grey.shade400,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),

                            // Divider
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(
                                color: Colors.grey.shade200,
                                height: 32,
                              ),
                            ),

                            // Phone Number Field
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.phone_outlined,
                                      color: primaryRed,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Phone Number',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color(0xFF1E1E1E),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _phoneController.text.isNotEmpty
                                              ? _phoneController.text
                                              : 'Not provided',
                                          style: TextStyle(
                                            color:
                                                _phoneController.text.isEmpty
                                                    ? Colors.grey.shade500
                                                    : const Color(0xFF1E1E1E),
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
                      ),

                      const SizedBox(height: 24),

                      // Location Section
                      _buildSectionHeader('Location'),

                      // Address and GPS Location in a single card
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Address Field
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.location_on_outlined,
                                      color: primaryRed,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Address',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color(0xFF1E1E1E),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _addressController.text.isNotEmpty
                                              ? _addressController.text
                                              : 'Not provided',
                                          style: TextStyle(
                                            color:
                                                _addressController.text.isEmpty
                                                    ? Colors.grey.shade500
                                                    : const Color(0xFF1E1E1E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Divider
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(
                                color: Colors.grey.shade200,
                                height: 32,
                              ),
                            ),

                            // GPS Location Field
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.gps_fixed,
                                      color: primaryRed,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Current Location',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Color(0xFF1E1E1E),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _currentLocation != null
                                              ? 'GPS coordinates'
                                              : 'Tap to get current location',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _currentLocation ?? 'Not set',
                                                style: TextStyle(
                                                  color:
                                                      _currentLocation == null
                                                          ? Colors.grey.shade500
                                                          : const Color(
                                                            0xFF1E1E1E,
                                                          ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.grey.shade800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
