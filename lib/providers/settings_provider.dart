import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;
  Color get backgroundColor => _settings.backgroundColor;
  bool get startOnMonday => _settings.startOnMonday;

  Future<void> init() async {
    _settings = await AppSettings.load();
    notifyListeners();
  }

  Future<void> setBackgroundColor(Color color) async {
    _settings = _settings.copyWith(backgroundColor: color);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setStartOnMonday(bool value) async {
    _settings = _settings.copyWith(startOnMonday: value);
    await _settings.save();
    notifyListeners();
  }
}

