import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/calendar_service.dart';
import '../services/google_calendar_service.dart';
import '../services/widget_update_service.dart';
import '../widgets/month_calendar_card.dart';
import 'settings_screen.dart';

// スクロール位置を PageStorage に保存するためのキー
const _scrollKey = PageStorageKey<String>('calendar_list_scroll');

class CalendarListScreen extends StatefulWidget {
  const CalendarListScreen({super.key});

  @override
  State<CalendarListScreen> createState() => _CalendarListScreenState();
}

class _CalendarListScreenState extends State<CalendarListScreen> {
  final WidgetUpdateService _widgetUpdateService = WidgetUpdateService();
  final CalendarService _calendarService = CalendarService();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();

  // 表示する月のリスト（過去→現在→未来）
  late List<DateTime> _months;
  late ScrollController _scrollController;

  // 一度に読み込む月数（初期: 前後6ヶ月）
  static const int _initialMonthsEach = 6;
  // 追加読み込み単位（クッション経由で追加する月数）
  static const int _loadMoreCount = 6;

  // 今月が何番目のインデックスか
  late int _currentMonthIndex;

  // Googleカレンダーイベントキャッシュ: "yyyy-M" → イベントマップ
  Map<String, Map<String, List<Color>>> _allEventData = {};
  // イベント読み込み中フラグ
  bool _loadingEvents = false;
  // 過去方向・未来方向のクッション追加中フラグ（二重発火防止）
  bool _loadingPast = false;
  bool _loadingFuture = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = _generateMonths(
      DateTime(now.year, now.month - _initialMonthsEach),
      _initialMonthsEach * 2 + 1,
    );
    // 今月のインデックス = _initialMonthsEach（前6ヶ月スタートなので6番目）
    _currentMonthIndex = _initialMonthsEach;

    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SettingsProvider>(context, listen: false);
      void onProviderReady() {
        _updateWidget();
        provider.removeListener(onProviderReady);
        // Google カレンダーが有効な場合は初期表示分のイベントを一括取得
        if (provider.googleCalendarEnabled) {
          _loadEventsForVisibleRange();
        }
      }
      if (provider.settings.backgroundColor != const Color(0xFF000000) ||
          provider.startOnMonday) {
        _updateWidget();
        if (provider.googleCalendarEnabled) {
          _loadEventsForVisibleRange();
        }
      } else {
        provider.addListener(onProviderReady);
        Future.delayed(const Duration(milliseconds: 500), () {
          provider.removeListener(onProviderReady);
          if (mounted) {
            _updateWidget();
            if (provider.googleCalendarEnabled) {
              _loadEventsForVisibleRange();
            }
          }
        });
      }
      _scrollToCurrentMonthIfNeeded();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<DateTime> _generateMonths(DateTime start, int count) {
    return List.generate(count, (i) => DateTime(start.year, start.month + i));
  }

  /// 現在表示中の月リスト全体（前後1ヶ月バッファ含む）のイベントを一括取得する
  Future<void> _loadEventsForVisibleRange() async {
    if (_loadingEvents) return;
    if (!_googleCalendarService.isSignedIn) return;

    setState(() => _loadingEvents = true);

    // 表示月の前後1ヶ月を含めて取得（隣月セルの薄色表示のため）
    final oldest = _months.first;
    final newest = _months.last;
    final fetchMonths = _generateMonths(
      DateTime(oldest.year, oldest.month - 1),
      _months.length + 2,
    );
    // 最後月も+1ヶ月まで含める
    final extendedFetch = [...fetchMonths, DateTime(newest.year, newest.month + 1)];

    final result = await _googleCalendarService.fetchEventsForMonths(extendedFetch);

    if (mounted) {
      setState(() {
        _allEventData = {..._allEventData, ...result};
        _loadingEvents = false;
      });
    }
  }

  /// 追加された月分のイベントを取得する（既存キャッシュと差分のみ）
  Future<void> _loadEventsForNewMonths(List<DateTime> newMonths) async {
    if (!_googleCalendarService.isSignedIn) return;

    // バッファ月を含めて取得
    final withBuffer = <DateTime>[];
    for (final m in newMonths) {
      withBuffer.add(DateTime(m.year, m.month - 1));
      withBuffer.add(m);
      withBuffer.add(DateTime(m.year, m.month + 1));
    }
    // 重複除去
    final unique = withBuffer.toSet().toList();

    final result = await _googleCalendarService.fetchEventsForMonths(unique);

    if (mounted) {
      setState(() {
        _allEventData = {..._allEventData, ...result};
      });
    }
  }

  /// 初回表示時（PageStorageに保存された位置がない場合）に今月へジャンプする
  void _scrollToCurrentMonthIfNeeded() {
    final savedOffset =
        PageStorage.of(context).readState(context, identifier: _scrollKey);
    if (savedOffset != null) return;
    if (!_scrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 8.0;
    const spacing = 8.0;
    const crossAxisCount = 2;
    final cellWidth =
        (screenWidth - padding * 2 - spacing * (crossAxisCount - 1)) / crossAxisCount;

    // 今月までの各行の高さを合計してスクロールオフセットを計算
    // +1: 先頭のクッションバナー分のオフセット（バナーなし列は0）
    double offset = padding;
    for (int i = 0; i < _currentMonthIndex; i += crossAxisCount) {
      final leftM = i < _months.length ? _months[i] : null;
      final rightM = i + 1 < _months.length ? _months[i + 1] : null;
      double rowH = 0;
      for (final m in [leftM, rightM]) {
        if (m == null) continue;
        final rows = _calendarService.getRowCount(
          year: m.year,
          month: m.month,
          startOnMonday: Provider.of<SettingsProvider>(context, listen: false).startOnMonday,
        );
        final ratio = rows == 6 ? 0.70 : 0.78;
        final h = cellWidth / ratio;
        if (h > rowH) rowH = h;
      }
      offset += rowH + spacing;
    }

    _scrollController.jumpTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  /// 過去方向に6ヶ月追加する（クッションバナータップ時に呼ぶ）
  Future<void> _loadPastMonths() async {
    if (_loadingPast) return;
    setState(() => _loadingPast = true);

    final oldest = _months.first;
    final newMonths = _generateMonths(
      DateTime(oldest.year, oldest.month - _loadMoreCount),
      _loadMoreCount,
    );

    setState(() {
      _months = [...newMonths, ..._months];
      // 先頭に追加した分インデックスをずらす
      _currentMonthIndex += _loadMoreCount;
      _loadingPast = false;
    });

    // 追加分のイベントを取得
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    if (provider.googleCalendarEnabled) {
      await _loadEventsForNewMonths(newMonths);
    }
  }

  /// 未来方向に6ヶ月追加する（クッションバナータップ時に呼ぶ）
  Future<void> _loadFutureMonths() async {
    if (_loadingFuture) return;
    setState(() => _loadingFuture = true);

    final newest = _months.last;
    final newMonths = _generateMonths(
      DateTime(newest.year, newest.month + 1),
      _loadMoreCount,
    );

    setState(() {
      _months = [..._months, ...newMonths];
      _loadingFuture = false;
    });

    // 追加分のイベントを取得
    final provider = Provider.of<SettingsProvider>(context, listen: false);
    if (provider.googleCalendarEnabled) {
      await _loadEventsForNewMonths(newMonths);
    }
  }

  Future<void> _updateWidget() async {
    final settings =
        Provider.of<SettingsProvider>(context, listen: false).settings;
    await _widgetUpdateService.updateCalendarWidget(settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final settings = settingsProvider.settings;

        // Googleカレンダー連携のオン/オフが変わった場合にイベントを再取得
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (settingsProvider.googleCalendarEnabled &&
              _allEventData.isEmpty &&
              !_loadingEvents) {
            _loadEventsForVisibleRange();
          } else if (!settingsProvider.googleCalendarEnabled &&
              _allEventData.isNotEmpty) {
            setState(() => _allEventData = {});
          }
        });

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              'カレンダー',
              style: GoogleFonts.rajdhani(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                  // 設定変更後にウィジェット更新
                  await _updateWidget();
                  // Googleカレンダーが有効になっていればイベントを取得
                  if (mounted &&
                      settingsProvider.googleCalendarEnabled &&
                      _allEventData.isEmpty) {
                    await _loadEventsForVisibleRange();
                  }
                },
              ),
            ],
          ),
          body: _buildCalendarList(
            settings.backgroundColor,
            settings.startOnMonday,
            settings.saturdayColor,
            settings.sundayHolidayColor,
            settingsProvider.googleCalendarEnabled,
          ),
        );
      },
    );
  }

  Widget _buildCalendarList(
    Color bgColor,
    bool startOnMonday,
    Color saturdayColor,
    Color sundayHolidayColor,
    bool googleCalendarEnabled,
  ) {
    final now = DateTime.now();

    // CustomScrollView + SliverList で先頭・末尾にクッションバナーを挿入する
    return CustomScrollView(
      key: _scrollKey,
      controller: _scrollController,
      slivers: [
        // ── 先頭クッション ──────────────────────────────
        SliverToBoxAdapter(
          child: _LoadMoreBanner(
            label: '${_months.first.year}年${_months.first.month}月より前を表示',
            loading: _loadingPast,
            onTap: _loadPastMonths,
          ),
        ),
        // ── カレンダーグリッド ────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          sliver: SliverGrid(
            gridDelegate: _MonthGridDelegate(
              months: _months,
              startOnMonday: startOnMonday,
              calendarService: _calendarService,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final month = _months[index];
                final isCurrentMonth =
                    month.year == now.year && month.month == now.month;

                // イベントデータをキャッシュから取得
                final currentKey = '${month.year}-${month.month}';
                final prevMonth = DateTime(month.year, month.month - 1);
                final nextMonth = DateTime(month.year, month.month + 1);
                final prevKey = '${prevMonth.year}-${prevMonth.month}';
                final nextKey = '${nextMonth.year}-${nextMonth.month}';

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: isCurrentMonth
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white38,
                            width: 1.5,
                          ),
                        )
                      : null,
                  child: MonthCalendarCard(
                    key: ValueKey(currentKey),
                    year: month.year,
                    month: month.month,
                    startOnMonday: startOnMonday,
                    backgroundColor: bgColor,
                    saturdayColor: saturdayColor,
                    sundayHolidayColor: sundayHolidayColor,
                    googleCalendarEnabled: googleCalendarEnabled,
                    eventColors: googleCalendarEnabled
                        ? _allEventData[currentKey]
                        : null,
                    prevEventColors: googleCalendarEnabled
                        ? _allEventData[prevKey]
                        : null,
                    nextEventColors: googleCalendarEnabled
                        ? _allEventData[nextKey]
                        : null,
                  ),
                );
              },
              childCount: _months.length,
            ),
          ),
        ),
        // ── 末尾クッション ──────────────────────────────
        SliverToBoxAdapter(
          child: _LoadMoreBanner(
            label: '${_months.last.year}年${_months.last.month}月より後を表示',
            loading: _loadingFuture,
            onTap: _loadFutureMonths,
          ),
        ),
      ],
    );
  }
}

/// 追加読み込みバナーウィジェット
class _LoadMoreBanner extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _LoadMoreBanner({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.expand_more, color: Colors.white38, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 月ごとに行数（5行 or 6行）に応じたアスペクト比を計算するグリッドデリゲート
class _MonthGridDelegate extends SliverGridDelegate {
  final List<DateTime> months;
  final bool startOnMonday;
  final CalendarService calendarService;

  // 基準アスペクト比（5行のとき）。縦を若干広げてゆとりを持たせる
  static const double _baseAspectRatio5 = 0.78;
  // 6行の場合は固定ヘッダー分を加味してやや高い比率（= 縦幅が短い）にする
  static const double _baseAspectRatio6 = 0.70;

  _MonthGridDelegate({
    required this.months,
    required this.startOnMonday,
    required this.calendarService,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    const crossAxisCount = 2;
    const spacing = 8.0;
    const padding = 0.0; // SliverPadding で制御するため0
    final cellWidth =
        (constraints.crossAxisExtent - spacing * (crossAxisCount - 1)) /
            crossAxisCount;

    // 月ごとの高さをリスト化
    final heights = List<double>.generate(months.length, (i) {
      final m = months[i];
      final rows = calendarService.getRowCount(
        year: m.year,
        month: m.month,
        startOnMonday: startOnMonday,
      );
      final ratio = rows == 6 ? _baseAspectRatio6 : _baseAspectRatio5;
      return cellWidth / ratio;
    });

    return _MonthGridLayout(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      padding: padding,
      cellWidth: cellWidth,
      heights: heights,
    );
  }

  @override
  bool shouldRelayout(_MonthGridDelegate oldDelegate) {
    return oldDelegate.months != months ||
        oldDelegate.startOnMonday != startOnMonday;
  }
}

/// 月ごとに高さが異なる2列グリッドのレイアウト
class _MonthGridLayout extends SliverGridLayout {
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double padding;
  final double cellWidth;
  final List<double> heights;

  // 各アイテムのY座標オフセットをキャッシュ
  late final List<double> _offsets;
  late final double _totalHeight;

  _MonthGridLayout({
    required this.crossAxisCount,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.padding,
    required this.cellWidth,
    required this.heights,
  }) {
    _offsets = List<double>.filled(heights.length, 0);
    // 2列グリッドなので左右ペアで高さを決める（高い方に合わせる）
    double y = padding;
    for (int i = 0; i < heights.length; i += crossAxisCount) {
      final leftH = i < heights.length ? heights[i] : 0.0;
      final rightH = i + 1 < heights.length ? heights[i + 1] : 0.0;
      final rowH = leftH > rightH ? leftH : rightH;
      _offsets[i] = y;
      if (i + 1 < heights.length) _offsets[i + 1] = y;
      y += rowH + mainAxisSpacing;
    }
    _totalHeight = y - mainAxisSpacing + padding;
  }

  @override
  double computeMaxScrollOffset(int childCount) => _totalHeight;

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final col = index % crossAxisCount;
    final xOffset = padding + col * (cellWidth + crossAxisSpacing);
    final rowIndex = index ~/ crossAxisCount;
    // 行内の高い方のセルに合わせた行高さ
    final leftIdx = rowIndex * crossAxisCount;
    final rightIdx = leftIdx + 1;
    final leftH = leftIdx < heights.length ? heights[leftIdx] : 0.0;
    final rightH = rightIdx < heights.length ? heights[rightIdx] : 0.0;
    final rowH = leftH > rightH ? leftH : rightH;

    return SliverGridGeometry(
      scrollOffset: _offsets[index],
      crossAxisOffset: xOffset,
      mainAxisExtent: rowH,
      crossAxisExtent: cellWidth,
    );
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    for (int i = 0; i < _offsets.length; i += crossAxisCount) {
      if (_offsets[i] > scrollOffset) return (i - crossAxisCount).clamp(0, _offsets.length - 1);
    }
    return (_offsets.length - crossAxisCount).clamp(0, _offsets.length - 1);
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    for (int i = 0; i < _offsets.length; i += crossAxisCount) {
      if (_offsets[i] > scrollOffset) return (i + crossAxisCount - 1).clamp(0, _offsets.length - 1);
    }
    return _offsets.length - 1;
  }
}

