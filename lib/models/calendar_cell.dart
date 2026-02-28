import 'package:flutter/material.dart';

enum DayType { weekday, saturday, sunday, holiday }

class CalendarCell {
  final DateTime? date;
  final DayType dayType;
  final String? holidayName;
  /// 前月または次月の日付かどうか
  final bool isAdjacentMonth;

  const CalendarCell({
    this.date,
    required this.dayType,
    this.holidayName,
    this.isAdjacentMonth = false,
  });

  bool get isEmpty => date == null;

  /// 当月の通常色
  Color get textColor {
    switch (dayType) {
      case DayType.sunday:
      case DayType.holiday:
        return const Color(0xFFFF4444);
      case DayType.saturday:
        return const Color(0xFF4488FF);
      case DayType.weekday:
        return Colors.white;
    }
  }

  /// 前月・次月用の薄い色
  Color get dimTextColor {
    switch (dayType) {
      case DayType.sunday:
      case DayType.holiday:
        return const Color(0x66FF4444);
      case DayType.saturday:
        return const Color(0x664488FF);
      case DayType.weekday:
        return const Color(0x66FFFFFF);
    }
  }

  /// 実際に使う色（隣接月かどうかで切替）
  Color get effectiveTextColor =>
      isAdjacentMonth ? dimTextColor : textColor;
}
