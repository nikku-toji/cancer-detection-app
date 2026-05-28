import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/detection_result.dart';

const _cancerGradients = {
  'skin': [Color(0xFF6D4C41), Color(0xFFBCAAA4)],
  'lung': [Color(0xFF1565C0), Color(0xFF42A5F5)],
  'breast': [Color(0xFFAD1457), Color(0xFFF48FB1)],
  'brain': [Color(0xFF4527A0), Color(0xFF9575CD)],
};

class ResultScreen extends StatelessWidget {
  final DetectionResult result;
  const ResultScreen({super.key, required this.result});

  Color get _riskColor {
    switch (result.riskLevel) {
      case 'high': return const Color(0xFFD32F2F);
      case 'medium': return const Color(0xFFF57C00);
      default: return const Color(0xFF388E3C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradColors = _cancerGradients[result.cancerType] ??
        [const Color(0xFF1565C0), const Color(0xFF42A5F5)];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            backgroundColor: gradColors[0],
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                '${AppConstants.cancerNames[result.cancerType]} Result',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradColors,
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Hero result card
                _HeroCard(result: result, riskColor: _riskColor, gradColors: gradColors)
                    .animate().fadeIn().slideY(begin: -0.15),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Confidence',
                        value: '${(result.topConfidence * 100).toStringAsFixed(1)}%',
                        icon: Icons.speed_rounded,
                        color: _riskColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Risk Level',
                        value: result.riskLevel.toUpperCase(),
                        icon: Icons.monitor_heart_outlined,
                        color: _riskColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Classes',
                        value: '${result.allConfidences.length}',
                        icon: Icons.category_outlined,
                        color: gradColors[0],
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 16),

                // Gauge
                _GaugeCard(result: result, riskColor: _riskColor)
                    .animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 16),

                // Probability chart
                _ProbabilityChart(result: result, gradColors: gradColors)
                    .animate().fadeIn(delay: 350.ms),
                const SizedBox(height: 16),

                // Recommendation
                _RecommendationCard(result: result, riskColor: _riskColor)
                    .animate().fadeIn(delay: 450.ms),
                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/education/${result.cancerType}'),
                        icon: const Icon(Icons.info_outline_rounded),
                        label: const Text('Learn More'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: gradColors[0],
                          side: BorderSide(color: gradColors[0].withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradColors),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: gradColors[0].withOpacity(0.3),
                              blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => context.go('/home'),
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                          label: const Text('New Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final DetectionResult result;
  final Color riskColor;
  final List<Color> gradColors;
  const _HeroCard({required this.result, required this.riskColor, required this.gradColors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [riskColor.withOpacity(0.12), riskColor.withOpacity(0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: riskColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              result.riskLevel == 'high' ? Icons.warning_amber_rounded
                  : result.riskLevel == 'medium' ? Icons.info_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: riskColor, size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.topLabel,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${result.riskLevel.toUpperCase()} RISK',
                    style: const TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  final DetectionResult result;
  final Color riskColor;
  const _GaugeCard({required this.result, required this.riskColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text('Confidence Score',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF37474F))),
          const SizedBox(height: 20),
          CircularPercentIndicator(
            radius: 90,
            lineWidth: 16,
            animation: true,
            animationDuration: 1500,
            percent: result.topConfidence.clamp(0.0, 1.0),
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${(result.topConfidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: riskColor)),
                Text('confidence', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            progressColor: riskColor,
            backgroundColor: riskColor.withOpacity(0.12),
            circularStrokeCap: CircularStrokeCap.round,
          ),
        ],
      ),
    );
  }
}

class _ProbabilityChart extends StatelessWidget {
  final DetectionResult result;
  final List<Color> gradColors;
  const _ProbabilityChart({required this.result, required this.gradColors});

  @override
  Widget build(BuildContext context) {
    final entries = result.allConfidences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Probability Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF37474F))),
          const SizedBox(height: 20),
          ...entries.asMap().entries.map((e) {
            final isTop = e.key == 0;
            final pct = e.value.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.value.key,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                              color: isTop ? gradColors[0] : Colors.grey.shade700,
                            )),
                      ),
                      Text('${(pct * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                            color: isTop ? gradColors[0] : Colors.grey.shade500,
                          )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(
                        isTop ? gradColors[0] : gradColors[0].withOpacity(0.35),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final DetectionResult result;
  final Color riskColor;
  const _RecommendationCard({required this.result, required this.riskColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.medical_services_rounded, color: riskColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Recommendation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF37474F))),
            ],
          ),
          const SizedBox(height: 14),
          Text(result.recommendation,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF546E7A))),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade700, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'For informational purposes only. Not a substitute for medical advice.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF795548)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
