class FirstAidGuide {
  final String id;
  final String title;
  final String category;
  final String summary;
  final bool callEmergencyNow;
  final List<String> warningSigns;
  final List<String> steps;
  final List<String> doNot;
  final String seekCare;

  const FirstAidGuide({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.callEmergencyNow,
    required this.warningSigns,
    required this.steps,
    required this.doNot,
    required this.seekCare,
  });

  factory FirstAidGuide.fromJson(Map<String, dynamic> json) {
    return FirstAidGuide(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'First aid guide',
      category: json['category']?.toString() ?? 'General',
      summary: json['summary']?.toString() ?? '',
      callEmergencyNow: json['callEmergencyNow'] == true,
      warningSigns: _stringList(json['warningSigns']),
      steps: _stringList(json['steps']),
      doNot: _stringList(json['doNot']),
      seekCare: json['seekCare']?.toString() ?? '',
    );
  }

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    return [
      title,
      category,
      summary,
      ...warningSigns,
      ...steps,
      ...doNot,
      seekCare,
    ].join(' ').toLowerCase().contains(normalizedQuery);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }
}
