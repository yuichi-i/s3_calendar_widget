import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/calendar_service.dart';
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

  // 表示する月のリスト（過去→現在→未来）
  late List<DateTime> _months;
  late ScrollController _scrollController;

  // 一度に読み込む月数（前後）
  static const int _initialMonthsEach = 12;
  static const int _loadMoreThreshold = 3; // 端から何月で追加読み込みするか

  // 今月が何番目のインデックスか
  late int _currentMonthIndex;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _months = _generateMonths(
      DateTime(now.year - 1, now.month),
      _initialMonthsEach * 2 + 1,
    );
    // 今月のインデックス = _initialMonthsEach（1年前スタートなので12番目）
    _currentMonthIndex = _initialMonthsEach;

    _scrollController = ScrollController()..addListener(_onScroll);

    // SettingsProvider の init() 完了後にウィジェット更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<SettingsProvider>(context, listen: false);
      // init() はすでに main.dart で呼ばれているが非同期のため、
      // addListener で初期化完了を検知してから初回更新する
      void onProviderReady() {
        _updateWidget();
        provider.removeListener(onProviderReady);
      }
      // すでに設定がデフォルト以外なら初期化済みとみなして即更新、
      // そうでなければリスナー経由で待つ
      if (provider.settings.backgroundColor != const Color(0xFF000000) ||
          provider.startOnMonday) {
        _updateWidget();
      } else {
        provider.addListener(onProviderReady);
        // 念のため短い遅延後にも実行（init済みでデフォルト値の場合に備えて）
        Future.delayed(const Duration(milliseconds: 500), () {
          provider.removeListener(onProviderReady);
          if (mounted) _updateWidget();
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
    return List.generate(
        count, (i) => DateTime(start.year, start.month + i));
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

  void _onScroll() {
    // 上端付近で過去月を追加
    if (_scrollController.position.pixels <
        _scrollController.position.minScrollExtent + 200) {
      _loadPastMonths();
    }
    // 下端付近で未来月を追加
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadFutureMonths();
    }
  }

  void _loadPastMonths() {
    final oldest = _months.first;
    setState(() {
      final newMonths = _generateMonths(
        DateTime(oldest.year, oldest.month - _loadMoreThreshold),
        _loadMoreThreshold,
      );
      _months = [...newMonths, ..._months];
      // 先頭に追加した分インデックスをずらす
      _currentMonthIndex += _loadMoreThreshold;
    });
  }

  void _loadFutureMonths() {
    final newest = _months.last;
    setState(() {
      final newMonths = _generateMonths(
        DateTime(newest.year, newest.month + 1),
        _loadMoreThreshold,
      );
      _months = [..._months, ...newMonths];
    });
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
                },
              ),
            ],
          ),
          body: _buildCalendarGrid(
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

  Widget _buildCalendarGrid(Color bgColor, bool startOnMonday, Color saturdayColor, Color sundayHolidayColor, bool googleCalendarEnabled) {
    final now = DateTime.now();

    // 2列グリッドで月カレンダーを表示
    return GridView.builder(
      key: _scrollKey,
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: _MonthGridDelegate(
        months: _months,
        startOnMonday: startOnMonday,
        calendarService: _calendarService,
      ),
      itemCount: _months.length,
      itemBuilder: (context, index) {
        final month = _months[index];
        final isCurrentMonth =
            month.year == now.year && month.month == now.month;

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
            key: ValueKey('${month.year}-${month.month}'),
            year: month.year,
            month: month.month,
            startOnMonday: startOnMonday,
            backgroundColor: bgColor,
            saturdayColor: saturdayColor,
            sundayHolidayColor: sundayHolidayColor,
            googleCalendarEnabled: googleCalendarEnabled,
          ),
        );
      },
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
    const padding = 8.0;
    final cellWidth =
        (constraints.crossAxisExtent - spacing * (crossAxisCount - 1) - padding * 2) /
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

