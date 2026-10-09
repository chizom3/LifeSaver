import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HospitalVerificationStatus {
  final int correctCount;
  final int incorrectCount;
  final String userVote;

  const HospitalVerificationStatus({
    required this.correctCount,
    required this.incorrectCount,
    required this.userVote,
  });

  factory HospitalVerificationStatus.empty() {
    return const HospitalVerificationStatus(
      correctCount: 0,
      incorrectCount: 0,
      userVote: '',
    );
  }

  factory HospitalVerificationStatus.fromJson(Map<String, dynamic> json) {
    return HospitalVerificationStatus(
      correctCount: json['correctCount'] as int? ?? 0,
      incorrectCount: json['incorrectCount'] as int? ?? 0,
      userVote: json['userVote']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'userVote': userVote,
    };
  }

  String get label {
    if (incorrectCount > correctCount) {
      return 'You reported a problem';
    }
    if (correctCount > 0) {
      return 'You marked this correct';
    }
    return 'Not verified yet';
  }
}

class HospitalVerificationService {
  static const String _key = 'hospital_verification_statuses';

  Future<HospitalVerificationStatus> statusFor(String hospitalId) async {
    final statuses = await _loadStatuses();
    return statuses[hospitalId] ?? HospitalVerificationStatus.empty();
  }

  Future<Map<String, HospitalVerificationStatus>> allStatuses() {
    return _loadStatuses();
  }

  Future<HospitalVerificationStatus> markCorrect(String hospitalId) {
    return _mark(hospitalId, 'correct');
  }

  Future<HospitalVerificationStatus> markIncorrect(String hospitalId) {
    return _mark(hospitalId, 'incorrect');
  }

  Future<HospitalVerificationStatus> _mark(
    String hospitalId,
    String vote,
  ) async {
    final statuses = await _loadStatuses();
    final current = statuses[hospitalId] ?? HospitalVerificationStatus.empty();

    var correctCount = current.correctCount;
    var incorrectCount = current.incorrectCount;
    if (current.userVote == 'correct') correctCount--;
    if (current.userVote == 'incorrect') incorrectCount--;
    if (vote == 'correct') correctCount++;
    if (vote == 'incorrect') incorrectCount++;

    final updated = HospitalVerificationStatus(
      correctCount: correctCount < 0 ? 0 : correctCount,
      incorrectCount: incorrectCount < 0 ? 0 : incorrectCount,
      userVote: vote,
    );
    statuses[hospitalId] = updated;
    await _saveStatuses(statuses);
    return updated;
  }

  Future<Map<String, HospitalVerificationStatus>> _loadStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) {
      return MapEntry(
        key,
        HospitalVerificationStatus.fromJson(value as Map<String, dynamic>),
      );
    });
  }

  Future<void> _saveStatuses(
    Map<String, HospitalVerificationStatus> statuses,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = statuses.map((key, value) {
      return MapEntry(key, value.toJson());
    });
    await prefs.setString(_key, jsonEncode(encoded));
  }
}
