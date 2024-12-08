import 'package:flutter/material.dart';
import '../models/estimation_session.dart';
import '../services/estimation_service.dart';

class EstimationHistoryPage extends StatelessWidget {
  const EstimationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final estimationService = EstimationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimation History'),
        backgroundColor: Colors.purple,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: estimationService.getSessionHistory(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data!;
          if (sessions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No estimation sessions yet.\nStart a new session from Planning Poker!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(session['taskDescription'] ?? 'Untitled Task'),
                  subtitle: Text(
                    'Created: ${session['createdAt']}\n'
                    'Status: ${session['status']}',
                  ),
                  trailing: session['finalEstimate'] != null
                      ? Chip(label: Text(session['finalEstimate']))
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
} 