import 'package:flutter/material.dart';

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

              // Enhanced Header Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF8B0000).withOpacity(0.05),
                      const Color(0xFF8B0000).withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF8B0000).withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B0000).withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF8B0000).withOpacity(0.15),
                                const Color(0xFF8B0000).withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF8B0000).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            '🔥',
                            style: TextStyle(fontSize: 32),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B0000,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'SAFETY GUIDE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B0000),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Fire Prevention',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E1E1E),
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
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: const Color(0xFF8B0000),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'What You Need to Know',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Essential tips and measures to keep you and your property safe from fire hazards.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Why Fire Prevention Matters
              _buildExpandableSection(
                key: 'why_matters',
                title: '1. Why Fire Prevention Matters',
                summary:
                    'Understanding the importance of fire prevention and early detection',
                content: [
                  'Fires spread fast. Early detection and good habits can save lives and property.',
                  '',
                  'Many residential fires start from everyday sources like cooking, heating devices, and electrical faults.',
                  '',
                  'According to the US Fire Administration, smoke alarms, fire-safe behavior, and community risk reduction play key roles in preventing home fires.',
                ],
                icon: Icons.info_outline,
                iconColor: Colors.blue,
              ),

              const SizedBox(height: 16),

              // At Home Prevention Measures
              _buildExpandableSection(
                key: 'at_home',
                title: ' At Home: Key Prevention Measures',
                summary: 'Essential fire safety tips for your home and family',
                content: [
                  'A. Smoke Alarms & Early Detection',
                  '• Install smoke alarms on every level, inside every bedroom, and outside sleeping areas.',
                  '• Test alarms monthly and replace batteries at least once a year.',
                  '• Replace your smoke alarm if it\'s more than 10 years old.',
                  '',
                  'B. Kitchen & Cooking Safety',
                  '• Never leave cooking food unattended.',
                  '• Keep flammable items (cloths, paper, curtains) away from stove, ovens, and heat sources.',
                  '• Clean grease and oil buildup from cooking surfaces. Grease fires are dangerous.',
                  '• If a grease fire starts, cover the pan with a lid and turn off heat (don\'t use water).',
                  '',
                  'C. Electrical & Appliance Safety',
                  '• Inspect cords and plugs: replace cracked, frayed, or damaged ones.',
                  '• Avoid overloading outlets or power strips.',
                  '• Keep cords out of walkways and off walls to prevent wear.',
                  '',
                  'D. Heating, Fireplaces & Space Heaters',
                  '• Keep at least 3 feet (≈1 meter) distance between heaters/fireplaces and flammable objects.',
                  '• Have chimneys, vents, and heating systems inspected and cleaned annually.',
                  '• Use screens or guards in fireplaces to contain sparks.',
                  '',
                  'E. Safe Storage & Housekeeping',
                  '• Store flammable liquids (gasoline, solvents) in approved containers, away from living spaces.',
                  '• Keep clutter, trash, and combustible materials away from exits and heaters.',
                  '• Clear roofs, gutters, and surroundings of leaves and debris to reduce fire risk.',
                ],
                icon: Icons.home_outlined,
                iconColor: Colors.green,
              ),

              const SizedBox(height: 16),

              // Buildings & Workplaces
              _buildExpandableSection(
                key: 'workplace',
                title: ' In Buildings & Workplaces',
                summary:
                    'Fire safety measures for commercial and public buildings',
                content: [
                  '• Ensure clear, unobstructed exits and marked evacuation routes.',
                  '• Maintain fire alarms, sprinklers, extinguishers, and emergency lighting.',
                  '• Train occupants/employees on fire prevention, proper use of fire extinguishers, and evacuation.',
                  '• Conduct regular fire drills to ensure readiness.',
                  '• Perform periodic inspections and maintenance of all fire safety systems.',
                ],
                icon: Icons.business_outlined,
                iconColor: Colors.orange,
              ),

              const SizedBox(height: 16),

              // Wildfire & Outdoor Fire Prevention
              _buildExpandableSection(
                key: 'wildfire',
                title: ' Wildfire & Outdoor Fire Prevention',
                summary: 'Protecting against outdoor fires and wildfires',
                content: [
                  '• Avoid open flames or burning during dry, windy periods.',
                  '• Build campfires in safe, cleared areas; extinguish completely before leaving.',
                  '• Maintain defensible space around buildings by clearing vegetation, trimming trees, and using fire-resistant materials.',
                  '• Use fire-resistant roofing, siding, vents, and screens to reduce ember infiltration.',
                ],
                icon: Icons.park_outlined,
                iconColor: Colors.brown,
              ),

              const SizedBox(height: 16),

              // Emergency Response
              _buildExpandableSection(
                key: 'emergency',
                title: ' What To Do If Fire Breaks Out: Basic Response Steps',
                summary: 'Critical steps to take when a fire occurs',
                content: [
                  '• Alert & evacuate — Leave immediately via your escape plan.',
                  '• Close doors behind you — helps slow fire spread.',
                  '• Stay low & crawl under smoke — air is cleaner near the floor.',
                  '• Stop, Drop, & Roll — if your clothes catch fire.',
                  '• Once safe, call emergency services.',
                  '• Don\'t re-enter until authorities say it\'s safe.',
                ],
                icon: Icons.emergency_outlined,
                iconColor: Colors.red,
              ),

              const SizedBox(height: 32),
            ],
          ),
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
        gradient:
            isExpanded
                ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    iconColor.withOpacity(0.03),
                    iconColor.withOpacity(0.01),
                  ],
                )
                : null,
        color: isExpanded ? null : cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                isExpanded
                    ? iconColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.08),
            blurRadius: isExpanded ? 16 : 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isExpanded ? iconColor.withOpacity(0.4) : Colors.grey.shade200,
          width: isExpanded ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Enhanced Header (Always visible)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedSections[key] = !isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(20),
              splashColor: iconColor.withOpacity(0.1),
              highlightColor: iconColor.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            iconColor.withOpacity(0.2),
                            iconColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: iconColor.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: iconColor, size: 26),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color:
                                  isExpanded
                                      ? iconColor
                                      : const Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              summary,
                              style: TextStyle(
                                fontSize: 13,
                                color: iconColor.withOpacity(0.8),
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryRed.withOpacity(0.15),
                            primaryRed.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryRed.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: primaryRed,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Enhanced Expandable Content
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            height: isExpanded ? null : 0,
            child:
                isExpanded
                    ? Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.8),
                            Colors.grey.shade50.withOpacity(0.9),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: iconColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    iconColor.withOpacity(0.3),
                                    iconColor.withOpacity(0.1),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              margin: const EdgeInsets.only(bottom: 20),
                            ),
                            ...content.map((line) {
                              if (line.isEmpty) {
                                return const SizedBox(height: 16);
                              }

                              // Enhanced bullet formatting
                              if (line.startsWith('•')) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: iconColor.withOpacity(0.1),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: iconColor.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(
                                          top: 2,
                                          right: 16,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              iconColor.withOpacity(0.2),
                                              iconColor.withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.check_circle_outline,
                                          color: iconColor,
                                          size: 16,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          line.substring(1).trim(),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF1E1E1E),
                                            height: 1.6,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (line.contains('A.') ||
                                  line.contains('B.') ||
                                  line.contains('C.') ||
                                  line.contains('D.') ||
                                  line.contains('E.')) {
                                // Enhanced section headers
                                return Container(
                                  margin: const EdgeInsets.only(
                                    bottom: 12,
                                    top: 16,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        iconColor.withOpacity(0.1),
                                        iconColor.withOpacity(0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: iconColor.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: iconColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.label_important_outline,
                                          color: iconColor,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          line,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: iconColor,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // Enhanced regular text
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey.shade800,
                                      height: 1.6,
                                      fontWeight: FontWeight.w400,
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
