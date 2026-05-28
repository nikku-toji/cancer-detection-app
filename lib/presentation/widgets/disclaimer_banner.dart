import 'package:flutter/material.dart';

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'For educational purposes only. Not a substitute for professional medical advice.',
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
            ),
          ),
        ],
      ),
    );
  }
}
