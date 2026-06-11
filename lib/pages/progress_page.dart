import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ml_service.dart';
import '../widgets/left_panel.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  Map<String, dynamic>? _historyData;
  bool _isLoading = true;

  // Archetype → index for Y axis
  final Map<String, double> _archetypeIndex = {
    'Consistent Achiever':    4,
    'Night Owl Performer':    3,
    'Last-Minute Performer':  2,
    'Easily Distracted User': 1,
    'Burnout-Prone User':     0,
  };

  final Map<double, String> _yLabels = {
    4: 'Consistent',
    3: 'Night Owl',
    2: 'Last-Minute',
    1: 'Distracted',
    0: 'Burnout',
  };

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final data = await MLService.getPredictionHistory(uid);
    if (mounted) {
      setState(() {
        _historyData = data;
        _isLoading = false;
      });
    }
  }

  List<FlSpot> _buildConfidenceSpots(List<dynamic> history) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      final confidence =
          (history[i]['confidence'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), confidence));
    }
    return spots;
  }

  List<FlSpot> _buildArchetypeSpots(List<dynamic> history) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      final archetype = history[i]['archetype'] as String? ?? '';
      final yVal = _archetypeIndex[archetype] ?? 2.0;
      spots.add(FlSpot(i.toDouble(), yVal));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      drawer: Drawer(
        child: SizedBox(
          width: screenSize.width * 0.5,
          child: LeftPanel(),
        ),
      ),
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        title: Text(
          'Focentra — Progress',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(colorScheme),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    final history =
        (_historyData?['history'] as List<dynamic>?) ?? [];
    final transitions =
        (_historyData?['transitions'] as List<dynamic>?) ?? [];

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🤖', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Not enough data yet.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete Pomodoro sessions to see your progress.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: colorScheme.onBackground.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Confidence over time ─────────────────────────────
          _sectionTitle('Model Confidence Over Time', colorScheme),
          const SizedBox(height: 12),
          _confidenceChart(history, colorScheme),
          const SizedBox(height: 32),

          // ── Archetype trajectory ─────────────────────────────
          _sectionTitle('Behavioral Archetype Trajectory', colorScheme),
          const SizedBox(height: 8),
          Text(
            'Higher = more consistent productivity pattern',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: colorScheme.onBackground.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
          _archetypeChart(history, colorScheme),
          const SizedBox(height: 32),

          // ── Archetype transitions ────────────────────────────
          if (transitions.isNotEmpty) ...[
            _sectionTitle('Archetype Transitions', colorScheme),
            const SizedBox(height: 12),
            ...transitions.map((t) => _transitionCard(t, colorScheme)),
          ],

          // ── Feature snapshot ─────────────────────────────────
          if (history.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Latest Behavioral Snapshot', colorScheme),
            const SizedBox(height: 12),
            _snapshotCard(history.last, colorScheme),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: colorScheme.onBackground,
      ),
    );
  }

  Widget _confidenceChart(
      List<dynamic> history, ColorScheme colorScheme) {
    final spots = _buildConfidenceSpots(history);
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 1,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 0.25,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: colorScheme.onSurface.withOpacity(0.08),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 0.25,
                    getTitlesWidget: (v, _) => Text(
                      '${(v * 100).toInt()}%',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 10,
                        color:
                            colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: colorScheme.primary,
                  barWidth: 3,
                  dotData: FlDotData(show: spots.length <= 10),
                  belowBarData: BarAreaData(
                    show: true,
                    color: colorScheme.primary.withOpacity(0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _archetypeChart(
      List<dynamic> history, ColorScheme colorScheme) {
    final spots = _buildArchetypeSpots(history);
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: -0.5,
              maxY: 4.5,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: colorScheme.onSurface.withOpacity(0.06),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 72,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final label = _yLabels[v];
                      if (label == null) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 9,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: Colors.deepPurple,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) =>
                        FlDotCirclePainter(
                      radius: 4,
                      color: Colors.deepPurple,
                      strokeWidth: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _transitionCard(
      Map<String, dynamic> t, ColorScheme colorScheme) {
    final from = t['from_archetype'] as String? ?? '';
    final to = t['to_archetype'] as String? ?? '';
    final message = MLService.getTransitionMessage(from, to);
    final emoji = MLService.getArchetypeEmoji(to);
    final color = Color(MLService.getArchetypeColor(to));

    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$from → $to',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snapshotCard(
      Map<String, dynamic> latest, ColorScheme colorScheme) {
    final fv =
        latest['feature_vector'] as Map<String, dynamic>? ?? {};

    final metrics = [
      {
        'label': 'Consistency',
        'value': fv['consistency_score'] ?? 0.0,
        'isRatio': true,
      },
      {
        'label': 'Motivation Slope',
        'value': fv['motivation_curve_slope'] ?? 0.0,
        'isRatio': false,
      },
      {
        'label': 'Focus Sessions/Day',
        'value': fv['focus_sessions_per_day'] ?? 0.0,
        'isRatio': false,
      },
      {
        'label': 'Burst Ratio',
        'value': fv['points_burst_ratio'] ?? 0.0,
        'isRatio': true,
      },
    ];

    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: metrics.map((m) {
            final val = (m['value'] as num).toDouble();
            final isRatio = m['isRatio'] as bool;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m['label'] as String,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color:
                              colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        isRatio
                            ? '${(val * 100).toInt()}%'
                            : val.toStringAsFixed(2),
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  if (isRatio) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: val.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor:
                            colorScheme.onSurface.withOpacity(0.08),
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}