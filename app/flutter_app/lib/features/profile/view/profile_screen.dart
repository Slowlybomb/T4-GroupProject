import 'package:flutter/material.dart';

import '../../../core/locator.dart';
import '../../../core/theme/app_colour_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../stats/domain/models/user_stats.dart';
import 'settings_screen.dart';

// ─── Demo data ────────────────────────────────────────────────────────────────

const _kDefaultStats = UserStats(
  weeklyDistanceKm: 28.6,
  weeklyMinutes: 144,
  trainingLogDateRange: 'Mon 24 Feb – Sun 2 Mar 2026',
  trainingLogEntries: [
    TrainingLogEntry(label: 'M', trainingMinutes: 42),
    TrainingLogEntry(label: 'T', trainingMinutes: 0),
    TrainingLogEntry(label: 'W', trainingMinutes: 72, highlighted: true),
    TrainingLogEntry(label: 'T', trainingMinutes: 0),
    TrainingLogEntry(label: 'F', trainingMinutes: 27),
    TrainingLogEntry(label: 'S', trainingMinutes: 0),
    TrainingLogEntry(label: 'S', trainingMinutes: 0),
  ],
);

// km rowed each of the last 12 weeks (oldest → newest)
const _kWeeklyKm = [
  12.1, 18.4, 9.0, 22.3, 15.7, 28.6,
  11.2, 19.8, 24.5, 16.0, 31.2, 28.6,
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class UserStatsScreen extends StatelessWidget {
  final AuthRepository? authRepository;
  final UserStats userStats;

  const UserStatsScreen({
    super.key,
    this.authRepository,
    this.userStats = _kDefaultStats,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'You',
          style: TextStyle(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: AppColors.primaryRed),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileSettingsScreen(
                    authRepository:
                        authRepository ?? Locator.authRepository,
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(backgroundColor: Colors.grey, radius: 15),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TwelveWeekChart(weeklyKm: _kWeeklyKm),
            _ThisWeekSummary(stats: userStats),
            _TrainingLogCard(stats: userStats),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── 12-week line chart ───────────────────────────────────────────────────────

class _TwelveWeekChart extends StatelessWidget {
  final List<double> weeklyKm;
  const _TwelveWeekChart({required this.weeklyKm});

  @override
  Widget build(BuildContext context) {
    final maxKm = weeklyKm.fold(0.0, (a, b) => a > b ? a : b);
    final totalKm = weeklyKm.fold(0.0, (a, b) => a + b);
    final totalHours = totalKm * 5.2 / 60;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '12-Week Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${totalKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${totalHours.toStringAsFixed(1)} h',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: CustomPaint(
              size: const Size(double.infinity, 110),
              painter: _LineChartPainter(data: weeklyKm, maxValue: maxKm),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('12w ago',
                  style: TextStyle(color: Colors.white54, fontSize: 10)),
              Text('This week',
                  style: TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;

  const _LineChartPainter({required this.data, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue == 0) return;

    const leftPad = 36.0; // space for Y-axis labels
    const topPad = 8.0;
    const bottomPad = 4.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotBorder = Paint()
      ..color = AppColors.primaryRed
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Y-axis labels + gridlines at 0%, 50%, 100%
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 9,
    );
    const levels = [0.0, 0.5, 1.0];
    for (final frac in levels) {
      final y = topPad + chartH * (1 - frac);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width, y),
        gridPaint,
      );
      final label = frac == 0
          ? '0'
          : '${(maxValue * frac).round()} km';
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // Compute point positions
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = leftPad + (i / (data.length - 1)) * chartW;
      final y = topPad + chartH * (1 - data[i] / maxValue);
      points.add(Offset(x, y));
    }

    // Draw polyline
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final pt in points.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw dots
    for (final pt in points) {
      canvas.drawCircle(pt, 4, dotFill);
      canvas.drawCircle(pt, 4, dotBorder);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.data != data || old.maxValue != maxValue;
}

// ─── This week summary ────────────────────────────────────────────────────────

class _ThisWeekSummary extends StatelessWidget {
  final UserStats stats;
  const _ThisWeekSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _WeekStat(
                label: 'Distance',
                value: '${stats.weeklyDistanceKm.toStringAsFixed(1)} km',
              ),
              const SizedBox(width: 24),
              _WeekStat(
                label: 'Time',
                value: '${stats.weeklyMinutes} min',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekStat extends StatelessWidget {
  final String label, value;
  const _WeekStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─── Training log card ────────────────────────────────────────────────────────

class _TrainingLogCard extends StatelessWidget {
  final UserStats stats;
  const _TrainingLogCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final maxMinutes = stats.trainingLogEntries
        .map((e) => e.trainingMinutes)
        .fold(0, (a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Training Log',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            stats.trainingLogDateRange,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: stats.trainingLogEntries
                .map((e) =>
                    _TrainingDay(entry: e, maxMinutes: maxMinutes))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _TrainingDay extends StatelessWidget {
  final TrainingLogEntry entry;
  final int maxMinutes;
  const _TrainingDay({required this.entry, required this.maxMinutes});

  @override
  Widget build(BuildContext context) {
    final hasTraining = entry.trainingMinutes > 0;
    // Scale radius: 14 (rest) → 24 (max effort)
    final radius = hasTraining && maxMinutes > 0
        ? 14.0 + 10.0 * (entry.trainingMinutes / maxMinutes)
        : 14.0;

    return Column(
      children: [
        // Day letter above
        Text(
          entry.label,
          style: TextStyle(
            color: hasTraining ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: hasTraining ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 6),
        // Circle containing time
        CircleAvatar(
          radius: radius,
          backgroundColor: hasTraining ? Colors.white : Colors.white24,
          child: hasTraining
              ? Text(
                  '${entry.trainingMinutes}m',
                  style: TextStyle(
                    color: AppColors.primaryRed,
                    fontSize: radius > 18 ? 10 : 8,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
