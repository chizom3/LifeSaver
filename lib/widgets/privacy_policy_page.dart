import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'MediMap Privacy Policy',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const _PolicySection(
              title: 'Data stored on this device',
              body:
                  'Medical ID, emergency contacts, saved hospitals, and last known location are stored locally on your device using app storage.',
            ),
            const _PolicySection(
              title: 'Location',
              body:
                  'Location is used to sort nearby facilities, show your position on the map, and prepare SOS messages. The app keeps a last known location fallback on this device.',
            ),
            const _PolicySection(
              title: 'Reports',
              body:
                  'Facility correction reports are saved locally by default and can open your email app so you can send the details. Cloud report submission is optional and should only be enabled after Firebase is configured.',
            ),
            const _PolicySection(
              title: 'Analytics and diagnostics',
              body:
                  'Firebase Analytics and Crashlytics may be used to understand app usage and diagnose crashes. Do not enter sensitive medical details into report text.',
            ),
            const _PolicySection(
              title: 'Your control',
              body:
                  'You can edit Medical ID details, remove emergency contacts, clear saved hospitals, and choose whether to send SOS or report emails.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
