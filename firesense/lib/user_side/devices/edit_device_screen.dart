import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'location_picker_screen.dart';

class EditDeviceScreen extends StatefulWidget {
  final String deviceId;

  const EditDeviceScreen({super.key, required this.deviceId});

  @override
  State<EditDeviceScreen> createState() => _EditDeviceScreenState();
}

class _EditDeviceScreenState extends State<EditDeviceScreen> {
  final TextEditingController _deviceNameController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingData = true;

  double? selectedLat;
  double? selectedLng;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadDeviceData();
  }

  Future<void> _loadDeviceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("User not logged in.")));
        Navigator.pop(context);
      }
      return;
    }

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('devices')
              .doc(widget.deviceId)
              .get();

      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        setState(() {
          _deviceNameController.text = data['name'] ?? '';
          selectedLat = data['lat']?.toDouble();
          selectedLng = data['lng']?.toDouble();
          _isLoadingData = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Device not found.")));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading device: $e")));
        Navigator.pop(context);
      }
    }
  }

  Future<void> updateDevice() async {
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

    final deviceName = _deviceNameController.text.trim();

    try {
      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(widget.deviceId)
          .update({'name': deviceName, 'lat': selectedLat, 'lng': selectedLng});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Device updated successfully!")),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating device: $e")));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);
    final Color bgGrey = const Color(0xFFF5F5F5);
    final Color cardWhite = Colors.white;

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: bgGrey,
        appBar: AppBar(
          backgroundColor: bgGrey,
          elevation: 0,
          title: const Text(
            "Edit Device",
            style: TextStyle(
              color: Color(0xFF8B0000),
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: bgGrey,
        elevation: 0,
        title: const Text(
          "Edit Device",
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

                    // Device ID (Read-only)
                    TextFormField(
                      initialValue: widget.deviceId,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: "Device ID",
                        labelStyle: const TextStyle(color: Colors.black54),
                        prefixIcon: const Icon(
                          Icons.info_rounded,
                          color: Colors.black54,
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Colors.black26),
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
                                  key: ValueKey(
                                    '${selectedLat!.toStringAsFixed(6)}_${selectedLng!.toStringAsFixed(6)}',
                                  ), // Force rebuild when location changes
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
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : updateDevice,
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
                            "Update Device",
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
