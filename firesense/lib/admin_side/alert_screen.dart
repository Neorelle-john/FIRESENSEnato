import 'package:flutter/material.dart';

class AdminAlertScreen extends StatelessWidget {
  const AdminAlertScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);
    const Color lightGrey = Color(0xFFF5F5F5);

    // Sample alerts data
    final List<Map<String, dynamic>> alerts = [
      {
        'title': 'Fire detected at Building A',
        'subtitle': 'Zone 1 - Floor 3',
        'time': '2 mins ago',
        'severity': 'High',
        'type': 'fire',
        'status': 'Active',
      },
      {
        'title': 'Smoke detected at Warehouse 3',
        'subtitle': 'Zone 2 - Storage Area',
        'time': '10 mins ago',
        'severity': 'Medium',
        'type': 'smoke',
        'status': 'Investigating',
      },
      {
        'title': 'Temperature spike at Office B',
        'subtitle': 'Zone 3 - Conference Room',
        'time': '1 hour ago',
        'severity': 'Low',
        'type': 'temperature',
        'status': 'Resolved',
      },
    ];

    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: primaryRed,
        elevation: 0,
        title: const Text(
          'Alert Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.filter_list, color: Colors.white),
              tooltip: 'Filter Alerts',
            ),
          ),
        ],
      ),
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
                        'Active Alerts',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${alerts.where((alert) => alert['status'] != 'Resolved').length}',
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
                    Icons.warning_amber_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),

          // Alerts List
          Expanded(
            child:
                alerts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      itemCount: alerts.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        return _buildAlertCard(alert, index);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No active alerts at this time',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, int index) {
    const Color primaryRed = Color(0xFF8B0000);

    Color severityColor;
    IconData alertIcon;

    switch (alert['severity']) {
      case 'High':
        severityColor = Colors.red;
        alertIcon = Icons.local_fire_department;
        break;
      case 'Medium':
        severityColor = Colors.orange;
        alertIcon = Icons.smoke_free;
        break;
      case 'Low':
        severityColor = Colors.yellow;
        alertIcon = Icons.device_thermostat;
        break;
      default:
        severityColor = Colors.grey;
        alertIcon = Icons.warning;
    }

    Color statusColor;
    switch (alert['status']) {
      case 'Active':
        statusColor = Colors.red;
        break;
      case 'Investigating':
        statusColor = Colors.orange;
        break;
      case 'Resolved':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

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
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(alertIcon, color: severityColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert['subtitle'],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          alert['severity'],
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert['time'],
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          alert['status'],
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryRed,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
