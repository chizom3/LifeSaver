import 'package:flutter_tts/flutter_tts.dart';

import '../first_aid_guide.dart';

class FirstAidVoiceService {
  final FlutterTts _tts;

  FirstAidVoiceService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  Future<void> configure() async {
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> readGuide(FirstAidGuide guide) async {
    await configure();
    await _tts.stop();
    await _tts.speak(_scriptFor(guide));
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  String _scriptFor(FirstAidGuide guide) {
    final buffer = StringBuffer()
      ..writeln('${guide.title}.')
      ..writeln(guide.summary)
      ..writeln();

    if (guide.callEmergencyNow) {
      buffer.writeln('Call emergency services now if this is happening.');
    } else {
      buffer.writeln(
        'Call emergency services if symptoms are severe, worsening, or you are unsure.',
      );
    }

    buffer
      ..writeln()
      ..writeln('Warning signs.');
    for (final sign in guide.warningSigns) {
      buffer.writeln(sign);
    }

    buffer
      ..writeln()
      ..writeln('What to do now.');
    for (var index = 0; index < guide.steps.length; index++) {
      buffer.writeln('Step ${index + 1}. ${guide.steps[index]}');
    }

    buffer
      ..writeln()
      ..writeln('Do not.');
    for (final item in guide.doNot) {
      buffer.writeln(item);
    }

    buffer
      ..writeln()
      ..writeln('When to seek care. ${guide.seekCare}');

    return buffer.toString();
  }
}
