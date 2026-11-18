import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:readmate/generated/locale_keys.g.dart';

class MonthlyBarChart extends StatelessWidget {
  final Map<int, int> monthlyStats;

  const MonthlyBarChart({
    super.key,
    required this.monthlyStats,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            LocaleKeys.monthly_stats.tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        AspectRatio(
          aspectRatio: 1.7,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxY(),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Theme.of(context).colorScheme.secondaryContainer,
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      rod.toY.toInt().toString(),
                      TextStyle(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: getTitles,
                    reservedSize: 38,
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: _getBarGroups(context),
            ),
          ),
        ),
      ],
    );
  }

  double _getMaxY() {
    int maxBooks = 0;
    monthlyStats.forEach((_, count) {
      if (count > maxBooks) maxBooks = count;
    });
    return (maxBooks + 1).toDouble();
  }

  List<BarChartGroupData> _getBarGroups(BuildContext context) {
    return List.generate(12, (index) {
      final month = index + 1;
      final count = monthlyStats[month] ?? 0;
      return BarChartGroupData(
        x: month,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: Theme.of(context).colorScheme.primary,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  Widget getTitles(double value, TitleMeta meta) {
    final style = TextStyle(
      color: meta.axisSide == AxisSide.bottom ? Colors.grey : null,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    String text;
    switch (value.toInt()) {
      case 1:
        text = LocaleKeys.january_short.tr();
        break;
      case 2:
        text = LocaleKeys.february_short.tr();
        break;
      case 3:
        text = LocaleKeys.march_short.tr();
        break;
      case 4:
        text = LocaleKeys.april_short.tr();
        break;
      case 5:
        text = LocaleKeys.may_short.tr();
        break;
      case 6:
        text = LocaleKeys.june_short.tr();
        break;
      case 7:
        text = LocaleKeys.july_short.tr();
        break;
      case 8:
        text = LocaleKeys.august_short.tr();
        break;
      case 9:
        text = LocaleKeys.september_short.tr();
        break;
      case 10:
        text = LocaleKeys.october_short.tr();
        break;
      case 11:
        text = LocaleKeys.november_short.tr();
        break;
      case 12:
        text = LocaleKeys.december_short.tr();
        break;
      default:
        text = '';
        break;
    }
    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(text, style: style),
    );
  }
}
