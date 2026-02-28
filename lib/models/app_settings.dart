import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final Color backgroundColor;
  final bool startOnMonday;
  final double backgroundOpacity;

  const AppSettings({
    this.backgroundColor = Colors.black,
    this.startOnMonday = false,
    this.backgroundOpacity = 0.85,
  });

  AppSettings copyWith({
    Color? backgroundColor,
    bool? startOnMonday,
    double? backgroundOpacity,
  }) {
    return AppSettings(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      startOnMonday: startOnMonday ?? this.startOnMonday,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    );
  }

  /// 透過率を適用した背景色を返す
  Color get effectiveBackgroundColor =>
      backgroundColor.withValues(alpha: backgroundOpacity);

  static const String _bgColorKey = 'bg_color';
  static const String _startOnMondayKey = 'start_on_monday';
  static const String _bgOpacityKey = 'bg_opacity';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bgColorKey, backgroundColor.toARGB32().toSigned(32));
    await prefs.setBool(_startOnMondayKey, startOnMonday);
    await prefs.setDouble(_bgOpacityKey, backgroundOpacity);
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final bgColorInt = prefs.getInt(_bgColorKey);
    final startOnMonday = prefs.getBool(_startOnMondayKey) ?? false;
    final bgOpacity = prefs.getDouble(_bgOpacityKey) ?? 0.85;
    return AppSettings(
      backgroundColor: bgColorInt != null ? Color(bgColorInt) : Colors.black,
      startOnMonday: startOnMonday,
      backgroundOpacity: bgOpacity,
    );
  }
}

