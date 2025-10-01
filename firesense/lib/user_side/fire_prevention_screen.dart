import 'package:flutter/material.dart';
import 'package:firesense/user_side/emergency_dial_screen.dart';
import 'package:firesense/user_side/material_screen.dart';
import 'package:firesense/user_side/settings_screen.dart';
import 'package:firesense/user_side/home_screen.dart';

class FirePreventionScreen extends StatefulWidget {
  const FirePreventionScreen({Key? key}) : super(key: key);

  @override
  State<FirePreventionScreen> createState() => _FirePreventionScreenState();
}

class _FirePreventionScreenState extends State<FirePreventionScreen> {
  final Map<String, bool> _expandedSections = {
    'why_matters': false,
    'at_home': false,
    'workplace': false,
    'wildfire': false,
    'emergency': false,
  };

  @override
  Widget build(BuildContext context) {
    final Color lightGrey = const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: lightGrey,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8B0000)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fire Prevention',
          style: TextStyle(
            color: Color(0xFF8B0000),
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Professional Header Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B0000).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_fire_department,
                            color: Color(0xFF8B0000),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fire Prevention Guide',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Professional safety measures for property owners',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B0000).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF8B0000).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: const Color(0xFF8B0000),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Comprehensive fire safety protocols for residential and commercial properties',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Fire Prevention Fundamentals
              _buildExpandableSection(
                key: 'why_matters',
                title: 'Fire Prevention Fundamentals',
                summary: 'Understanding fire risks and prevention strategies',
                content: [
                  'Fire incidents can cause significant property damage and loss of life. Early detection and proper prevention measures are essential for property protection.',
                  '',
                  'Most fires originate from common sources: cooking equipment, electrical systems, heating devices, and improper storage of flammable materials.',
                  '',
                  'Implementing comprehensive fire safety protocols reduces risk and ensures compliance with local fire codes and insurance requirements.',
                ],
                icon: Icons.analytics_outlined,
                iconColor: const Color(0xFF8B0000),
              ),

              const SizedBox(height: 16),

              // Residential Property Safety
              _buildExpandableSection(
                key: 'at_home',
                title: 'Residential Property Safety',
                summary: 'Essential fire safety measures for home owners',
                content: [
                  'Smoke Detection Systems',
                  '• Install interconnected smoke alarms on every level and in all bedrooms',
                  '• Test monthly and replace batteries annually',
                  '• Replace smoke alarms every 10 years or as recommended by manufacturer',
                  '',
                  'Kitchen Safety Protocols',
                  '• Never leave cooking unattended',
                  '• Maintain 3-foot clearance from heat sources',
                  '• Clean grease buildup regularly to prevent fire hazards',
                  '• Keep fire extinguisher accessible in kitchen area',
                  '',
                  'Electrical System Maintenance',
                  '• Inspect electrical cords and replace damaged ones immediately',
                  '• Avoid overloading circuits and power strips',
                  '• Schedule annual electrical system inspection by licensed electrician',
                  '',
                  'Heating System Safety',
                  '• Maintain 3-foot clearance around heating equipment',
                  '• Schedule annual inspection and cleaning of heating systems',
                  '• Use fireplace screens and ensure proper ventilation',
                  '',
                  'Property Maintenance',
                  '• Store flammable materials in approved containers away from living areas',
                  '• Maintain clear evacuation routes and exits',
                  '• Keep gutters and roof areas clear of debris',
                ],
                icon: Icons.home_work_outlined,
                iconColor: const Color(0xFF8B0000),
              ),

              const SizedBox(height: 16),

              // Commercial Building Safety
              _buildExpandableSection(
                key: 'workplace',
                title: 'Commercial Building Safety',
                summary: 'Fire safety compliance for business establishments',
                content: [
                  '• Maintain clear, marked evacuation routes and emergency exits',
                  '• Install and maintain fire suppression systems (sprinklers, alarms, extinguishers)',
                  '• Conduct regular fire safety training for all employees',
                  '• Schedule quarterly fire drills and document compliance',
                  '• Perform annual inspection and maintenance of all fire safety equipment',
                  '• Ensure emergency lighting systems are functional',
                  '• Maintain fire department access and clear building perimeters',
                ],
                icon: Icons.business_center_outlined,
                iconColor: const Color(0xFF8B0000),
              ),

              const SizedBox(height: 16),

              // Outdoor Fire Prevention
              _buildExpandableSection(
                key: 'wildfire',
                title: 'Outdoor Fire Prevention',
                summary: 'Protecting properties from external fire threats',
                content: [
                  '• Maintain defensible space around buildings (minimum 30 feet)',
                  '• Use fire-resistant building materials for roofing and siding',
                  '• Clear vegetation and debris from building perimeters',
                  '• Install ember-resistant vents and screens',
                  '• Avoid outdoor burning during high-risk weather conditions',
                  '• Ensure adequate water supply for fire suppression',
                ],
                icon: Icons.landscape_outlined,
                iconColor: const Color(0xFF8B0000),
              ),

              const SizedBox(height: 16),

              // Emergency Response Procedures
              _buildExpandableSection(
                key: 'emergency',
                title: 'Emergency Response Procedures',
                summary: 'Critical actions during fire incidents',
                content: [
                  '• Activate fire alarm and alert all occupants immediately',
                  '• Evacuate using designated escape routes',
                  '• Close doors behind you to slow fire spread',
                  '• Stay low to avoid smoke inhalation',
                  '• Call emergency services from safe location',
                  '• Do not re-enter building until cleared by fire department',
                  '• Account for all occupants at designated meeting point',
                ],
                icon: Icons.emergency_outlined,
                iconColor: const Color(0xFF8B0000),
              ),

              const SizedBox(height: 100), // Extra space for bottom navigation
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
          selectedItemColor: const Color(0xFF8B0000),
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

  Widget _buildExpandableSection({
    required String key,
    required String title,
    required String summary,
    required List<String> content,
    required IconData icon,
    required Color iconColor,
  }) {
    final Color cardWhite = Colors.white;
    final Color primaryRed = const Color(0xFF8B0000);
    final bool isExpanded = _expandedSections[key] ?? false;

    return Container(
      width: double.infinity,
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
        border: Border.all(
          color:
              isExpanded ? primaryRed.withOpacity(0.2) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Professional Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedSections[key] = !isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: primaryRed, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: primaryRed,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Professional Content
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: isExpanded ? null : 0,
            child:
                isExpanded
                    ? Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            ...content.map((line) {
                              if (line.isEmpty) {
                                return const SizedBox(height: 12);
                              }

                              // Professional bullet points
                              if (line.startsWith('•')) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(
                                          top: 6,
                                          right: 12,
                                        ),
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: primaryRed,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          line.substring(1).trim(),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF1E1E1E),
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (line.contains('Systems') ||
                                  line.contains('Protocols') ||
                                  line.contains('Maintenance') ||
                                  line.contains('Safety')) {
                                // Section headers
                                return Container(
                                  margin: const EdgeInsets.only(
                                    bottom: 8,
                                    top: 16,
                                  ),
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryRed,
                                      height: 1.4,
                                    ),
                                  ),
                                );
                              } else {
                                // Regular text
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                );
                              }
                            }).toList(),
                          ],
                        ),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
