import 'package:flutter/material.dart';

class AlarmOverlay extends StatelessWidget {
  final String? deviceName;
  final String? deviceId;
  final VoidCallback onClose;
  final VoidCallback? onOpenAlert; // Optional callback for admin side

  const AlarmOverlay({
    super.key,
    this.deviceName,
    this.deviceId,
    required this.onClose,
    this.onOpenAlert,
  });

  String _getAlarmMessage() {
    if (deviceName != null && deviceName!.isNotEmpty) {
      return "Fire detected by $deviceName. Please evacuate immediately and call emergency services.";
    }
    return "Fire alarm has been triggered. Please evacuate immediately and call emergency services.";
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFF8B0000);
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenSize.width - 48,
              maxHeight: screenSize.height * 0.9,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Alarm Title
                    const Text(
                      "FIRE ALARM",
                      style: TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                    const SizedBox(height: 20),
                    // Alarm Message
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        _getAlarmMessage(),
                        style: const TextStyle(
                          color: Color(0xFF1E1E1E),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Emergency Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryRed.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "What to do:",
                            style: TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                          SizedBox(height: 8),
                          Text(
                            "1.) Evacuate the building immediately\n2.) Call emergency services (911)\n3.) Do not use elevators\n4.) Stay low if there's smoke",
                            style: TextStyle(
                              color: Color(0xFF4A4A4A),
                              fontSize: 13,
                              height: 1.6,
                            ),
                            maxLines: 10,
                            overflow: TextOverflow.clip,
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Button - either "Open Alert" (admin) or "Acknowledge" (user)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (onOpenAlert != null) {
                            // Admin side: Open alert details
                            onOpenAlert!();
                            onClose();
                          } else {
                            // User side: Just close the overlay without changing alarm state
                            // Alarm can only be turned off via "Deactivate Alarm" button in device details
                            onClose();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          onOpenAlert != null ? "Open Alert" : "Acknowledge",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
