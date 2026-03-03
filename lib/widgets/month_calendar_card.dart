import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/calendar_cell.dart';
import '../models/holiday.dart';
import '../services/calendar_service.dart';
import '../services/holiday_service.dart';
import '../services/google_calendar_service.dart';
import 'day_cell_widget.dart';

class MonthCalendarCard extends StatefulWidget {
  final int year;
  final int month;
  final bool startOnMonday;
  final Color backgroundColor;
  /// 土曜日の文字色
  final Color saturdayColor;
  /// 日曜・祝日の文字色
  final Color sundayHolidayColor;
  /// Googleカレンダー連携が有効かどうか
  final bool googleCalendarEnabled;

  const MonthCalendarCard({
    super.key,
    required this.year,
    required this.month,
    required this.startOnMonday,
    required this.backgroundColor,
    this.saturdayColor = const Color(0xFF4488FF),
    this.sundayHolidayColor = const Color(0xFFFF4444),
    this.googleCalendarEnabled = false,
  });

  @override
  State<MonthCalendarCard> createState() => _MonthCalendarCardState();
}

class _MonthCalendarCardState extends State<MonthCalendarCard> {
  final CalendarService _calendarService = CalendarService();
  final HolidayService _holidayService = HolidayService();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();

  List<CalendarCell> _cells = [];
  bool _loading = true;
  int _rowCount = 5; // 5行 or 6行（月によって変わる）
  /// 当月の日付文字列（yyyy-MM-dd）→ イベント色リスト
  Map<String, List<Color>> _eventColors = {};
  /// 前月の日付文字列（yyyy-MM-dd）→ イベント色リスト（薄色用）
  Map<String, List<Color>> _prevEventColors = {};
  /// 次月の日付文字列（yyyy-MM-dd）→ イベント色リスト（薄色用）
  Map<String, List<Color>> _nextEventColors = {};

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
        oldWidget.startOnMonday != widget.startOnMonday ||
        oldWidget.saturdayColor != widget.saturdayColor ||
        oldWidget.sundayHolidayColor != widget.sundayHolidayColor) {
      _loadCells();
    }
    // Googleカレンダー連携のオン/オフが変わった場合もリロード
    if (oldWidget.googleCalendarEnabled != widget.googleCalendarEnabled) {
      _loadEvents();
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
      saturdayColor: widget.saturdayColor,
      sundayHolidayColor: widget.sundayHolidayColor,
    );
    final rowCount = _calendarService.getRowCount(
      year: widget.year,
      month: widget.month,
      startOnMonday: widget.startOnMonday,
    );
    if (mounted) {
      setState(() {
        _cells = cells;
        _rowCount = rowCount;
        _loading = false;
      });
    }
    // セル読み込み後にイベントも取得
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (!widget.googleCalendarEnabled || !_googleCalendarService.isSignedIn) {
      if (mounted) {
        setState(() {
          _eventColors = {};
          _prevEventColors = {};
          _nextEventColors = {};
        });
      }
      return;
    }

    // 当月・前月・次月を並行取得
    final prevMonth = DateTime(widget.year, widget.month - 1);
    final nextMonth = DateTime(widget.year, widget.month + 1);
    final results = await Future.wait([
      _googleCalendarService.fetchEventsForMonth(widget.year, widget.month),
      _googleCalendarService.fetchEventsForMonth(prevMonth.year, prevMonth.month),
      _googleCalendarService.fetchEventsForMonth(nextMonth.year, nextMonth.month),
    ]);

    if (mounted) {
      setState(() {
        _eventColors = results[0];
        _prevEventColors = results[1];
        _nextEventColors = results[2];
      });
    }
  }

  /// 日付キー文字列を生成（yyyy-MM-dd）
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
          // 曜日ヘッダー行
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: headers.map((h) {
                Color color = Colors.white;
                if (widget.startOnMonday) {
                  if (h == '土') color = widget.saturdayColor;
                  if (h == '日') color = widget.sundayHolidayColor;
                } else {
                  if (h == '日') color = widget.sundayHolidayColor;
                  if (h == '土') color = widget.saturdayColor;
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
    // _rowCount行×7列（5行=35セル or 6行=42セル）
    final totalCells = _rowCount * 7;
    final rows = <Widget>[];
    for (int i = 0; i < totalCells; i += 7) {
      final weekCells = _cells.sublist(i, (i + 7).clamp(0, _cells.length));

      // この週の有効な日付リスト（当月のみ）を取得（空セルのフォールバック用）
      final validDatesInWeek = weekCells
          .where((c) => c.date != null && !c.isAdjacentMonth)
          .map((c) => c.date!)
          .toList();

      rows.add(Expanded(
        child: Row(
          children: weekCells.map((cell) {
            final isCurrentMonth = cell.date != null && !cell.isAdjacentMonth;
            final isAdjacentWithDate = cell.date != null && cell.isAdjacentMonth;

            List<Color> colors;
            if (isCurrentMonth) {
              // 当月: 通常色
              colors = _eventColors[_dateKey(cell.date!)] ?? [];
            } else if (isAdjacentWithDate) {
              // 前月・次月: 薄い色で表示
              final key = _dateKey(cell.date!);
              final isPrev = cell.date!.month != widget.month &&
                  (cell.date!.year < widget.year ||
                      (cell.date!.year == widget.year && cell.date!.month < widget.month));
              final base = isPrev
                  ? (_prevEventColors[key] ?? [])
                  : (_nextEventColors[key] ?? []);
              // 透明度 40% で薄くする
              colors = base.map((c) => c.withValues(alpha: 0.4)).toList();
            } else {
              // 空セル
              colors = [];
            }

            // タップ時に開く日付:
            // - 当月セル: その日付
            // - 隣月セル: その日付（隣月でも正しい日付に飛ぶ）
            // - 空セル: 同週の当月内の直近日付
            DateTime? tapDate;
            if (cell.date != null) {
              tapDate = cell.date;
            } else if (validDatesInWeek.isNotEmpty) {
              tapDate = validDatesInWeek.first;
            }

            return Expanded(
              child: DayCellWidget(
                cell: cell,
                fontSize: 12,
                eventColors: colors,
                onTap: tapDate != null
                    ? () => _googleCalendarService.openCalendarOnDate(tapDate!)
                    : null,
              ),
            );
          }).toList(),
        ),
      ));
    }
    return Column(children: rows);
  }
}

