import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final Color backgroundColor;
  final bool startOnMonday;
  final double backgroundOpacity;

  /// 土曜日の文字色
  final Color saturdayColor;

  /// 日曜・祝日の文字色
  final Color sundayHolidayColor;

  /// Googleカレンダー表示の●色（1件目）
  final Color firstEventDotColor;

  /// Googleカレンダー表示の●色（2件目）
  final Color secondEventDotColor;

  /// Googleカレンダー表示の●色（3件目）
  final Color thirdEventDotColor;

  const AppSettings({
    this.backgroundColor = Colors.black,
    this.startOnMonday = false,
    this.backgroundOpacity = 0.85,
    this.saturdayColor = const Color(0xFF4488FF),
    this.sundayHolidayColor = const Color(0xFFFF4444),
    this.firstEventDotColor = const Color(0xFF00E5FF),
    this.secondEventDotColor = const Color(0xFFFFEA00),
    this.thirdEventDotColor = const Color(0xFFFF4081),
  });

  AppSettings copyWith({
    Color? backgroundColor,
    bool? startOnMonday,
    double? backgroundOpacity,
    Color? saturdayColor,
    Color? sundayHolidayColor,
    Color? firstEventDotColor,
    Color? secondEventDotColor,
    Color? thirdEventDotColor,
  }) {
    return AppSettings(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      startOnMonday: startOnMonday ?? this.startOnMonday,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      saturdayColor: saturdayColor ?? this.saturdayColor,
      sundayHolidayColor: sundayHolidayColor ?? this.sundayHolidayColor,
      firstEventDotColor: firstEventDotColor ?? this.firstEventDotColor,
      secondEventDotColor: secondEventDotColor ?? this.secondEventDotColor,
      thirdEventDotColor: thirdEventDotColor ?? this.thirdEventDotColor,
    );
  }

  /// 透過率を適用した背景色を返す
  Color get effectiveBackgroundColor =>
      backgroundColor.withValues(alpha: backgroundOpacity);

  static const String _bgColorKey = 'bg_color';
  static const String _startOnMondayKey = 'start_on_monday';
  static const String _bgOpacityKey = 'bg_opacity';
  static const String _saturdayColorKey = 'saturday_color';
  static const String _sundayHolidayColorKey = 'sunday_holiday_color';
  static const String _firstEventDotColorKey = 'first_event_dot_color';
  static const String _secondEventDotColorKey = 'second_event_dot_color';
  static const String _thirdEventDotColorKey = 'third_event_dot_color';

  // Googleカレンダー/タスクの月別キャッシュ保存先キー
  static const String googleEventCacheKeyPrefix = 'google_event_cache_';
  static const String googleEventCacheDateKeyPrefix =
      'google_event_cache_date_';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bgColorKey, backgroundColor.toARGB32().toSigned(32));
    await prefs.setBool(_startOnMondayKey, startOnMonday);
    await prefs.setDouble(_bgOpacityKey, backgroundOpacity);
    await prefs.setInt(
      _saturdayColorKey,
      saturdayColor.toARGB32().toSigned(32),
    );
    await prefs.setInt(
      _sundayHolidayColorKey,
      sundayHolidayColor.toARGB32().toSigned(32),
    );
    await prefs.setInt(
      _firstEventDotColorKey,
      firstEventDotColor.toARGB32().toSigned(32),
    );
    await prefs.setInt(
      _secondEventDotColorKey,
      secondEventDotColor.toARGB32().toSigned(32),
    );
    await prefs.setInt(
      _thirdEventDotColorKey,
      thirdEventDotColor.toARGB32().toSigned(32),
    );
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final bgColorInt = prefs.getInt(_bgColorKey);
    final startOnMonday = prefs.getBool(_startOnMondayKey) ?? false;
    final bgOpacity = prefs.getDouble(_bgOpacityKey) ?? 0.85;
    final satColorInt = prefs.getInt(_saturdayColorKey);
    final sunHolColorInt = prefs.getInt(_sundayHolidayColorKey);
    final firstEventDotColorInt = prefs.getInt(_firstEventDotColorKey);
    final secondEventDotColorInt = prefs.getInt(_secondEventDotColorKey);
    final thirdEventDotColorInt = prefs.getInt(_thirdEventDotColorKey);
    return AppSettings(
      backgroundColor: bgColorInt != null ? Color(bgColorInt) : Colors.black,
      startOnMonday: startOnMonday,
      backgroundOpacity: bgOpacity,
      saturdayColor: satColorInt != null
          ? Color(satColorInt)
          : const Color(0xFF4488FF),
      sundayHolidayColor: sunHolColorInt != null
          ? Color(sunHolColorInt)
          : const Color(0xFFFF4444),
      firstEventDotColor: firstEventDotColorInt != null
          ? Color(firstEventDotColorInt)
          : const Color(0xFF00E5FF),
      secondEventDotColor: secondEventDotColorInt != null
          ? Color(secondEventDotColorInt)
          : const Color(0xFFFFEA00),
      thirdEventDotColor: thirdEventDotColorInt != null
          ? Color(thirdEventDotColorInt)
          : const Color(0xFFFF4081),
    );
  }
}
