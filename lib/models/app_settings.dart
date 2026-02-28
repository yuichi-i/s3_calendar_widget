import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final Color backgroundColor;
  final bool startOnMonday;

  const AppSettings({
    this.backgroundColor = Colors.black,
    this.startOnMonday = false,
  });

  AppSettings copyWith({Color? backgroundColor, bool? startOnMonday}) {
    return AppSettings(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      startOnMonday: startOnMonday ?? this.startOnMonday,
    );
  }

  static const String _bgColorKey = 'bg_color';
  static const String _startOnMondayKey = 'start_on_monday';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bgColorKey, backgroundColor.toARGB32().toSigned(32));
    await prefs.setBool(_startOnMondayKey, startOnMonday);
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final bgColorInt = prefs.getInt(_bgColorKey);
    final startOnMonday = prefs.getBool(_startOnMondayKey) ?? false;
    return AppSettings(
      backgroundColor: bgColorInt != null
          ? Color(bgColorInt)
          : Colors.black,
      startOnMonday: startOnMonday,
    );
  }
}

