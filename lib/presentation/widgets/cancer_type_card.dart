import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';

const _cancerIcons = {
  'skin': Icons.face_retouching_natural,
  'lung': Icons.air,
  'breast': Icons.favorite_outline,
  'brain': Icons.psychology,
};

const _cancerGradients = {
  'skin': [Color(0xFF6D4C41), Color(0xFFBCAAA4)],
  'lung': [Color(0xFF1565C0), Color(0xFF42A5F5)],
  'breast': [Color(0xFFAD1457), Color(0xFFF48FB1)],
  'brain': [Color(0xFF4527A0), Color(0xFF9575CD)],
};

const _cancerStats = {
  'skin': '7 classes',
  'lung': '4 classes',
  'breast': '3 classes',
  'brain': '4 classes',
};

class CancerTypeCard extends StatelessWidget {
  final String cancerType;
  final int index;

  const CancerTypeCard({super.key, required this.cancerType, required this.index});

  @override
  Widget build(BuildContext context) {
    final gradColors = _cancerGradients[cancerType]!;
    final icon = _cancerIcons[cancerType]!;
    final name = AppConstants.cancerNames[cancerType]!;
    final desc = AppConstants.cancerDescriptions[cancerType]!;
    final stat = _cancerStats[cancerType]!;

    return GestureDetector(
      onTap: () => context.push('/scan/$cancerType'),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradColors,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradColors[0].withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern circles
            Positioned(
              right: -20, top: -20,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              right: 20, bottom: 40,
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const Spacer(),
                  // Stat chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(stat,
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 6),
                  Text(name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11)),
                  const SizedBox(height: 12),
                  // Scan button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Scan Now',
                            style: TextStyle(color: gradColors[0], fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: gradColors[0], size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate()
      .fadeIn(delay: Duration(milliseconds: index * 100))
      .slideY(begin: 0.15, delay: Duration(milliseconds: index * 100));
  }
}
