import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';

const _cancerIcons = {
  'skin': Icons.face_retouching_natural,
  'lung': Icons.air,
  'breast': Icons.favorite_outline,
  'brain': Icons.psychology,
};

const _cancerColors = {
  'skin': Color(0xFF6D4C41),
  'lung': Color(0xFF1565C0),
  'breast': Color(0xFFAD1457),
  'brain': Color(0xFF4527A0),
};

class CancerTypeCard extends StatelessWidget {
  final String cancerType;
  final int index;

  const CancerTypeCard({
    super.key,
    required this.cancerType,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final color = _cancerColors[cancerType]!;
    final icon = _cancerIcons[cancerType]!;
    final name = AppConstants.cancerNames[cancerType]!;
    final desc = AppConstants.cancerDescriptions[cancerType]!;

    return GestureDetector(
      onTap: () => context.push('/scan/$cancerType'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.7)],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const Spacer(),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Scan',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 100)).scale(
          begin: const Offset(0.9, 0.9),
          delay: Duration(milliseconds: index * 100),
        );
  }
}
