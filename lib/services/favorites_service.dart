import 'package:shared_preferences/shared_preferences.dart';

import '../hospital.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorite_hospital_ids';

  Future<Set<String>> loadFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoritesKey) ?? []).toSet();
  }

  Future<void> saveFavoriteIds(Set<String> favoriteIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favoriteIds.toList()..sort());
  }

  String hospitalId(Hospital hospital) {
    return hospital.hospitalKey;
  }

  bool isFavorite(Hospital hospital, Set<String> favoriteIds) {
    return favoriteIds.contains(hospitalId(hospital));
  }
}
