import 'package:firesense/user_side/contacts/add_contact_screen.dart';
import 'package:firesense/user_side/contacts/contacts_list_screen.dart';
import 'package:firesense/user_side/devices/devices_screen.dart';
import 'package:firesense/user_side/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firesense/user_side/emergency/emergency_dial_screen.dart';
import 'package:firesense/user_side/home/home_screen.dart';
import 'package:firesense/user_side/materials/fire_prevention_screen.dart';
import 'package:firesense/user_side/materials/fire_checklist_screen.dart';

class MaterialScreen extends StatefulWidget {
  const MaterialScreen({Key? key}) : super(key: key);

  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen> {
  // 0 = News and Articles, 1 = Secondary Resources
  int selectedCategory = 0;

  @override
  Widget build(BuildContext context) {
    final Color primaryRed = const Color(0xFF8B0000);
    final Color lightGrey = const Color(0xFFF5F5F5);
    final Color cardWhite = Colors.white;

    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: lightGrey,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [lightGrey, lightGrey.withOpacity(0.95)],
            ),
          ),
        ),
        title: Row(
          children: [
            const Text(
              'Materials',
              style: TextStyle(
                color: Color(0xFF8B0000),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.people, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactsListScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person_add, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddContactScreen(),
                ),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Categories Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryButton(
                        title: 'News and Articles',
                        icon: Icons.article_outlined,
                        isSelected: selectedCategory == 0,
                        onTap: () => setState(() => selectedCategory = 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCategoryButton(
                        title: 'Secondary Resources',
                        icon: Icons.library_books_outlined,
                        isSelected: selectedCategory == 1,
                        onTap: () => setState(() => selectedCategory = 1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (selectedCategory == 0) ...[
              // Enhanced News and Articles
              _buildNewsCard(
                title: 'A fire destroys homes in Tondo Manila',
                subtitle:
                    'Manila Fire: Inferno destroys thousands of shanties in isla puting bato',
                content:
                    'A massive fire broke out in the early hours of the morning, engulfing hundreds of homes in the densely populated area.',
                category: 'Breaking News',
                timeAgo: '2 hours ago',
                icon: Icons.local_fire_department,
              ),
              const SizedBox(height: 12),
              _buildNewsCard(
                title: 'A three storey building burned down',
                subtitle:
                    'A fire engulfed a three storey building in Manila in just 20 minutes',
                content:
                    'The fire started on the ground floor of the commercial building and quickly spread upward through the stairwells.',
                category: 'Emergency',
                timeAgo: '5 hours ago',
                icon: Icons.warning_amber_outlined,
              ),
            ] else ...[
              // Enhanced Secondary Resources
              _buildResourceCard(
                imageUrl:
                    'https://plus.unsplash.com/premium_photo-1661490162121-41df314e1ef1?q=80&w=932&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
                title: 'Fire Prevention',
                description:
                    'Essential fire safety tips and prevention measures',
                category: 'Safety Guide',
                isInteractive: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FirePreventionScreen(),
                    ),
                  );
                },
                icon: Icons.local_fire_department,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              _buildResourceCard(
                imageUrl:
                    'https://media.istockphoto.com/id/2174665559/nl/foto/checking-fire-equipment-in-a-fire-truck.jpg?s=612x612&w=is&k=20&c=1WySJyeHoxnaZZXHO6-Ci4tqdlW1cDuUJED3BMzw00M=',
                title: 'Fire Safety Checklist',
                description: 'A comprehensive guide to check for your safety',
                category: 'Checklist',
                isInteractive: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FireChecklistScreen(),
                    ),
                  );
                },
                icon: Icons.checklist,
                color: Colors.orange,
              ),
            ],
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
              offset: Offset(0, -2),
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
              // Already on Materials
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DevicesScreen()),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencyDialScreen(),
                ),
              );
            } else if (index == 4) {
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
              icon: Icon(Icons.sensors),
              label: 'Devices',
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

  Widget _buildCategoryButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final Color primaryRed = const Color(0xFF8B0000);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient:
                isSelected
                    ? LinearGradient(
                      colors: [primaryRed, primaryRed.withOpacity(0.8)],
                    )
                    : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryRed : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isSelected
                        ? primaryRed.withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : primaryRed,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsCard({
    required String title,
    required String subtitle,
    required String content,
    required String category,
    required String timeAgo,
    required IconData icon,
  }) {
    final Color primaryRed = const Color(0xFF8B0000);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with category and time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryRed,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryRed.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    timeAgo,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF1E1E1E),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 15,
                color: primaryRed,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Content
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),

            // Read More section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, color: primaryRed, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Read More',
                        style: TextStyle(
                          color: primaryRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard({
    required String imageUrl,
    required String title,
    required String description,
    required String category,
    required bool isInteractive,
    VoidCallback? onTap,
    required IconData icon,
    required Color color,
  }) {
    final Color primaryRed = const Color(0xFF8B0000);

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                isInteractive
                    ? color.withOpacity(0.15)
                    : Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border:
            isInteractive
                ? Border.all(color: color.withOpacity(0.2), width: 1)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: Image.network(
                  imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isInteractive)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryRed,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryRed.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.touch_app,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF1E1E1E),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isInteractive
                                ? primaryRed.withOpacity(0.1)
                                : color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isInteractive
                                ? Icons.touch_app
                                : Icons.info_outline,
                            color: isInteractive ? primaryRed : color,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isInteractive ? 'Tap to read more' : 'Coming Soon',
                            style: TextStyle(
                              color: isInteractive ? primaryRed : color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isInteractive && onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
