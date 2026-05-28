import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/detection_repository.dart';
import '../../../core/constants/app_constants.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = DetectionRepository();
    final records = repo.getHistory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear History'),
                  content: const Text('Delete all scan records?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirm == true) await repo.clearHistory();
            },
          ),
        ],
      ),
      body: records.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No scans yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, i) {
                final record = records[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: record.isHighRisk
                          ? Colors.red[100]
                          : Colors.green[100],
                      child: Icon(
                        record.isHighRisk ? Icons.warning : Icons.check,
                        color: record.isHighRisk ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(
                      AppConstants.cancerNames[record.cancerType] ?? record.cancerType,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.topLabel),
                        Text(
                          DateFormat('MMM d, yyyy • hh:mm a')
                              .format(record.createdAt),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${(record.topConfidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: record.isHighRisk ? Colors.red : Colors.green,
                      ),
                    ),
                    isThreeLine: true,
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 60));
              },
            ),
    );
  }
}
