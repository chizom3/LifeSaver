import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../first_aid_guide.dart';

class FirstAidRepository {
  Future<List<FirstAidGuide>> loadGuides() async {
    final response = await rootBundle.loadString(
      'assets/data/first_aid_guides.json',
    );
    final data = json.decode(response) as List<dynamic>;
    final guides = data.map((item) {
      return FirstAidGuide.fromJson(item as Map<String, dynamic>);
    }).toList();

    guides.sort((a, b) {
      final categoryCompare = a.category.compareTo(b.category);
      if (categoryCompare != 0) return categoryCompare;
      return a.title.compareTo(b.title);
    });
    return guides;
  }

  List<FirstAidGuide> filterGuides(List<FirstAidGuide> guides, String query) {
    return guides.where((guide) => guide.matches(query)).toList();
  }

  List<String> categories(List<FirstAidGuide> guides) {
    final values = guides.map((guide) => guide.category).toSet().toList();
    values.sort();
    return values;
  }
}
