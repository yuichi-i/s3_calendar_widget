import 'package:flutter/material.dart';
import '../models/calendar_cell.dart';
import '../models/holiday.dart';

class CalendarService {
  /// 指定月のカレンダーセルリストを生成する（5行×7列=35セル または 6行×7列=42セル）
  /// 当月の日付が5行に収まらない場合は6行にする
  /// 先頭・末尾は前月・次月の日付で埋める
  List<CalendarCell> buildMonthCells({
    required int year,
    required int month,
    required bool startOnMonday,
    required Map<String, Holiday> holidays,
    Color saturdayColor = const Color(0xFF4488FF),
    Color sundayHolidayColor = const Color(0xFFFF4444),
  }) {
    final List<CalendarCell> cells = [];

    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    // 先頭オフセット（前月の残り日数）
    int firstWeekday = firstDay.weekday; // 1=月, 7=日
    int offset;
    if (startOnMonday) {
      offset = firstWeekday - 1;
    } else {
      offset = firstWeekday % 7;
    }

    // 前月の日付でオフセットを埋める
    if (offset > 0) {
      final prevMonthLast = DateTime(year, month, 0); // 前月末日
      for (int i = offset - 1; i >= 0; i--) {
        final date = DateTime(prevMonthLast.year, prevMonthLast.month,
            prevMonthLast.day - i);
        cells.add(CalendarCell(
          date: date,
          dayType: _dayType(date, {}),
          isAdjacentMonth: true,
          saturdayColor: saturdayColor,
          sundayHolidayColor: sundayHolidayColor,
        ));
      }
    }

    // 当月の日付
    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(year, month, day);
      final dateKey = _dateKey(date);
      final holiday = holidays[dateKey];
      DayType dayType;
      if (holiday != null) {
        dayType = DayType.holiday;
      } else {
        dayType = _dayType(date, {});
      }
      cells.add(CalendarCell(
        date: date,
        dayType: dayType,
        holidayName: holiday?.name,
        isAdjacentMonth: false,
        saturdayColor: saturdayColor,
        sundayHolidayColor: sundayHolidayColor,
      ));
    }

    // 次月の日付で末尾を埋める（35セル or 42セル）
    // 当月+オフセットが35を超えたら6行=42セルにする
    final totalCells = cells.length > 35 ? 42 : 35;
    int nextDay = 1;
    while (cells.length < totalCells) {
      final date = DateTime(year, month + 1, nextDay++);
      cells.add(CalendarCell(
        date: date,
        dayType: _dayType(date, {}),
        isAdjacentMonth: true,
        saturdayColor: saturdayColor,
        sundayHolidayColor: sundayHolidayColor,
      ));
    }

    return cells;
  }

  /// 指定月の表示に必要な行数（5 or 6）を返す
  int getRowCount({
    required int year,
    required int month,
    required bool startOnMonday,
  }) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    int firstWeekday = firstDay.weekday;
    int offset = startOnMonday ? firstWeekday - 1 : firstWeekday % 7;
    return (offset + lastDay.day) > 35 ? 6 : 5;
  }

  DayType _dayType(DateTime date, Map<String, Holiday> holidays) {
    if (date.weekday == DateTime.sunday) return DayType.sunday;
    if (date.weekday == DateTime.saturday) return DayType.saturday;
    return DayType.weekday;
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<String> getWeekdayHeaders(bool startOnMonday) {
    if (startOnMonday) {
      return ['月', '火', '水', '木', '金', '土', '日'];
    } else {
      return ['日', '月', '火', '水', '木', '金', '土'];
    }
  }
}

