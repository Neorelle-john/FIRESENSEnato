import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'client_screen.dart';
import 'alert_screen.dart';
import 'settings.dart';

// Dummy data for clients and their devices - Urdaneta, Pangasinan
final List<Map<String, dynamic>> dummyClients = [
  {
    'name': 'Urdaneta City Hall',
    'devices': [
      'FireSense Pro - Mayor\'s Office',
      'FireSense Pro - Council Chamber',
      'FireSense Pro - Records Section',
      'FireSense Pro - Treasury Office',
    ],
  },
  {
    'name': 'Urdaneta Central Market',
    'devices': [
      'FireSense Pro - Meat Section',
      'FireSense Pro - Vegetable Area',
      'FireSense Pro - Dry Goods Section',
      'FireSense Pro - Food Court',
    ],
  },
  {
    'name': 'Pangasinan State University - Urdaneta',
    'devices': [
      'FireSense Pro - Main Library',
      'FireSense Pro - Computer Laboratory',
      'FireSense Pro - Science Laboratory',
      'FireSense Pro - Cafeteria',
      'FireSense Pro - Administration Building',
    ],
  },
  {
    'name': 'Urdaneta District Hospital',
    'devices': [
      'FireSense Pro - Emergency Room',
      'FireSense Pro - Operating Room',
      'FireSense Pro - ICU Ward',
      'FireSense Pro - Pharmacy',
      'FireSense Pro - Laboratory',
      'FireSense Pro - Patient Wards',
    ],
  },
  {
    'name': 'Robinsons Place Urdaneta',
    'devices': [
      'FireSense Pro - Food Court',
      'FireSense Pro - Cinema 1',
      'FireSense Pro - Cinema 2',
      'FireSense Pro - Department Store',
      'FireSense Pro - Parking Level 1',
      'FireSense Pro - Parking Level 2',
    ],
  },
  {
    'name': 'Urdaneta Public Market',
    'devices': [
      'FireSense Pro - Fish Section',
      'FireSense Pro - Poultry Area',
      'FireSense Pro - Rice Section',
      'FireSense Pro - Spice Corner',
    ],
  },
];

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    // Dashboard
    _AdminDashboard(),
    // Clients
    AdminClientsScreen(),
    // Alerts
    AdminAlertScreen(),
    // Settings
    AdminSettingsScreen(),
  ];

  final List<String> _titles = [
    'Admin Dashboard',
    'Clients',
    'Alerts',
    'Settings',
  ];

  void _onDrawerTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close the drawer
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: primaryRed,
        elevation: 2,
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: true,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // Enhanced Header
            Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryRed, Color(0xFFB22222)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Admin Panel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'FireSense Management',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'System Administrator',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
            // Navigation Items
            Expanded(
              child: Container(
                color: const Color(0xFFF8F9FA),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.dashboard_outlined,
                      title: 'Dashboard',
                      subtitle: 'Overview & Statistics',
                      index: 0,
                      isSelected: _selectedIndex == 0,
                    ),
                    _buildDrawerItem(
                      icon: Icons.people_outline,
                      title: 'Clients',
                      subtitle: 'Manage Client Accounts',
                      index: 1,
                      isSelected: _selectedIndex == 1,
                    ),
                    _buildDrawerItem(
                      icon: Icons.warning_amber_outlined,
                      title: 'Alerts',
                      subtitle: 'Emergency Notifications',
                      index: 2,
                      isSelected: _selectedIndex == 2,
                    ),
                    _buildDrawerItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'System Preferences',
                      index: 3,
                      isSelected: _selectedIndex == 3,
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                border: Border(
                  top: BorderSide(color: Color(0xFFE9ECEF), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.security,
                      color: primaryRed,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Secure Session',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF495057),
                          ),
                        ),
                        Text(
                          'Last login: Today',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
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
      body: SafeArea(child: _screens[_selectedIndex]),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required int index,
    required bool isSelected,
  }) {
    const Color primaryRed = Color(0xFF8B0000);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? primaryRed.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
                ? Border.all(color: primaryRed.withOpacity(0.3), width: 1)
                : null,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? primaryRed : primaryRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : primaryRed,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 15,
            color: isSelected ? primaryRed : const Color(0xFF495057),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color:
                isSelected ? primaryRed.withOpacity(0.7) : Colors.grey.shade600,
          ),
        ),
        onTap: () => _onDrawerTap(index),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

// Enhanced Dashboard widget with comprehensive data
class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard();

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);
    const Color cardWhite = Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Enhanced Map View Button - Primary Eye Catcher
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [primaryRed, Color(0xFFB22222)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryRed.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: primaryRed.withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminMapScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 32,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated icon container
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.map_outlined,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Enhanced text with subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'VIEW MAP',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Monitor Fire Sensors',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Arrow indicator
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Statistics Cards Row 1
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people_outline,
                  title: 'Total Clients',
                  value: '${dummyClients.length}',
                  subtitle: 'Registered',
                  color: primaryRed,
                  trend: '+12%',
                  trendColor: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.device_thermostat,
                  title: 'Active Devices',
                  value: '24',
                  subtitle: 'Online',
                  color: Colors.blue,
                  trend: '+5%',
                  trendColor: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Statistics Cards Row 2
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.warning_amber_outlined,
                  title: 'Active Alerts',
                  value: '3',
                  subtitle: 'Pending',
                  color: Colors.orange,
                  trend: '-2',
                  trendColor: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.location_on_outlined,
                  title: 'Coverage',
                  value: '5',
                  subtitle: 'Zones',
                  color: Colors.green,
                  trend: '100%',
                  trendColor: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Alerts Section
          _buildSectionHeader('Recent Alerts'),

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
            child: Column(
              children: [
                _buildAlertItem(
                  icon: Icons.local_fire_department,
                  title: 'Fire detected at Building A',
                  subtitle: '2 minutes ago',
                  severity: 'High',
                  color: Colors.red,
                  location: 'Zone 1',
                ),
                _buildDivider(),
                _buildAlertItem(
                  icon: Icons.smoke_free,
                  title: 'Smoke detected at Warehouse 3',
                  subtitle: '10 minutes ago',
                  severity: 'Medium',
                  color: Colors.orange,
                  location: 'Zone 2',
                ),
                _buildDivider(),
                _buildAlertItem(
                  icon: Icons.warning_amber_outlined,
                  title: 'Temperature spike at Office B',
                  subtitle: '1 hour ago',
                  severity: 'Low',
                  color: Colors.yellow,
                  location: 'Zone 3',
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required String trend,
    required Color trendColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String severity,
    required Color color,
    required String location,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              severity,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: Colors.grey.shade200, height: 1),
    );
  }
}

// Map screen with client markers
class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({Key? key}) : super(key: key);

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  LatLng? _currentPosition;
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() {
      _locationLoading = true;
    });

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      setState(() {
        _locationLoading = false;
      });
      return;
    }

    // Check permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationLoading = false;
      });
      return;
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _locationLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryRed,
        elevation: 10,
        title: const Text(
          'Map View',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          _locationLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentPosition == null
              ? const Center(
                child: Text('Location permission denied or unavailable.'),
              )
              : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition!,
                  zoom: 14,
                ),
                onMapCreated: (controller) {
                  // Map controller initialized
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              ),
    );
  }
}
