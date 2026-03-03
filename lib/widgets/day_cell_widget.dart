import 'package:flutter/material.dart';
import '../models/calendar_cell.dart';

class DayCellWidget extends StatelessWidget {
  final CalendarCell cell;
  final double fontSize;
  /// この日付のGoogleカレンダーイベント色リスト（最大3件）
  final List<Color> eventColors;
  /// 日付セルタップ時のコールバック
  final VoidCallback? onTap;

  const DayCellWidget({
    super.key,
    required this.cell,
    this.fontSize = 14,
    this.eventColors = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cell.isEmpty) {
      // 空セルでもタップを受け取る（最近傍日付へのフォールバック用）
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const SizedBox.expand(),
      );
    }

    final isToday = !cell.isAdjacentMonth && _isToday(cell.date!);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // 透明領域含めセル全体でタップを受け取る
      child: Container(
        decoration: isToday
            ? const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 日付数字
            Text(
              cell.date!.day.toString(),
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: cell.effectiveTextColor,
                height: 1.0,
              ),
            ),
            // イベント●インジケーター（イベントがある場合のみ表示）
            if (eventColors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: eventColors.map((color) {
                    return Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
