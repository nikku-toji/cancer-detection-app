import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../data/services/api_service.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';

final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ApiService.getAnalytics();
});

final scansProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ApiService.getScans();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final analytics = ref.watch(analyticsProvider);
    final scans = ref.watch(scansProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF1565C0),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF00ACC1)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: user?['picture'] != null
                                  ? NetworkImage(user!['picture']) : null,
                              child: user?['picture'] == null
                                  ? Text(
                                      (user?['name'] ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 20, color: Colors.white),
                                    )
                                  : null,
                              backgroundColor: Colors.white24,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hello, ${user?['name']?.split(' ').first ?? 'User'}!',
                                    style: const TextStyle(color: Colors.white,
                                        fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(user?['email'] ?? '',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        analytics.when(
                          data: (data) => Text(
                            '${data['total_scans']} total scans · ${data['high_risk_total']} high risk',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Quick actions
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.add_circle_outline,
                      label: 'New Scan',
                      color: const Color(0xFF1565C0),
                      onTap: () => context.go('/home'),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.history,
                      label: 'History',
                      color: const Color(0xFF4527A0),
                      onTap: () => context.push('/history'),
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      icon: Icons.analytics_outlined,
                      label: 'Analytics',
                      color: const Color(0xFF00838F),
                      onTap: () {},
                    ),
                  ],
                ).animate().fadeIn().slideY(begin: 0.2),
                const SizedBox(height: 20),

                // Analytics cards
                analytics.when(
                  loading: () => _ShimmerCard(),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Analytics Overview'),
                      const SizedBox(height: 12),

                      // Stats row
                      Row(
                        children: [
                          _StatCard(label: 'Total Scans',
                              value: '${data['total_scans']}',
                              icon: Icons.biotech_rounded,
                              color: const Color(0xFF1565C0)),
                          const SizedBox(width: 12),
                          _StatCard(label: 'High Risk',
                              value: '${data['high_risk_total']}',
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFD32F2F)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Cancer type breakdown
                      if ((data['by_cancer_type'] as List).isNotEmpty)
                        _CancerTypeChart(data: data['by_cancer_type'] as List),

                      const SizedBox(height: 12),

                      // Risk distribution pie
                      if ((data['risk_distribution'] as List).isNotEmpty)
                        _RiskDistributionChart(data: data['risk_distribution'] as List),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Recent scans
                const _SectionTitle('Recent Scans'),
                const SizedBox(height: 12),
                scans.when(
                  loading: () => _ShimmerCard(),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                  data: (data) {
                    final scanList = data['scans'] as List;
                    if (scanList.isEmpty) {
                      return _EmptyScans();
                    }
                    return Column(
                      children: scanList.take(5).map((s) => _ScanTile(
                        scan: s as Map<String, dynamic>,
                        onTap: () => context.push('/scan-detail/${s['id']}'),
                      )).toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color,
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(color: color,
                    fontWeight: FontWeight.bold, fontSize: 22)),
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CancerTypeChart extends StatelessWidget {
  final List data;
  const _CancerTypeChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = [const Color(0xFF1565C0), const Color(0xFFAD1457),
                    const Color(0xFF4527A0), const Color(0xFF6D4C41)];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scans by Cancer Type',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(BarChartData(
              barGroups: data.asMap().entries.map((e) => BarChartGroupData(
                x: e.key,
                barRods: [BarChartRodData(
                  toY: (e.value['count'] as int).toDouble(),
                  color: colors[e.key % colors.length],
                  width: 28,
                  borderRadius: BorderRadius.circular(6),
                )],
              )).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx >= data.length) return const SizedBox();
                    final name = AppConstants.cancerNames[data[idx]['_id']] ?? data[idx]['_id'];
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(name.split(' ').first,
                          style: const TextStyle(fontSize: 10)),
                    );
                  },
                )),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            )),
          ),
        ],
      ),
    );
  }
}

class _RiskDistributionChart extends StatelessWidget {
  final List data;
  const _RiskDistributionChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorMap = {
      'high': const Color(0xFFD32F2F),
      'medium': const Color(0xFFF57C00),
      'low': const Color(0xFF388E3C),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Risk Distribution',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 120, width: 120,
                child: PieChart(PieChartData(
                  sections: data.map((d) {
                    final level = d['_id'] as String;
                    final count = (d['count'] as int).toDouble();
                    return PieChartSectionData(
                      value: count,
                      color: colorMap[level] ?? Colors.grey,
                      title: '$count',
                      titleStyle: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13),
                      radius: 48,
                    );
                  }).toList(),
                  sectionsSpace: 3,
                )),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: data.map((d) {
                  final level = d['_id'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12,
                            decoration: BoxDecoration(
                              color: colorMap[level] ?? Colors.grey,
                              borderRadius: BorderRadius.circular(3),
                            )),
                        const SizedBox(width: 8),
                        Text('${level[0].toUpperCase()}${level.substring(1)} risk: ${d['count']}',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  final Map<String, dynamic> scan;
  final VoidCallback onTap;
  const _ScanTile({required this.scan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final riskColor = scan['risk_level'] == 'high'
        ? const Color(0xFFD32F2F)
        : scan['risk_level'] == 'medium'
            ? const Color(0xFFF57C00)
            : const Color(0xFF388E3C);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                scan['is_high_risk'] == true ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: riskColor, size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.cancerNames[scan['cancer_type']] ?? scan['cancer_type'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(scan['top_label'],
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${((scan['top_confidence'] as num) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: riskColor, fontWeight: FontWeight.bold)),
                Text(
                  scan['created_at'].toString().substring(0, 10),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E))),
      ],
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text('Backend not running. Start with: uvicorn main:app\n$message',
          style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
    );
  }
}

class _EmptyScans extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('No scans yet', style: TextStyle(color: Colors.grey)),
          Text('Run your first scan to see results here',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
