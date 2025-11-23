import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
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
  bool _isLoading = false;

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

  Future<void> saveDevice() async {
    if (!_formKey.currentState!.validate()) return;

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
      body: Padding(
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
                        labelText: "Device ID (e.g., Device1)",
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
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(selectedLat!, selectedLng!),
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
                                  liteModeEnabled: true, // Static preview mode
                                ),
                              ),
                    ),
                    const SizedBox(height: 20),
                    // Location picker
                    ElevatedButton(
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

                        if (result != null) {
                          setState(() {
                            selectedLat = result.latitude;
                            selectedLng = result.longitude;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        "Set Device Location",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
                    //   ),
                  ],
                ),
              ),

              const Spacer(),

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
                          ? const CircularProgressIndicator(color: Colors.white)
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
    );
  }
}
