import 'package:flutter/material.dart';

class MedicalDisclaimerPage extends StatelessWidget {
  final bool requiresAcceptance;
  final VoidCallback? onAccepted;

  const MedicalDisclaimerPage({
    super.key,
    this.requiresAcceptance = false,
    this.onAccepted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !requiresAcceptance,
        title: const Text('Medical Disclaimer'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.emergency, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'MediMap is an emergency support tool.',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'It does not replace official emergency services, trained responders, hospitals, doctors, or professional medical advice.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Facility information can become outdated. Confirm phone numbers, routes, and facility availability before relying on them.',
            ),
            const SizedBox(height: 12),
            const Text(
              'SOS messages open in your device SMS app for review. You are responsible for checking and sending the final message.',
            ),
            const SizedBox(height: 12),
            const Text(
              'In an immediate emergency, call your local emergency number first. In Nigeria, use 112 where available.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: Icon(requiresAcceptance ? Icons.check : Icons.close),
              label: Text(requiresAcceptance ? 'I understand' : 'Close'),
              onPressed: onAccepted ?? () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
