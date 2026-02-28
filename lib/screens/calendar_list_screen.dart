import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
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

    // 初回ウィジェット更新 + 今月へのスクロール（保存済みでなければ）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateWidget();
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
    // PageStorage に保存済みのオフセットがあればそちらが使われるため何もしない
    final savedOffset =
        PageStorage.of(context).readState(context, identifier: _scrollKey);
    if (savedOffset != null) return;

    // 2列グリッドなので今月は (_currentMonthIndex ~/ 2) 行目
    // childAspectRatio=0.85、spacing=8、padding=8 から大まかなアイテム高さを計算
    if (!_scrollController.hasClients) return;
    // GridViewは縦スクロールなのでhorizontal幅はMediaQueryから取得する
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 8.0;
    const spacing = 8.0;
    const crossAxisCount = 2;
    const aspectRatio = 0.85;
    final itemWidth =
        (screenWidth - padding * 2 - spacing * (crossAxisCount - 1)) /
            crossAxisCount;
    final itemHeight = itemWidth / aspectRatio;
    final row = _currentMonthIndex ~/ crossAxisCount;
    final offset = row * (itemHeight + spacing) + padding;

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
          body: _buildCalendarGrid(settings.backgroundColor, settings.startOnMonday),
        );
      },
    );
  }

  Widget _buildCalendarGrid(Color bgColor, bool startOnMonday) {
    final now = DateTime.now();

    // 2列グリッドで月カレンダーを表示
    return GridView.builder(
      key: _scrollKey,
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
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
          ),
        );
      },
    );
  }
}

