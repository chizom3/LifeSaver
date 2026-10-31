import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinish;
  final VoidCallback onOpenMedicalId;

  const OnboardingPage({
    super.key,
    required this.onFinish,
    required this.onOpenMedicalId,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _OnboardingStep(
        icon: Icons.local_hospital,
        showLogo: true,
        title: 'Find nearby care',
        body:
            'Use LifeSaver to search health facilities, compare distance, call, and open directions.',
      ),
      const _OnboardingStep(
        icon: Icons.medical_information,
        title: 'Set up Medical ID',
        body:
            'Save blood type, conditions, medications, allergies, and emergency contacts on this device.',
      ),
      const _OnboardingStep(
        icon: Icons.sos,
        title: 'Prepare SOS alerts',
        body:
            'SOS creates a message preview with your Medical ID and current or last known location.',
      ),
    ];
    final isLastPage = _pageIndex == pages.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LifeSaver'),
        actions: [
          TextButton(onPressed: widget.onFinish, child: const Text('Skip')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => _pageIndex = index);
              },
              children: pages,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < pages.length; index++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: index == _pageIndex ? 22 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _pageIndex
                              ? Colors.red
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(isLastPage ? Icons.check : Icons.arrow_forward),
                    label: Text(isLastPage ? 'Start LifeSaver' : 'Next'),
                    onPressed: () {
                      if (isLastPage) {
                        widget.onFinish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.medical_information),
                    label: const Text('Set up Medical ID'),
                    onPressed: widget.onOpenMedicalId,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool showLogo;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
    this.showLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showLogo)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/lifesaver_logo.png',
                width: 112,
                height: 112,
              ),
            )
          else
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.red.shade50,
              child: Icon(icon, size: 48, color: Colors.red),
            ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
