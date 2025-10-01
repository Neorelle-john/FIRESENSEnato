import 'package:flutter/material.dart';
import 'package:firesense/user_side/emergency_dial_screen.dart';
import 'package:firesense/user_side/material_screen.dart';
import 'package:firesense/user_side/settings_screen.dart';
import 'package:firesense/user_side/home_screen.dart';

class FireChecklistScreen extends StatefulWidget {
  const FireChecklistScreen({Key? key}) : super(key: key);

  @override
  State<FireChecklistScreen> createState() => _FireChecklistScreenState();
}

class _FireChecklistScreenState extends State<FireChecklistScreen> {
  // Checklist data organized by categories
  final Map<String, List<ChecklistItem>> _checklistData = {
    'Fire Prevention': [
      ChecklistItem(
        id: 'prevent_1',
        title: 'Smoke detectors installed and working',
        description: 'Test monthly and replace batteries annually',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'prevent_2',
        title: 'Fire extinguisher accessible and charged',
        description: 'Check pressure gauge monthly',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'prevent_3',
        title: 'Electrical outlets not overloaded',
        description: 'Avoid using multiple extension cords',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'prevent_4',
        title: 'Candles and open flames supervised',
        description: 'Never leave burning candles unattended',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'prevent_5',
        title: 'Heating equipment maintained',
        description: 'Clean and inspect furnaces, heaters annually',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'prevent_6',
        title: 'Flammable materials stored safely',
        description: 'Keep away from heat sources and electrical equipment',
        isChecked: false,
      ),
    ],
    'Emergency Preparedness': [
      ChecklistItem(
        id: 'emergency_1',
        title: 'Emergency exit plan created and practiced',
        description: 'Have at least two ways out of every room',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'emergency_2',
        title: 'Emergency contact numbers posted',
        description: 'Include fire department, police, and family contacts',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'emergency_3',
        title: 'Fire escape ladder available (if needed)',
        description: 'For second floor or higher rooms',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'emergency_4',
        title: 'Emergency kit prepared',
        description: 'Include first aid, flashlight, and important documents',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'emergency_5',
        title: 'Family fire drill conducted',
        description: 'Practice at least twice a year',
        isChecked: false,
      ),
    ],
    'Kitchen Safety': [
      ChecklistItem(
        id: 'kitchen_1',
        title: 'Stove and oven clean and functional',
        description: 'Remove grease buildup regularly',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'kitchen_2',
        title: 'Cooking area free of flammable items',
        description: 'Keep towels, papers away from stove',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'kitchen_3',
        title: 'Never leave cooking unattended',
        description: 'Stay in kitchen while cooking',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'kitchen_4',
        title: 'Microwave clean and functioning',
        description: 'Check for damage and clean regularly',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'kitchen_5',
        title: 'Kitchen fire extinguisher nearby',
        description: 'Class K extinguisher for kitchen fires',
        isChecked: false,
      ),
    ],
    'Electrical Safety': [
      ChecklistItem(
        id: 'electrical_1',
        title: 'Electrical cords in good condition',
        description: 'No fraying, cracking, or damage',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'electrical_2',
        title: 'Outlets and switches working properly',
        description: 'No sparking, overheating, or loose connections',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'electrical_3',
        title: 'Extension cords used temporarily only',
        description: 'Not as permanent wiring solution',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'electrical_4',
        title: 'Appliances unplugged when not in use',
        description: 'Especially heating appliances',
        isChecked: false,
      ),
      ChecklistItem(
        id: 'electrical_5',
        title: 'Circuit breakers labeled and accessible',
        description: 'Know which breaker controls which area',
        isChecked: false,
      ),
    ],
  };

  // Track completion progress
  int get _totalItems {
    return _checklistData.values.expand((items) => items).length;
  }

  int get _completedItems {
    return _checklistData.values
        .expand((items) => items)
        .where((item) => item.isChecked)
        .length;
  }

  double get _completionPercentage {
    if (_totalItems == 0) return 0.0;
    return (_completedItems / _totalItems) * 100;
  }

  void _toggleItem(String category, String itemId) {
    setState(() {
      final item = _checklistData[category]!.firstWhere(
        (item) => item.id == itemId,
      );
      item.isChecked = !item.isChecked;
    });
  }

  void _resetAllItems() {
    setState(() {
      for (var items in _checklistData.values) {
        for (var item in items) {
          item.isChecked = false;
        }
      }
    });
  }

  void _checkAllItems() {
    setState(() {
      for (var items in _checklistData.values) {
        for (var item in items) {
          item.isChecked = true;
        }
      }
    });
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8B0000)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fire Safety Checklist',
          style: TextStyle(
            color: Color(0xFF8B0000),
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF8B0000)),
            onSelected: (value) {
              if (value == 'reset') {
                _showResetDialog();
              } else if (value == 'check_all') {
                _checkAllItems();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'check_all',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Check All'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Reset All'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Progress Card
            Container(
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.security,
                          color: primaryRed,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Fire Safety Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _completionPercentage / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryRed, primaryRed.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_completedItems} of ${_totalItems} completed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_completionPercentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 16,
                          color: primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Checklist Categories
            ..._checklistData.entries.map((entry) {
              return _buildCategorySection(
                category: entry.key,
                items: entry.value,
                primaryRed: primaryRed,
                cardWhite: cardWhite,
              );
            }),

            const SizedBox(height: 100), // Extra space for bottom navigation
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: primaryRed,
          unselectedItemColor: Colors.black54,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          currentIndex: 1,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MaterialScreen()),
              );
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencyDialScreen(),
                ),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'Materials',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.phone_in_talk),
              label: 'Emergency Dial',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection({
    required String category,
    required List<ChecklistItem> items,
    required Color primaryRed,
    required Color cardWhite,
  }) {
    final completedInCategory = items.where((item) => item.isChecked).length;
    final totalInCategory = items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryRed.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(_getCategoryIcon(category), color: primaryRed, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$completedInCategory/$totalInCategory',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryRed,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Checklist Items
          ...items.map((item) => _buildChecklistItem(item, primaryRed)),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(ChecklistItem item, Color primaryRed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          GestureDetector(
            onTap: () {
              final category =
                  _checklistData.entries
                      .firstWhere((entry) => entry.value.contains(item))
                      .key;
              _toggleItem(category, item.id);
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: item.isChecked ? primaryRed : Colors.transparent,
                border: Border.all(
                  color: item.isChecked ? primaryRed : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child:
                  item.isChecked
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        item.isChecked
                            ? Colors.grey.shade600
                            : const Color(0xFF1E1E1E),
                    decoration:
                        item.isChecked ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Fire Prevention':
        return Icons.local_fire_department;
      case 'Emergency Preparedness':
        return Icons.emergency;
      case 'Kitchen Safety':
        return Icons.kitchen;
      case 'Electrical Safety':
        return Icons.electrical_services;
      default:
        return Icons.checklist;
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            contentPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            content: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.refresh,
                            color: Colors.orange.shade600,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Reset Checklist',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Message
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Text(
                      'Are you sure you want to reset all checklist items? This action cannot be undone.',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1E1E1E),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _resetAllItems();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class ChecklistItem {
  final String id;
  final String title;
  final String description;
  bool isChecked;

  ChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.isChecked,
  });
}
