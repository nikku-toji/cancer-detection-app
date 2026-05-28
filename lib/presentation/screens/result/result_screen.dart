import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/detection_result.dart';

class ResultScreen extends StatelessWidget {
  final DetectionResult result;

  const ResultScreen({super.key, required this.result});

  Color get _riskColor {
    switch (result.riskLevel) {
      case 'high':
        return const Color(0xFFD32F2F);
      case 'medium':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFF388E3C);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${AppConstants.cancerNames[result.cancerType]} Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Risk level card
            _RiskCard(result: result, riskColor: _riskColor)
                .animate()
                .fadeIn()
                .slideY(begin: -0.2),
            const SizedBox(height: 20),

            // Confidence gauge
            _ConfidenceGauge(result: result, riskColor: _riskColor)
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 20),

            // Bar chart of all probabilities
            _ProbabilityChart(result: result)
                .animate()
                .fadeIn(delay: 400.ms),
            const SizedBox(height: 20),

            // Recommendation
            _RecommendationCard(result: result)
                .animate()
                .fadeIn(delay: 600.ms),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/education/${result.cancerType}',
                    ),
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Learn More'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Scan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final DetectionResult result;
  final Color riskColor;
  const _RiskCard({required this.result, required this.riskColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: riskColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: riskColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              result.riskLevel == 'high'
                  ? Icons.warning_amber_rounded
                  : result.riskLevel == 'medium'
                      ? Icons.info_outline
                      : Icons.check_circle_outline,
              size: 48,
              color: riskColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.topLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.riskLevel.toUpperCase()} RISK',
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1.2,
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
}

class _ConfidenceGauge extends StatelessWidget {
  final DetectionResult result;
  final Color riskColor;
  const _ConfidenceGauge({required this.result, required this.riskColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Confidence Score',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            CircularPercentIndicator(
              radius: 80,
              lineWidth: 14,
              animation: true,
              animationDuration: 1200,
              percent: result.topConfidence.clamp(0.0, 1.0),
              center: Text(
                '${(result.topConfidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              progressColor: riskColor,
              backgroundColor: riskColor.withOpacity(0.15),
              circularStrokeCap: CircularStrokeCap.round,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProbabilityChart extends StatelessWidget {
  final DetectionResult result;
  const _ProbabilityChart({required this.result});

  @override
  Widget build(BuildContext context) {
    final entries = result.allConfidences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Probability Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: entries.length * 48.0,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.0,
                  barGroups: entries.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value,
                          color: const Color(0xFF1565C0),
                          width: 24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= entries.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              entries[idx].key.length > 12
                                  ? '${entries[idx].key.substring(0, 10)}...'
                                  : entries[idx].key,
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final DetectionResult result;
  const _RecommendationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_services_outlined),
                const SizedBox(width: 10),
                Text(
                  'Recommendation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result.recommendation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '⚠️ This result is for informational purposes only and does not constitute medical advice.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
