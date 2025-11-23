import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? currentLocation;

  const EditProfileScreen({
    Key? key,
    required this.userData,
    this.currentLocation,
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _currentLocation;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _nameController.text = widget.userData['name'] ?? '';
    _emailController.text = widget.userData['email'] ?? '';
    _addressController.text = widget.userData['address'] ?? '';
    _phoneController.text = widget.userData['phone'] ?? '';
    _currentLocation = widget.currentLocation;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permissions are permanently denied');
        return;
      }

      setState(() => _isLoading = true);

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _isLoading = false;
      });

      _showSuccessSnackBar('Location updated successfully');
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error getting location: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Check if email has changed
      bool emailChanged = user.email != _emailController.text.trim();

      // Check if password is being changed
      bool passwordChanged = _passwordController.text.isNotEmpty;

      // Update email if changed
      if (emailChanged) {
        try {
          await user.updateEmail(_emailController.text.trim());
          // Re-authenticate user after email change
          await user.reload();
        } catch (emailError) {
          // If email update fails, show specific error and don't proceed with other updates
          String emailErrorMessage = 'Error updating email: $emailError';

          if (emailError.toString().contains('requires-recent-login')) {
            _showEmailUpdateDialog();
          } else if (emailError.toString().contains('email-already-in-use')) {
            emailErrorMessage =
                'This email is already in use by another account.';
            _showErrorSnackBar(emailErrorMessage);
          } else if (emailError.toString().contains('invalid-email')) {
            emailErrorMessage = 'Please enter a valid email address.';
            _showErrorSnackBar(emailErrorMessage);
          } else if (emailError.toString().contains('too-many-requests')) {
            emailErrorMessage = 'Too many requests. Please try again later.';
            _showErrorSnackBar(emailErrorMessage);
          } else {
            _showErrorSnackBar(emailErrorMessage);
          }

          setState(() => _isLoading = false);
          return; // Exit early if email update fails
        }
      }

      // Update password if provided
      if (passwordChanged) {
        await user.updatePassword(_passwordController.text);
      }

      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'address': _addressController.text.trim(),
            'phone': _phoneController.text.trim(),
            if (_currentLocation != null) 'location': _currentLocation,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Clear password fields
      _passwordController.clear();
      _confirmPasswordController.clear();

      _showSuccessSnackBar('Profile updated successfully');
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      String errorMessage = 'Error updating profile: $e';

      // Handle specific Firebase Auth errors
      if (e.toString().contains('requires-recent-login')) {
        errorMessage =
            'Please sign out and sign in again to update your email/password';
      } else if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'This email is already in use by another account';
      } else if (e.toString().contains('weak-password')) {
        errorMessage =
            'Password is too weak. Please choose a stronger password';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Please enter a valid email address';
      }

      _showErrorSnackBar(errorMessage);
    }

    setState(() => _isLoading = false);
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEmailUpdateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email Update Information'),
          content: const Text(
            'To update your email address, you may need to:\n\n'
            '1. Sign out and sign back in to refresh your authentication\n'
            '2. Ensure your current email is verified\n'
            '3. Try again after recent authentication\n\n'
            'If you continue to have issues, please contact support.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8B0000)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF8B0000),
            fontWeight: FontWeight.bold,
          ),
        ),
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
                  child: Form(
                    key: _formKey,
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

                        // Name Field
                        _buildEditableField(
                          icon: Icons.person_outline,
                          label: 'Full Name',
                          controller: _nameController,
                          hintText: 'Enter your full name',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Email Field
                        _buildEditableField(
                          icon: Icons.email_outlined,
                          label: 'Email Address',
                          controller: _emailController,
                          hintText: 'Enter your email address',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          suffixWidget: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Requires recent auth',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Phone Field
                        _buildEditableField(
                          icon: Icons.phone_outlined,
                          label: 'Phone Number',
                          controller: _phoneController,
                          hintText: 'Enter your phone number',
                          keyboardType: TextInputType.phone,
                        ),

                        const SizedBox(height: 24),

                        // Security Section
                        _buildSectionHeader('Security'),

                        // Password Field
                        _buildEditableField(
                          icon: Icons.lock_outline,
                          label: 'New Password',
                          controller: _passwordController,
                          hintText: 'Enter new password (optional)',
                          obscureText: _obscurePassword,
                          suffixWidget: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Confirm Password Field
                        _buildEditableField(
                          icon: Icons.lock_outline,
                          label: 'Confirm Password',
                          controller: _confirmPasswordController,
                          hintText: 'Confirm new password',
                          obscureText: _obscureConfirmPassword,
                          suffixWidget: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                          validator: (value) {
                            if (_passwordController.text.isNotEmpty) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Location Section
                        _buildSectionHeader('Location'),

                        // Address Field
                        _buildEditableField(
                          icon: Icons.location_on_outlined,
                          label: 'Address',
                          controller: _addressController,
                          hintText: 'Enter your address',
                          maxLines: 2,
                        ),

                        const SizedBox(height: 12),

                        // GPS Location Field
                        Container(
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
                          child: Padding(
                            padding: const EdgeInsets.all(20),
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
                                          IconButton(
                                            onPressed: _getCurrentLocation,
                                            icon: const Icon(Icons.my_location),
                                            color: primaryRed,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: primaryRed),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Color(0xFF8B0000),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryRed,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text(
                                  'Save Changes',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
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

  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    int maxLines = 1,
    Widget? suffixWidget,
    String? Function(String?)? validator,
  }) {
    final Color primaryRed = const Color(0xFF8B0000);
    final Color cardWhite = Colors.white;

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryRed, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: controller,
                    keyboardType: keyboardType,
                    obscureText: obscureText,
                    maxLines: maxLines,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: hintText,
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      suffixIcon: suffixWidget,
                    ),
                    validator: validator,
                    style: const TextStyle(color: Color(0xFF1E1E1E)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
