import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  String getLocale() {
    return _prefs.getString(AppConstants.storageLocaleKey) ?? 'vi';
  }

  Future<bool> setLocale(String languageCode) {
    return _prefs.setString(AppConstants.storageLocaleKey, languageCode);
  }

  List<String> getFavorites() {
    return _prefs.getStringList(AppConstants.storageFavoritesKey) ?? [];
  }

  Future<bool> setFavorites(List<String> villaIds) {
    return _prefs.setStringList(AppConstants.storageFavoritesKey, villaIds);
  }
}
