import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/logger_service.dart';
import '../pages/planning_poker_page.dart';

class EstimationService {
  // In-memory storage for now
  static final List<Map<String, dynamic>> _sessions = [];

  Future<String> createSession({
    required String taskDescription,
    required String sequence,
    required String createdBy,
  }) async {
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final session = {
      'id': id,
      'taskDescription': taskDescription,
      'cardSequence': sequence,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'voting',
      'votes': {},
      'createdBy': createdBy,
      'finalEstimate': null,
    };

    _sessions.add(session);
    return id;
  }

  Stream<List<Map<String, dynamic>>> getSessionHistory() {
    // Return a stream with the current sessions
    return Stream.value(_sessions);
  }

  Future<void> submitVote({
    required String sessionId,
    required String userId,
    required String userName,
    required String value,
  }) async {
    final sessionIndex = _sessions.indexWhere((s) => s['id'] == sessionId);
    if (sessionIndex != -1) {
      _sessions[sessionIndex]['votes'][userId] = {
        'userName': userName,
        'value': value,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<void> revealVotes(String sessionId) async {
    final sessionIndex = _sessions.indexWhere((s) => s['id'] == sessionId);
    if (sessionIndex != -1) {
      _sessions[sessionIndex]['status'] = 'revealed';
    }
  }

  Future<void> resetVoting(String sessionId) async {
    final sessionIndex = _sessions.indexWhere((s) => s['id'] == sessionId);
    if (sessionIndex != -1) {
      _sessions[sessionIndex]['votes'] = {};
      _sessions[sessionIndex]['status'] = 'voting';
      _sessions[sessionIndex]['finalEstimate'] = null;
    }
  }

  Future<void> setFinalEstimate(String sessionId, String estimate) async {
    final sessionIndex = _sessions.indexWhere((s) => s['id'] == sessionId);
    if (sessionIndex != -1) {
      _sessions[sessionIndex]['finalEstimate'] = estimate;
      _sessions[sessionIndex]['status'] = 'completed';
    }
  }
} 