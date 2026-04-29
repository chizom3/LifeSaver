import 'package:flutter/material.dart';

class EmergencyModePage extends StatelessWidget {
  final VoidCallback onCallEmergency;
  final VoidCallback onSendSos;
  final VoidCallback onOpenFirstAid;
  final VoidCallback onFindNearestHospital;

  const EmergencyModePage({
    super.key,
    required this.onCallEmergency,
    required this.onSendSos,
    required this.onOpenFirstAid,
    required this.onFindNearestHospital,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Emergency Mode'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose one action',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'For life-threatening emergencies, call 112 first.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                  children: [
                    _EmergencyActionButton(
                      label: 'Call 112',
                      icon: Icons.call,
                      color: Colors.red,
                      onPressed: onCallEmergency,
                    ),
                    _EmergencyActionButton(
                      label: 'Send SOS',
                      icon: Icons.sos,
                      color: Colors.deepOrange,
                      onPressed: onSendSos,
                    ),
                    _EmergencyActionButton(
                      label: 'First Aid',
                      icon: Icons.health_and_safety,
                      color: Colors.teal,
                      onPressed: onOpenFirstAid,
                    ),
                    _EmergencyActionButton(
                      label: 'Nearest Hospital',
                      icon: Icons.local_hospital,
                      color: Colors.blue,
                      onPressed: onFindNearestHospital,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'MediMap is support only and does not replace emergency services.',
                style: TextStyle(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _EmergencyActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(12),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
