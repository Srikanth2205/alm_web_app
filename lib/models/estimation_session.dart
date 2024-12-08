import 'package:cloud_firestore/cloud_firestore.dart';

enum CardSequence { fibonacci, tShirt, custom }
enum EstimationStatus { waiting, voting, revealed }

class Vote {
  final String userId;
  final String userName;
  final String value;
  final DateTime timestamp;

  Vote({
    required this.userId,
    required this.userName,
    required this.value,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userName': userName,
    'value': value,
    'timestamp': timestamp.toIso8601String(),
  };

  factory Vote.fromJson(Map<String, dynamic> json) => Vote(
    userId: json['userId'],
    userName: json['userName'],
    value: json['value'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class EstimationSession {
  final String id;
  final String taskDescription;
  final CardSequence cardSequence;
  final DateTime createdAt;
  final EstimationStatus status;
  final Map<String, Vote> votes;
  final int? timerSeconds;
  final String? finalEstimate;

  EstimationSession({
    required this.id,
    required this.taskDescription,
    required this.cardSequence,
    required this.createdAt,
    required this.status,
    required this.votes,
    this.timerSeconds,
    this.finalEstimate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskDescription': taskDescription,
    'cardSequence': cardSequence.toString(),
    'createdAt': createdAt.toIso8601String(),
    'status': status.toString(),
    'votes': votes.map((key, value) => MapEntry(key, value.toJson())),
    'timerSeconds': timerSeconds,
    'finalEstimate': finalEstimate,
  };

  factory EstimationSession.fromJson(Map<String, dynamic> json) {
    return EstimationSession(
      id: json['id'],
      taskDescription: json['taskDescription'],
      cardSequence: CardSequence.values.firstWhere(
        (e) => e.toString() == json['cardSequence'],
      ),
      createdAt: DateTime.parse(json['createdAt']),
      status: EstimationStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
      ),
      votes: (json['votes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, Vote.fromJson(value as Map<String, dynamic>)),
      ),
      timerSeconds: json['timerSeconds'],
      finalEstimate: json['finalEstimate'],
    );
  }
} 