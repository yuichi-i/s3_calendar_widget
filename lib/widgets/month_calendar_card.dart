import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/calendar_cell.dart';
import '../models/holiday.dart';
import '../services/calendar_service.dart';
import '../services/holiday_service.dart';
import 'day_cell_widget.dart';

class MonthCalendarCard extends StatefulWidget {
  final int year;
  final int month;
  final bool startOnMonday;
  final Color backgroundColor;

  const MonthCalendarCard({
    super.key,
    required this.year,
    required this.month,
    required this.startOnMonday,
    required this.backgroundColor,
  });

  @override
  State<MonthCalendarCard> createState() => _MonthCalendarCardState();
}

class _MonthCalendarCardState extends State<MonthCalendarCard> {
  final CalendarService _calendarService = CalendarService();
  final HolidayService _holidayService = HolidayService();

  List<CalendarCell> _cells = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCells();
  }

  @override
  void didUpdateWidget(MonthCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year ||
        oldWidget.month != widget.month ||
        oldWidget.startOnMonday != widget.startOnMonday) {
      _loadCells();
    }
  }

  Future<void> _loadCells() async {
    setState(() => _loading = true);
    final Map<String, Holiday> holidays = await _holidayService
        .getHolidayMapForMonth(widget.year, widget.month);
    final cells = _calendarService.buildMonthCells(
      year: widget.year,
      month: widget.month,
      startOnMonday: widget.startOnMonday,
      holidays: holidays,
    );
    if (mounted) {
      setState(() {
        _cells = cells;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final headers = _calendarService.getWeekdayHeaders(widget.startOnMonday);

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 月ヘッダー
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${widget.year}年 ${widget.month}月',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // 曜日ヘッダー行（上下パディングを追加して間隔を広げる）
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: headers.map((h) {
                Color color = Colors.white;
                if (widget.startOnMonday) {
                  if (h == '土') color = const Color(0xFF4488FF);
                  if (h == '日') color = const Color(0xFFFF4444);
                } else {
                  if (h == '日') color = const Color(0xFFFF4444);
                  if (h == '土') color = const Color(0xFF4488FF);
                }
                return Expanded(
                  child: Center(
                    child: Text(
                      h,
                      style: GoogleFonts.rajdhani(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // 区切り線
          Container(height: 0.5, color: Colors.white12),
          const SizedBox(height: 2),
          // カレンダーグリッド（常に5行）
          if (_loading)
            const Expanded(
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            )
          else
            Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    // 常に35セル（5行×7列）
    final rows = <Widget>[];
    for (int i = 0; i < 35; i += 7) {
      final weekCells = _cells.sublist(i, (i + 7).clamp(0, _cells.length));
      rows.add(Expanded(
        child: Row(
          children: weekCells.map((cell) {
            return Expanded(
              child: DayCellWidget(cell: cell, fontSize: 12),
            );
          }).toList(),
        ),
      ));
    }
    return Column(children: rows);
  }
}

