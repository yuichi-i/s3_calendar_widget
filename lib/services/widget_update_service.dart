import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/app_settings.dart';
import 'calendar_service.dart';
import 'holiday_service.dart';

const String _androidWidgetName = 'CalendarWidgetProvider';

class WidgetUpdateService {
  final CalendarService _calendarService = CalendarService();
  final HolidayService _holidayService = HolidayService();

  Future<void> updateCalendarWidget({
    required AppSettings settings,
    DateTime? targetMonth,
  }) async {
    final now = targetMonth ?? DateTime.now();
    final year = now.year;
    final month = now.month;

    // 当月の祝日取得
    final holidayMap = await _holidayService.getHolidayMapForMonth(year, month);
    debugPrint('[WidgetUpdate] holidays for $year/$month: ${holidayMap.length} → ${holidayMap.keys.toList()}');

    // カレンダーセル生成
    final cells = _calendarService.buildMonthCells(
      year: year,
      month: month,
      startOnMonday: settings.startOnMonday,
      holidays: holidayMap,
    );

    // セルデータをJSON化
    final cellData = cells.map((cell) {
      return {
        'date': cell.date?.toIso8601String() ?? '',
        'day': cell.date?.day ?? 0,
        'colorType': cell.dayType.name,
        'isAdjacentMonth': cell.isAdjacentMonth,
      };
    }).toList();

    // 曜日ヘッダー
    final dowHeaders = _calendarService.getWeekdayHeaders(settings.startOnMonday);

    // 祝日日付リストをKotlinフォールバック用に保存
    // 当月分 + 年全体の祝日をマージしてすべて保存（前後月の祝日も参照できるよう）
    final allHolidaysOfYear = await _holidayService.getHolidays(year);
    final allHolidayDates = allHolidaysOfYear
        .map((h) =>
            '${h.date.year}-${h.date.month.toString().padLeft(2, '0')}-${h.date.day.toString().padLeft(2, '0')}')
        .toList();
    debugPrint('[WidgetUpdate] total holiday dates saved: ${allHolidayDates.length}');

    // home_widget経由でAndroidに保存
    await HomeWidget.saveWidgetData<String>(
        'calendar_widget_data', jsonEncode(cellData));
    await HomeWidget.saveWidgetData<int>(
        'widget_bg_color', settings.backgroundColor.toARGB32());
    await HomeWidget.saveWidgetData<bool>(
        'widget_start_on_monday', settings.startOnMonday);
    await HomeWidget.saveWidgetData<String>(
        'widget_dow_headers', jsonEncode(dowHeaders));
    await HomeWidget.saveWidgetData<String>(
        'widget_holiday_dates', jsonEncode(allHolidayDates));

    // ウィジェット更新をトリガー
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
    );
  }
}

