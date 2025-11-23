import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? selectedLocation;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();

    if (widget.initialLat != null && widget.initialLng != null) {
      selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  Future<void> _goToMyLocation() async {
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final newLoc = LatLng(pos.latitude, pos.longitude);

    setState(() => selectedLocation = newLoc);

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(newLoc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng defaultCenter = selectedLocation ??
        const LatLng(14.5995, 120.9842); // Manila fallback

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Device Location"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: defaultCenter,
              zoom: 16,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (latLng) {
              setState(() => selectedLocation = latLng);
            },
            markers: selectedLocation == null
                ? {}
                : {
              Marker(
                markerId: const MarkerId("picked"),
                position: selectedLocation!,
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),

          // Bottom Buttons
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _goToMyLocation,
                  child: const Text(
                    "Get My Current Location",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: selectedLocation == null
                      ? null
                      : () {
                    Navigator.pop(context, selectedLocation);
                  },
                  child: const Text(
                    "Confirm Location",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
