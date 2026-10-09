import 'package:flutter/material.dart';

import '../first_aid_guide.dart';
import '../services/first_aid_voice_service.dart';

class FirstAidDetailPage extends StatefulWidget {
  final FirstAidGuide guide;
  final VoidCallback onCallEmergency;
  final VoidCallback onFindHospitals;

  const FirstAidDetailPage({
    super.key,
    required this.guide,
    required this.onCallEmergency,
    required this.onFindHospitals,
  });

  @override
  State<FirstAidDetailPage> createState() => _FirstAidDetailPageState();
}

class _FirstAidDetailPageState extends State<FirstAidDetailPage> {
  final FirstAidVoiceService _voiceService = FirstAidVoiceService();
  bool _isReading = false;

  @override
  void initState() {
    super.initState();
    _voiceService.setOnFinished(() {
      if (mounted) setState(() => _isReading = false);
    });
  }

  @override
  void dispose() {
    _voiceService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.guide;

    return Scaffold(
      appBar: AppBar(title: Text(guide.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _EmergencyBanner(callEmergencyNow: guide.callEmergencyNow),
            const SizedBox(height: 12),
            Text(
              guide.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(guide.summary),
            const SizedBox(height: 16),
            _ReadAloudCard(
              isReading: _isReading,
              onRead: _readAloud,
              onStop: _stopReading,
            ),
            const SizedBox(height: 8),
            _VisualGuideCard(guide: guide),
            const SizedBox(height: 8),
            _SectionCard(
              title: 'Emergency warning signs',
              icon: Icons.warning_amber,
              color: Colors.red,
              children: guide.warningSigns,
            ),
            _NumberedSectionCard(
              title: 'What to do now',
              icon: Icons.check_circle_outline,
              color: Colors.green,
              children: guide.steps,
            ),
            _SectionCard(
              title: 'Do not',
              icon: Icons.block,
              color: Colors.orange,
              children: guide.doNot,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.local_hospital, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'When to seek care',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(guide.seekCare),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Find hospitals'),
                  onPressed: widget.onFindHospitals,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.call),
                  label: const Text('Call 112'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: widget.onCallEmergency,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _readAloud() async {
    setState(() => _isReading = true);
    try {
      await _voiceService.readGuide(widget.guide);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start read aloud.')),
      );
      setState(() => _isReading = false);
    }
  }

  Future<void> _stopReading() async {
    await _voiceService.stop();
    if (!mounted) return;
    setState(() => _isReading = false);
  }
}

class _ReadAloudCard extends StatelessWidget {
  final bool isReading;
  final VoidCallback onRead;
  final VoidCallback onStop;

  const _ReadAloudCard({
    required this.isReading,
    required this.onRead,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.volume_up, color: Colors.blue.shade800),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Read the warning signs and steps aloud for hands-free guidance.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: Icon(isReading ? Icons.stop : Icons.play_arrow),
              label: Text(isReading ? 'Stop' : 'Read'),
              onPressed: isReading ? onStop : onRead,
            ),
          ],
        ),
      ),
    );
  }
}

class _VisualGuideCard extends StatelessWidget {
  final FirstAidGuide guide;

  const _VisualGuideCard({required this.guide});

  @override
  Widget build(BuildContext context) {
    final visuals = _visualsForGuide(guide);

    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image_search, color: Colors.teal.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Visual guide',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < visuals.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == visuals.length - 1 ? 0 : 12,
                ),
                child: _VisualStepTile(
                  number: index + 1,
                  icon: visuals[index].icon,
                  title: visuals[index].title,
                  body: visuals[index].body,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_VisualStep> _visualsForGuide(FirstAidGuide guide) {
    switch (guide.id) {
      case 'cpr_not_breathing':
        return const [
          _VisualStep(
            icon: Icons.call,
            title: 'Call for help',
            body: 'Call 112 first or ask someone nearby to call.',
          ),
          _VisualStep(
            icon: Icons.compress,
            title: 'Hands in chest center',
            body: 'Place hands in the middle of the chest and push hard/fast.',
          ),
          _VisualStep(
            icon: Icons.repeat,
            title: 'Do not stop',
            body:
                'Continue compressions until help takes over or breathing returns.',
          ),
        ];
      case 'choking_adult_child':
        return const [
          _VisualStep(
            icon: Icons.record_voice_over,
            title: 'Ask if they can cough',
            body: 'If they can cough strongly, encourage coughing.',
          ),
          _VisualStep(
            icon: Icons.back_hand,
            title: 'Back blows',
            body: 'Give firm blows between the shoulder blades if severe.',
          ),
          _VisualStep(
            icon: Icons.accessibility_new,
            title: 'Abdominal thrusts',
            body:
                'Use abdominal thrusts only if trained and severe choking continues.',
          ),
        ];
      case 'infant_choking':
        return const [
          _VisualStep(
            icon: Icons.child_care,
            title: 'Face down support',
            body: 'Support the baby face down with head lower than chest.',
          ),
          _VisualStep(
            icon: Icons.back_hand,
            title: '5 back blows',
            body: 'Give firm back blows between the shoulder blades.',
          ),
          _VisualStep(
            icon: Icons.favorite,
            title: '5 chest thrusts',
            body: 'Turn face up and use two fingers for chest thrusts.',
          ),
        ];
      case 'severe_bleeding':
      case 'internal_bleeding':
        return const [
          _VisualStep(
            icon: Icons.pan_tool,
            title: 'Direct pressure',
            body: 'Press firmly with clean cloth or dressing.',
          ),
          _VisualStep(
            icon: Icons.layers,
            title: 'Add cloth, keep pressure',
            body: 'Do not remove soaked cloth; add more and keep pressing.',
          ),
          _VisualStep(
            icon: Icons.airline_seat_flat,
            title: 'Watch for shock',
            body: 'Help them lie still and keep warm.',
          ),
        ];
      case 'burns':
        return const [
          _VisualStep(
            icon: Icons.water_drop,
            title: 'Cool with water',
            body: 'Use cool running water for at least 20 minutes.',
          ),
          _VisualStep(
            icon: Icons.do_not_touch,
            title: 'Remove tight items',
            body: 'Remove jewelry near the burn unless stuck.',
          ),
          _VisualStep(
            icon: Icons.health_and_safety,
            title: 'Cover loosely',
            body: 'Use a clean non-stick dressing or cloth.',
          ),
        ];
      case 'stroke':
        return const [
          _VisualStep(
            icon: Icons.face,
            title: 'Face',
            body: 'Look for one-sided facial drooping.',
          ),
          _VisualStep(
            icon: Icons.accessibility,
            title: 'Arms',
            body: 'Check for one weak or drifting arm.',
          ),
          _VisualStep(
            icon: Icons.record_voice_over,
            title: 'Speech and time',
            body:
                'Slurred speech means call 112 immediately and note the time.',
          ),
        ];
      case 'heart_attack':
      case 'asthma_attack':
      case 'allergic_reaction':
      case 'opioid_overdose':
        return const [
          _VisualStep(
            icon: Icons.event_seat,
            title: 'Comfortable position',
            body:
                'Help them rest in the position that makes breathing easiest.',
          ),
          _VisualStep(
            icon: Icons.medication,
            title: 'Use prescribed medicine',
            body: 'Help with their own prescribed medicine if available.',
          ),
          _VisualStep(
            icon: Icons.call,
            title: 'Call 112 if severe',
            body:
                'Do not wait if breathing, chest pain, or consciousness worsens.',
          ),
        ];
      case 'seizure':
        return const [
          _VisualStep(
            icon: Icons.clear_all,
            title: 'Clear space',
            body: 'Move objects away to prevent injury.',
          ),
          _VisualStep(
            icon: Icons.timer,
            title: 'Time it',
            body: 'Call 112 if it lasts over 5 minutes or repeats.',
          ),
          _VisualStep(
            icon: Icons.airline_seat_individual_suite,
            title: 'Side position',
            body: 'After shaking stops, place on side if breathing.',
          ),
        ];
      case 'nosebleed':
        return const [
          _VisualStep(
            icon: Icons.arrow_downward,
            title: 'Lean forward',
            body: 'Sit upright and lean forward, not backward.',
          ),
          _VisualStep(
            icon: Icons.front_hand,
            title: 'Pinch soft nose',
            body: 'Hold steady pressure for 10 to 15 minutes.',
          ),
        ];
      case 'fracture_sprain':
      case 'head_neck_spinal_injury':
      case 'concussion':
        return const [
          _VisualStep(
            icon: Icons.pause_circle_outline,
            title: 'Keep still',
            body: 'Stop movement and support the injured area.',
          ),
          _VisualStep(
            icon: Icons.ac_unit,
            title: 'Cold pack if suitable',
            body: 'Wrap cold pack in cloth; do not place ice directly on skin.',
          ),
          _VisualStep(
            icon: Icons.local_hospital,
            title: 'Seek care',
            body:
                'Get medical review for severe pain, deformity, or head injury signs.',
          ),
        ];
      case 'heat_stroke':
      case 'hypothermia':
      case 'dehydration':
        return const [
          _VisualStep(
            icon: Icons.place,
            title: 'Move to safety',
            body:
                'Move to a cooler or warmer safe place based on the emergency.',
          ),
          _VisualStep(
            icon: Icons.thermostat,
            title: 'Correct temperature',
            body:
                'Cool rapidly for heat stroke; warm gradually for hypothermia.',
          ),
          _VisualStep(
            icon: Icons.water_drop,
            title: 'Fluids only if safe',
            body: 'Give small sips only if fully awake and able to swallow.',
          ),
        ];
      default:
        return [
          _VisualStep(
            icon: guide.callEmergencyNow ? Icons.call : Icons.visibility,
            title: guide.callEmergencyNow
                ? 'Call 112 early'
                : 'Check warning signs',
            body: guide.callEmergencyNow
                ? 'Call emergency services first when warning signs are present.'
                : 'Look for severe symptoms and call 112 if unsure.',
          ),
          const _VisualStep(
            icon: Icons.check_circle_outline,
            title: 'Follow steps in order',
            body:
                'Work through the first aid steps while monitoring breathing.',
          ),
          const _VisualStep(
            icon: Icons.local_hospital,
            title: 'Get medical care',
            body: 'Use Find hospitals or call emergency services when needed.',
          ),
        ];
    }
  }
}

class _VisualStepTile extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String body;

  const _VisualStepTile({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.teal.shade100),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(64, 64),
                painter: _FirstAidIllustrationPainter(title, icon),
              ),
              Positioned(
                top: 5,
                left: 5,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisualStep {
  final IconData icon;
  final String title;
  final String body;

  const _VisualStep({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _FirstAidIllustrationPainter extends CustomPainter {
  final String title;
  final IconData fallbackIcon;

  const _FirstAidIllustrationPainter(this.title, this.fallbackIcon);

  @override
  void paint(Canvas canvas, Size size) {
    final key = title.toLowerCase();
    final teal = Paint()
      ..color = Colors.teal.shade700
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final red = Paint()
      ..color = Colors.red.shade500
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(size.center(Offset.zero), 28, fill);

    if (key.contains('hands') || key.contains('stop')) {
      _drawLyingPerson(canvas, size, teal);
      canvas.drawLine(
        Offset(size.width * .35, size.height * .45),
        Offset(size.width * .65, size.height * .45),
        red,
      );
      canvas.drawLine(
        Offset(size.width * .50, size.height * .22),
        Offset(size.width * .50, size.height * .48),
        red,
      );
      return;
    }

    if (key.contains('back blow') || key.contains('thrust')) {
      _drawStandingPerson(canvas, size, teal);
      canvas.drawLine(
        Offset(size.width * .16, size.height * .30),
        Offset(size.width * .42, size.height * .40),
        red,
      );
      canvas.drawLine(
        Offset(size.width * .18, size.height * .42),
        Offset(size.width * .42, size.height * .48),
        red,
      );
      return;
    }

    if (key.contains('face down') || key.contains('chest thrust')) {
      canvas.drawCircle(Offset(size.width * .24, size.height * .40), 7, teal);
      canvas.drawLine(
        Offset(size.width * .32, size.height * .42),
        Offset(size.width * .74, size.height * .50),
        teal,
      );
      canvas.drawLine(
        Offset(size.width * .48, size.height * .20),
        Offset(size.width * .48, size.height * .42),
        red,
      );
      return;
    }

    if (key.contains('pressure') || key.contains('cloth')) {
      canvas.drawLine(
        Offset(size.width * .18, size.height * .50),
        Offset(size.width * .82, size.height * .50),
        teal,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * .50, size.height * .50),
            width: 26,
            height: 18,
          ),
          const Radius.circular(4),
        ),
        red,
      );
      canvas.drawLine(
        Offset(size.width * .50, size.height * .18),
        Offset(size.width * .50, size.height * .40),
        red,
      );
      return;
    }

    if (key.contains('water') || key.contains('cool')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * .38, size.height * .46, 22, 12),
          const Radius.circular(6),
        ),
        red,
      );
      for (var i = 0; i < 4; i++) {
        final x = size.width * (.24 + i * .14);
        canvas.drawLine(Offset(x, 14), Offset(x - 4, 35), teal);
      }
      return;
    }

    if (key.contains('side') || key.contains('shock')) {
      canvas.drawCircle(Offset(size.width * .26, size.height * .35), 7, teal);
      canvas.drawLine(
        Offset(size.width * .34, size.height * .42),
        Offset(size.width * .70, size.height * .54),
        teal,
      );
      canvas.drawLine(
        Offset(size.width * .46, size.height * .48),
        Offset(size.width * .34, size.height * .62),
        teal,
      );
      canvas.drawLine(
        Offset(size.width * .58, size.height * .52),
        Offset(size.width * .76, size.height * .36),
        teal,
      );
      return;
    }

    if (key.contains('face') || key.contains('arm') || key.contains('speech')) {
      canvas.drawCircle(size.center(const Offset(0, -2)), 17, teal);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * .50, size.height * .54),
          width: 22,
          height: 12,
        ),
        0,
        3.14,
        false,
        red,
      );
      return;
    }

    _drawFallbackIcon(canvas, size);
  }

  void _drawLyingPerson(Canvas canvas, Size size, Paint paint) {
    canvas.drawCircle(Offset(size.width * .24, size.height * .44), 7, paint);
    canvas.drawLine(
      Offset(size.width * .32, size.height * .46),
      Offset(size.width * .74, size.height * .46),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .52, size.height * .46),
      Offset(size.width * .72, size.height * .64),
      paint,
    );
  }

  void _drawStandingPerson(Canvas canvas, Size size, Paint paint) {
    canvas.drawCircle(Offset(size.width * .56, size.height * .20), 7, paint);
    canvas.drawLine(
      Offset(size.width * .54, size.height * .30),
      Offset(size.width * .48, size.height * .58),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .48, size.height * .58),
      Offset(size.width * .38, size.height * .82),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .48, size.height * .58),
      Offset(size.width * .62, size.height * .82),
      paint,
    );
  }

  void _drawFallbackIcon(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(fallbackIcon.codePoint),
        style: TextStyle(
          fontSize: 30,
          fontFamily: fallbackIcon.fontFamily,
          package: fallbackIcon.fontPackage,
          color: Colors.teal.shade800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _FirstAidIllustrationPainter oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.fallbackIcon != fallbackIcon;
  }
}

class _EmergencyBanner extends StatelessWidget {
  final bool callEmergencyNow;

  const _EmergencyBanner({required this.callEmergencyNow});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: callEmergencyNow ? Colors.red.shade50 : Colors.amber.shade50,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              callEmergencyNow ? Icons.emergency : Icons.info_outline,
              color: callEmergencyNow ? Colors.red : Colors.amber.shade900,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                callEmergencyNow
                    ? 'Call 112 now if this is happening. Follow dispatcher instructions.'
                    : 'Use this as general first aid guidance. Call 112 if symptoms are severe, worsening, or you are unsure.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in children)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('- '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NumberedSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> children;

  const _NumberedSectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < children.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.green.shade50,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(children[index])),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
