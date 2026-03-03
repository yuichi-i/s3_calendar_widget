import 'package:flutter/material.dart';

enum DayType { weekday, saturday, sunday, holiday }

class CalendarCell {
  final DateTime? date;
  final DayType dayType;
  final String? holidayName;
  /// 前月または次月の日付かどうか
  final bool isAdjacentMonth;
  /// 土曜日の文字色（外部から設定可能）
  final Color saturdayColor;
  /// 日曜・祝日の文字色（外部から設定可能）
  final Color sundayHolidayColor;

  const CalendarCell({
    this.date,
    required this.dayType,
    this.holidayName,
    this.isAdjacentMonth = false,
    this.saturdayColor = const Color(0xFF4488FF),
    this.sundayHolidayColor = const Color(0xFFFF4444),
  });

  bool get isEmpty => date == null;

  /// 当月の通常色
  Color get textColor {
    switch (dayType) {
      case DayType.sunday:
      case DayType.holiday:
        return sundayHolidayColor;
      case DayType.saturday:
        return saturdayColor;
      case DayType.weekday:
        return Colors.white;
    }
  }

  /// 前月・次月用の薄い色
  Color get dimTextColor {
    switch (dayType) {
      case DayType.sunday:
      case DayType.holiday:
        return sundayHolidayColor.withValues(alpha: 0.4);
      case DayType.saturday:
        return saturdayColor.withValues(alpha: 0.4);
      case DayType.weekday:
        return const Color(0x66FFFFFF);
    }
  }

  /// 実際に使う色（隣接月かどうかで切替）
  Color get effectiveTextColor =>
      isAdjacentMonth ? dimTextColor : textColor;
}
