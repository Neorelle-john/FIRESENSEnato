import 'package:flutter/material.dart';

class AdminAlertScreen extends StatelessWidget {
  const AdminAlertScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primaryRed),
        titleTextStyle: const TextStyle(
          color: primaryRed,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: const Icon(Icons.warning, color: primaryRed, size: 32),
              title: const Text(
                'Fire detected at Building A',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('2 mins ago'),
              trailing: const Icon(Icons.chevron_right, color: primaryRed),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: const Icon(Icons.warning, color: primaryRed, size: 32),
              title: const Text(
                'Smoke detected at Warehouse 3',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('10 mins ago'),
              trailing: const Icon(Icons.chevron_right, color: primaryRed),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
