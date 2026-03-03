import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;
  Color get backgroundColor => _settings.backgroundColor;
  bool get startOnMonday => _settings.startOnMonday;
  double get backgroundOpacity => _settings.backgroundOpacity;
  /// 土曜日の文字色
  Color get saturdayColor => _settings.saturdayColor;
  /// 日曜・祝日の文字色
  Color get sundayHolidayColor => _settings.sundayHolidayColor;

  Future<void> init() async {
    _settings = await AppSettings.load();
    notifyListeners();
  }

  Future<void> setBackgroundColor(Color color) async {
    _settings = _settings.copyWith(backgroundColor: color);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setBackgroundOpacity(double opacity) async {
    _settings = _settings.copyWith(backgroundOpacity: opacity);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setStartOnMonday(bool value) async {
    _settings = _settings.copyWith(startOnMonday: value);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setSaturdayColor(Color color) async {
    _settings = _settings.copyWith(saturdayColor: color);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setSundayHolidayColor(Color color) async {
    _settings = _settings.copyWith(sundayHolidayColor: color);
    await _settings.save();
    notifyListeners();
  }
}
