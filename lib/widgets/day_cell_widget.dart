import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/calendar_cell.dart';

class DayCellWidget extends StatelessWidget {
  final CalendarCell cell;
  final double fontSize;

  const DayCellWidget({
    super.key,
    required this.cell,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    if (cell.isEmpty) {
      return const SizedBox.expand();
    }

    final isToday = !cell.isAdjacentMonth && _isToday(cell.date!);

    return Container(
      decoration: isToday
          ? const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            )
          : null,
      child: Center(
        child: Text(
          cell.date!.day.toString(),
          style: GoogleFonts.rajdhani(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: cell.effectiveTextColor,
            height: 1.0,
          ),
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
