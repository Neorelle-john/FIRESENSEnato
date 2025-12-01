import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminClientsScreen extends StatefulWidget {
  const AdminClientsScreen({Key? key}) : super(key: key);

  @override
  State<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends State<AdminClientsScreen> {
  final List<Map<String, dynamic>> clients = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _clientsSubscription;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _clientsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First, check if admin has clients stored
      final adminClientsRef = FirebaseFirestore.instance
          .collection('admin')
          .doc(adminUser.uid)
          .collection('clients');

      // Check initial state
      final initialSnapshot = await adminClientsRef.get();
      if (initialSnapshot.docs.isEmpty) {
        // If no clients stored, fetch from users collection and sync
        await _syncUsersToAdminClients();
      } else {
        // Load clients from admin collection
        await _loadClientsFromAdmin();
      }

      // Listen to admin's clients collection for updates
      _clientsSubscription = adminClientsRef.snapshots().listen((snapshot) {
        _loadClientsFromAdmin();
      });

      // Also listen to users collection for new users
      _usersSubscription = FirebaseFirestore.instance
          .collection('users')
          .snapshots()
          .listen((snapshot) {
            // Sync new users to admin clients (only if not already syncing)
            if (!_isLoading) {
              _syncUsersToAdminClients();
            }
          });
    } catch (e) {
      print('Error loading clients: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncUsersToAdminClients() async {
    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) return;

    try {
      // Get all users from /users collection
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      final adminClientsRef = FirebaseFirestore.instance
          .collection('admin')
          .doc(adminUser.uid)
          .collection('clients');

      // Sync each user to admin's clients collection
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();

        // Skip admin user itself
        if (userId == adminUser.uid) continue;

        // Get user's devices
        final devicesSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('devices')
                .get();

        final devices =
            devicesSnapshot.docs.map((doc) {
              final deviceData = doc.data();
              return {
                'deviceId': deviceData['deviceId'] ?? doc.id,
                'name': deviceData['name'] ?? 'Unknown Device',
                ...deviceData,
              };
            }).toList();

        // Store in admin's clients collection
        await adminClientsRef.doc(userId).set({
          'userId': userId,
          'name': userData['name'] ?? 'Unknown User',
          'email': userData['email'] ?? '',
          'phone': userData['phone'] ?? '',
          'address': userData['address'] ?? '',
          'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Store devices as subcollection
        final devicesRef = adminClientsRef.doc(userId).collection('devices');
        for (var device in devices) {
          await devicesRef.doc(device['deviceId']).set(device);
        }
      }

      // Reload clients after sync
      _loadClientsFromAdmin();
    } catch (e) {
      print('Error syncing users to admin clients: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClientsFromAdmin() async {
    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final clientsSnapshot =
          await FirebaseFirestore.instance
              .collection('admin')
              .doc(adminUser.uid)
              .collection('clients')
              .get();

      final List<Map<String, dynamic>> loadedClients = [];

      for (var clientDoc in clientsSnapshot.docs) {
        final clientData = clientDoc.data();

        // Get devices for this client
        final devicesSnapshot =
            await FirebaseFirestore.instance
                .collection('admin')
                .doc(adminUser.uid)
                .collection('clients')
                .doc(clientDoc.id)
                .collection('devices')
                .get();

        final devices =
            devicesSnapshot.docs.map((doc) {
              final deviceData = doc.data();
              return deviceData['name'] ?? 'Unknown Device';
            }).toList();

        loadedClients.add({
          'id': clientDoc.id,
          'name': clientData['name'] ?? 'Unknown User',
          'email': clientData['email'] ?? '',
          'phone': clientData['phone'] ?? '',
          'address': clientData['address'] ?? '',
          'devices': devices,
        });
      }

      if (mounted) {
        setState(() {
          clients.clear();
          clients.addAll(loadedClients);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading clients from admin: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncUserToAdminClient(String userId) async {
    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) return;

    try {
      // Get user data
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;

      // Get user's devices
      final devicesSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('devices')
              .get();

      final devices =
          devicesSnapshot.docs.map((doc) {
            final deviceData = doc.data();
            return {
              'deviceId': deviceData['deviceId'] ?? doc.id,
              'name': deviceData['name'] ?? 'Unknown Device',
              ...deviceData,
            };
          }).toList();

      // Store in admin's clients collection
      final adminClientsRef = FirebaseFirestore.instance
          .collection('admin')
          .doc(adminUser.uid)
          .collection('clients');

      await adminClientsRef.doc(userId).set({
        'userId': userId,
        'name': userData['name'] ?? 'Unknown User',
        'email': userData['email'] ?? '',
        'phone': userData['phone'] ?? '',
        'address': userData['address'] ?? '',
        'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Store devices as subcollection
      final devicesRef = adminClientsRef.doc(userId).collection('devices');
      for (var device in devices) {
        await devicesRef.doc(device['deviceId']).set(device);
      }

      // Reload clients
      await _loadClientsFromAdmin();
    } catch (e) {
      print('Error syncing client: $e');
    }
  }

  void _addDevice(int clientIndex) async {
    // Devices should be added from the user's actual devices collection
    // This will sync automatically when we reload
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Devices are synced from the user\'s account. Please add devices from the user side.',
          ),
          backgroundColor: Color(0xFF8B0000),
        ),
      );
    }

    // Refresh to get latest devices
    await _syncUserToAdminClient(clients[clientIndex]['id']);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);
    const Color lightGrey = Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: lightGrey,
      body: Column(
        children: [
          // Header Stats
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryRed, Color(0xFFB22222)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryRed.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Clients',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${clients.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),

          // Clients List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : clients.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      itemCount: clients.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final client = clients[index];
                        return _buildClientCard(client, index);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    const Color primaryRed = Color(0xFF8B0000);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.people_outline,
              size: 64,
              color: primaryRed.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Clients Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Clients are automatically added when users sign up',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'New users will appear here automatically',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client, int index) {
    const Color primaryRed = Color(0xFF8B0000);
    final deviceCount = (client['devices'] as List).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.only(bottom: 16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [primaryRed, Color(0xFFB22222)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 24),
        ),
        title: Text(
          client['name'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$deviceCount device${deviceCount != 1 ? 's' : ''}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            if (client['email'] != null &&
                client['email'].toString().isNotEmpty)
              Text(
                client['email'],
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.expand_more, color: primaryRed, size: 20),
        ),
        children: [
          if (deviceCount > 0) ...[
            ...List.generate(
              deviceCount,
              (devIdx) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.sensors,
                        color: primaryRed,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        client['devices'][devIdx],
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Online',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.device_unknown,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No devices added yet',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addDevice(index),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh Devices'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
