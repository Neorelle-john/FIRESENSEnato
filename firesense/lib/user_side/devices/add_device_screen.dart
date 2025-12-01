import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // FIXED

import 'location_picker_screen.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isLoading = false;
  bool _isGeocoding = false;

  double? selectedLat;
  double? selectedLng;

  final _formKey = GlobalKey<FormState>();

  Future<void> pickLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location services are disabled.")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied.")),
          );
          return;
        }
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        selectedLat = pos.latitude;
        selectedLng = pos.longitude;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error getting location: $e")));
    }
  }

  Future<void> geocodeAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter an address.")));
      return;
    }

    setState(() => _isGeocoding = true);

    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          selectedLat = location.latitude;
          selectedLng = location.longitude;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Location found: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}",
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Could not find location for this address. Please try a more specific address.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error geocoding address: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  Future<void> saveDevice() async {
    if (!_formKey.currentState!.validate()) return;

    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter an address.")));
      return;
    }

    if (selectedLat == null || selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please set the device location.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in.")));
      setState(() => _isLoading = false);
      return;
    }

    final deviceId = _deviceIdController.text.trim();
    final deviceName = _deviceNameController.text.trim();

    try {
      // Check if device exists in Realtime Database
      final dbRef = FirebaseDatabase.instance.ref().child("Devices/$deviceId");

      final snapshot = await dbRef.get();
      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Device ID '$deviceId' not found in database."),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Check if user already has this device in Firestore
      final existingDevice =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('devices')
              .doc(deviceId)
              .get();

      if (existingDevice.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This device is already in your account.'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Check if device is already claimed by another user using transaction
      // This prevents race conditions where two users try to claim the same device
      final claimedRef = dbRef.child('claimedBy');
      final claimedSnapshot = await claimedRef.get();

      print('DEBUG: Checking claimedBy at path: Devices/$deviceId/claimedBy');
      print('DEBUG: claimedSnapshot.exists: ${claimedSnapshot.exists}');
      print('DEBUG: User ID: ${user.uid}');

      if (claimedSnapshot.exists) {
        final claimedByUserId = claimedSnapshot.value as String?;
        print('DEBUG: Device is already claimed by: $claimedByUserId');
        if (claimedByUserId != null && claimedByUserId != user.uid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This device is already claimed by another user. '
                'You cannot add it to your account.',
              ),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        // Device is already claimed by current user - proceed to add to Firestore
        print('DEBUG: Device already claimed by current user, proceeding...');
      } else {
        // Device is not claimed yet - claim it atomically for this user
        print(
          'DEBUG: Device not claimed yet, claiming for user ${user.uid}...',
        );
        try {
          await claimedRef.set(user.uid).timeout(const Duration(seconds: 5));
          print(
            'DEBUG: Successfully set claimedBy to ${user.uid} for device $deviceId',
          );
        } catch (e, stackTrace) {
          print('ERROR: Failed to set claimedBy field: $e');
          print('ERROR: Stack trace: $stackTrace');
          // Re-throw to be caught by outer catch block
          throw Exception('Failed to claim device: $e');
        }
      }

      print('DEBUG: About to save device to Firestore...');

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .set({
            'deviceId': deviceId,
            'name': deviceName,
            'lat': selectedLat,
            'lng': selectedLng,
            'address': address,
            'created_at': DateTime.now(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Device added successfully!")),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving device: $e")));
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);
    final Color bgGrey = const Color(0xFFF5F5F5);
    final Color cardWhite = Colors.white;

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: bgGrey,
        elevation: 0,
        title: const Text(
          "Add Device",
          style: TextStyle(
            color: Color(0xFF8B0000),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Device Name
                      TextFormField(
                        controller: _deviceNameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Device Name cannot be empty";
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: "Device Name",
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(
                            Icons.library_books_outlined,
                            color: Colors.black54,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Colors.black26),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: primaryRed, width: 2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Device ID
                      TextFormField(
                        controller: _deviceIdController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Device ID cannot be empty";
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: "Device ID",
                          labelStyle: const TextStyle(color: Colors.black54),
                          prefixIcon: const Icon(
                            Icons.info_rounded,
                            color: Colors.black54,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Colors.black26),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: primaryRed, width: 2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Address Field for Geocoding
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _addressController,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Address is required";
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: "Enter Address *",
                                hintText:
                                    "123 Street, Purok, Brgy, Municipality, Province",
                                labelStyle: const TextStyle(
                                  color: Colors.black54,
                                ),
                                prefixIcon: const Icon(
                                  Icons.location_city,
                                  color: Colors.black54,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Colors.black26,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: primaryRed,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isGeocoding ? null : geocodeAddress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child:
                                _isGeocoding
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Icon(Icons.search, size: 24),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // MINI MAP PREVIEW
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.grey[200],
                        ),
                        child:
                            selectedLat == null || selectedLng == null
                                ? const Center(
                                  child: Text(
                                    "Location not set",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                )
                                : ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: GoogleMap(
                                    key: ValueKey(
                                      '${selectedLat!.toStringAsFixed(6)}_${selectedLng!.toStringAsFixed(6)}',
                                    ), // Force rebuild when location changes
                                    initialCameraPosition: CameraPosition(
                                      target: LatLng(
                                        selectedLat!,
                                        selectedLng!,
                                      ),
                                      zoom: 15,
                                    ),
                                    markers: {
                                      Marker(
                                        markerId: const MarkerId("selected"),
                                        position: LatLng(
                                          selectedLat!,
                                          selectedLng!,
                                        ),
                                      ),
                                    },
                                    zoomControlsEnabled: false,
                                    myLocationButtonEnabled: false,
                                    scrollGesturesEnabled: false,
                                    rotateGesturesEnabled: false,
                                    tiltGesturesEnabled: false,
                                    zoomGesturesEnabled: false,
                                    mapToolbarEnabled: false,
                                  ),
                                ),
                      ),
                      const SizedBox(height: 20),
                      // Location picker
                      OutlinedButton.icon(
                        onPressed: () async {
                          final LatLng? result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => LocationPickerScreen(
                                    initialLat: selectedLat,
                                    initialLng: selectedLng,
                                  ),
                            ),
                          );

                          if (result != null && mounted) {
                            setState(() {
                              selectedLat = result.latitude;
                              selectedLng = result.longitude;
                            });
                          }
                        },
                        icon: const Icon(Icons.location_on, size: 20),
                        label: const Text(
                          "Set Device Location",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryRed,
                          side: BorderSide(color: primaryRed, width: 1.5),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // if (selectedLat != null && selectedLng != null)
                      //   Text(
                      //     "Location: (${selectedLat!.toStringAsFixed(5)}, ${selectedLng!.toStringAsFixed(5)})",
                      //     style: const TextStyle(
                      //       fontSize: 14,
                      //       fontWeight: FontWeight.w600,
                      //     ),
                      //                       ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : saveDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              "Save Device",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
