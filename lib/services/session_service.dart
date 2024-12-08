import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class SessionNotFoundException implements Exception {
  final String message;
  SessionNotFoundException(this.message);
  @override
  String toString() => message;
}

class SessionState {
  final String taskName;
  final Map<String, ParticipantState> participants;
  final bool votesRevealed;
  final List<TaskData> tasks;

  SessionState({
    required this.taskName,
    required this.participants,
    required this.votesRevealed,
    required this.tasks,
  });

  factory SessionState.fromJson(Map<String, dynamic> json) {
    return SessionState(
      taskName: json['taskName'] as String? ?? '',
      participants: (json['participants'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(
          k,
          ParticipantState.fromJson(v as Map<String, dynamic>),
        ),
      ),
      votesRevealed: json['votesRevealed'] as bool? ?? false,
      tasks: (json['tasks'] as List<dynamic>?)?.map(
              (t) => TaskData.fromJson(t as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'taskName': taskName,
    'participants': participants.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'votesRevealed': votesRevealed,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };
}

class ParticipantState {
  final String userName;
  final bool hasVoted;
  final bool isModerator;
  final String? vote;

  ParticipantState({
    required this.userName,
    required this.hasVoted,
    required this.isModerator,
    this.vote,
  });

  factory ParticipantState.fromJson(Map<String, dynamic> json) {
    return ParticipantState(
      userName: json['userName'] as String,
      hasVoted: json['hasVoted'] as bool,
      isModerator: json['isModerator'] as bool,
      vote: json['vote'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'userName': userName,
    'hasVoted': hasVoted,
    'isModerator': isModerator,
    'vote': vote,
  };
}

class TaskData {
  final String name;
  String? estimate;

  TaskData({required this.name, this.estimate});

  factory TaskData.fromJson(Map<String, dynamic> json) {
    return TaskData(
      name: json['name'] as String,
      estimate: json['estimate'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'estimate': estimate,
  };
}

class SessionService {
  static const String _tag = 'SessionService';
  final _sessionController = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, StreamSubscription> _subscriptions = {};

  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Future<void> createSession(String sessionId, String userName) async {
    debugPrint('\n[$_tag] ====== CREATING SESSION ======');
    debugPrint('[$_tag] SessionId: $sessionId, Moderator: $userName');
    
    final sessions = getSessionsFromStorage();
    final sessionData = {
      'taskName': '',
      'participants': {
        userName: {
          'userName': userName,
          'hasVoted': false,
          'isModerator': true,
          'vote': null,
        },
      },
      'votesRevealed': false,
      'tasks': <Map<String, dynamic>>[],
    };
    
    sessions[sessionId] = sessionData;
    _saveSessionsToStorage(sessions);
    _broadcastUpdate(sessionId);
    debugPrint('[$_tag] Session created successfully\n');
  }

  Future<void> joinSession(String sessionId, String userName) async {
    debugPrint('\n[$_tag] ====== JOINING SESSION ======');
    debugPrint('[$_tag] SessionId: $sessionId, User: $userName');
    debugPrint('[$_tag] Checking if session exists: $sessionId');
    
    final sessions = getSessionsFromStorage();
    debugPrint('[$_tag] Getting sessions from storage');
    debugPrint('Raw storage data: ${json.encode(sessions)}');
    debugPrint('Decoded storage data: ${json.encode(sessions)}');

    if (!sessions.containsKey(sessionId)) {
      throw SessionNotFoundException('Session $sessionId not found');
    }

    final session = sessions[sessionId] as Map<String, dynamic>;
    final participants = session['participants'] as Map<String, dynamic>;
    
    participants[userName] = {
      'userName': userName,
      'hasVoted': false,
      'isModerator': false,
      'vote': null,
    };

    debugPrint('[$_tag] Updated session data:');
    debugPrint(json.encode(session));

    debugPrint('[$_tag] Saving to localStorage:');
    debugPrint('Data: ${json.encode(sessions)}');
    _saveSessionsToStorage(sessions);
    debugPrint('Verified saved data: ${json.encode(getSessionsFromStorage())}');

    debugPrint('\n[$_tag] ====== BROADCASTING STATE ======');
    _broadcastUpdate(sessionId);
    debugPrint('\n[$_tag] Joined session successfully');
  }

  Future<void> addTask(String sessionId, TaskData task) async {
    debugPrint('\n[$_tag] ====== ADDING TASK ======');
    debugPrint('[$_tag] Task: ${task.name} to session: $sessionId');
    
    final sessions = getSessionsFromStorage();
    if (!sessions.containsKey(sessionId)) {
      throw SessionNotFoundException('Session $sessionId not found');
    }

    final session = sessions[sessionId] as Map<String, dynamic>;
    
    // First add the task
    final tasks = (session['tasks'] as List<dynamic>);
    tasks.add(task.toJson());
    _saveSessionsToStorage(sessions);
    _broadcastUpdate(sessionId);
    
    // Then set it as the active task in a separate operation
    session['taskName'] = task.name;
    
    // Reset all votes when adding a new task
    final participants = session['participants'] as Map<String, dynamic>;
    for (var participant in participants.values) {
      participant['hasVoted'] = false;
      participant['vote'] = null;
    }
    session['votesRevealed'] = false;

    // Save and broadcast again with the updated task name
    _saveSessionsToStorage(sessions);
    _broadcastUpdate(sessionId);
    debugPrint('[$_tag] Task added successfully\n');
  }

  Future<void> setTaskName(String sessionId, String name) async {
    debugPrint('\n[$_tag] ====== SETTING TASK NAME ======');
    debugPrint('[$_tag] SessionId: $sessionId, Task: $name');
    
    final sessions = getSessionsFromStorage();
    if (!sessions.containsKey(sessionId)) {
      throw SessionNotFoundException('Session $sessionId not found');
    }

    final session = sessions[sessionId] as Map<String, dynamic>;
    session['taskName'] = name;
    
    // Reset all votes when changing tasks
    final participants = session['participants'] as Map<String, dynamic>;
    for (var participant in participants.values) {
      participant['hasVoted'] = false;
      participant['vote'] = null;
    }
    session['votesRevealed'] = false;

    _saveSessionsToStorage(sessions);
    _broadcastUpdate(sessionId);
    debugPrint('[$_tag] Task name updated successfully');
  }

  Future<void> removeTask(String sessionId, String taskName) async {
    final sessions = getSessionsFromStorage();
    final session = sessions[sessionId] as Map<String, dynamic>;
    final tasks = session['tasks'] as List<dynamic>;
    tasks.removeWhere((t) => t['name'] == taskName);
    _saveSessionsToStorage(sessions);
    _broadcastUpdate(sessionId);
  }

  Future<void> updateTaskEstimate(String sessionId, String taskName, String estimate) async {
    final sessions = getSessionsFromStorage();
    final session = sessions[sessionId] as Map<String, dynamic>;
    final tasks = session['tasks'] as List<dynamic>;
    final task = tasks.firstWhere((t) => t['name'] == taskName);
    task['estimate'] = estimate;
    _saveSessionsToStorage(sessions);
    _broadcastUpdate(sessionId);
  }

  Future<void> resetVotes(String sessionId) async {
    final sessions = getSessionsFromStorage();
    final session = sessions[sessionId] as Map<String, dynamic>;
    final participants = session['participants'] as Map<String, dynamic>;
    for (final participant in participants.values) {
      participant['hasVoted'] = false;
      participant['vote'] = null;
    }
    session['votesRevealed'] = false;
    _saveSessionsToStorage(sessions);
    _broadcastUpdate(sessionId);
  }

  Future<void> submitVote(String sessionId, String userName, String vote) async {
    debugPrint('\n[$_tag] ====== SUBMITTING VOTE ======');
    debugPrint('[$_tag] SessionId: $sessionId, User: $userName, Vote: $vote');
    
    final sessions = getSessionsFromStorage();
    if (!sessions.containsKey(sessionId)) {
      throw SessionNotFoundException('Session $sessionId not found');
    }

    final session = sessions[sessionId] as Map<String, dynamic>;
    final participants = session['participants'] as Map<String, dynamic>;
    
    if (!participants.containsKey(userName)) {
      throw Exception('User $userName not found in session');
    }

    // Only allow voting if there's an active task
    if (session['taskName'] == null || session['taskName'].isEmpty) {
      debugPrint('[$_tag] Cannot vote: No active task');
      return;
    }

    final participant = participants[userName] as Map<String, dynamic>;
    participant['hasVoted'] = true;
    participant['vote'] = vote;

    _saveSessionsToStorage(sessions);
    _broadcastUpdate(sessionId);
    debugPrint('[$_tag] Vote submitted successfully');
  }

  Stream<SessionState> getSessionStream(String sessionId) {
    debugPrint('\n[$_tag] Getting session stream for: $sessionId');
    return _sessionController.stream
        .where((event) => event['sessionId'] == sessionId)
        .distinct()
        .map((event) {
          final state = event['state'] as Map<String, dynamic>;
          debugPrint('[$_tag] Converting to SessionState:');
          debugPrint('  - Task Name: ${state['taskName']}');
          debugPrint('  - Tasks: ${(state['tasks'] as List).map((t) => t['name']).join(', ')}');
          debugPrint('  - Participants: ${(state['participants'] as Map).keys.join(', ')}');
          final result = SessionState.fromJson(state);
          debugPrint('[$_tag] State broadcasted successfully');
          return result;
        });
  }

  Map<String, dynamic> getSessionsFromStorage() {
    final stored = html.window.localStorage['planning_poker_sessions'];
    if (stored == null) {
      debugPrint('[$_tag] Getting from storage: null');
      return {};
    }
    debugPrint('[$_tag] Getting from storage: $stored');
    return json.decode(stored) as Map<String, dynamic>;
  }

  void _saveSessionsToStorage(Map<String, dynamic> sessions) {
    final jsonString = json.encode(sessions);
    html.window.localStorage['planning_poker_sessions'] = jsonString;
    debugPrint('[$_tag] Saved to storage: $jsonString');
  }

  void _broadcastUpdate(String sessionId) {
    debugPrint('\n[$_tag] ====== BROADCASTING UPDATE ======');
    final sessions = getSessionsFromStorage();
    if (sessions.containsKey(sessionId)) {
      final state = sessions[sessionId] as Map<String, dynamic>;
      debugPrint('[$_tag] Broadcasting state:');
      debugPrint(json.encode(state));
      
      try {
        _sessionController.add({
          'sessionId': sessionId,
          'state': state,
        });
        debugPrint('[$_tag] Update broadcasted successfully');
      } catch (e) {
        debugPrint('[$_tag] Error broadcasting update: $e');
      }
    }
  }

  Future<SessionState> getSessionState(String sessionId) async {
    debugPrint('\n[$_tag] ====== GETTING SESSION STATE ======');
    debugPrint('[$_tag] SessionId: $sessionId');
    
    final sessions = getSessionsFromStorage();
    if (!sessions.containsKey(sessionId)) {
      throw SessionNotFoundException('Session $sessionId not found');
    }

    final session = sessions[sessionId] as Map<String, dynamic>;
    debugPrint('[$_tag] Current session state:');
    debugPrint('  - Task Name: ${session['taskName']}');
    debugPrint('  - Tasks Count: ${(session['tasks'] as List).length}');
    debugPrint('  - Participants: ${(session['participants'] as Map).keys.join(', ')}');

    // Force a broadcast update to ensure all clients are in sync
    _broadcastUpdate(sessionId);
    
    return SessionState.fromJson(session);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _sessionController.close();
  }
}