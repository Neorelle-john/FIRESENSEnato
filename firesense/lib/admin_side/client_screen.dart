import 'package:flutter/material.dart';

class AdminClientsScreen extends StatefulWidget {
  const AdminClientsScreen({Key? key}) : super(key: key);

  @override
  State<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends State<AdminClientsScreen> {
  final List<Map<String, dynamic>> clients = [
    {
      'name': 'Client A',
      'devices': ['Device 1', 'Device 2'],
    },
    {
      'name': 'Client B',
      'devices': ['Device 3'],
    },
  ];

  void _addClient() async {
    String? clientName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add Client'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Client Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (clientName != null && clientName.isNotEmpty) {
      setState(() {
        clients.add({'name': clientName, 'devices': []});
      });
    }
  }

  void _addDevice(int clientIndex) async {
    String? deviceName = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add Device'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Device Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (deviceName != null && deviceName.isNotEmpty) {
      setState(() {
        clients[clientIndex]['devices'].add(deviceName);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Clients',
          style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: primaryRed),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: primaryRed),
            tooltip: 'Add Client',
            onPressed: _addClient,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: clients.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final client = clients[index];
          return Card(
            color: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: primaryRed.withOpacity(0.1),
                child: Icon(Icons.person, color: primaryRed),
              ),
              title: Text(
                client['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                ...List.generate(
                  client['devices'].length,
                  (devIdx) => ListTile(
                    leading: const Icon(Icons.sensors, color: primaryRed),
                    title: Text(client['devices'][devIdx]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, color: primaryRed),
                    label: const Text(
                      'Add Device',
                      style: TextStyle(color: primaryRed),
                    ),
                    onPressed: () => _addDevice(index),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
