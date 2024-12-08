import 'dart:io';
import 'dart:async';
import 'dart:convert';

void main() async {
  final sessions = <String, SessionData>{};
  
  final server = await HttpServer.bind('localhost', 8080);
  print('WebSocket server running on ws://localhost:8080');

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      handleConnection(socket, sessions);
    }
  }
}

void handleConnection(WebSocket socket, Map<String, SessionData> sessions) {
  print('Client connected');

  socket.listen(
    (message) {
      final data = jsonDecode(message);
      final sessionId = data['sessionId'];
      
      switch (data['type']) {
        case 'create_session':
          sessions[sessionId] = SessionData(
            moderator: socket,
            participants: {data['userName']: socket},
            taskName: data['taskName'],
          );
          broadcastSessionState(sessions[sessionId]!, sessionId);
          break;

        case 'join_session':
          final session = sessions[sessionId];
          if (session != null) {
            session.participants[data['userName']] = socket;
            broadcastSessionState(session, sessionId);
          }
          break;

        case 'submit_vote':
          final session = sessions[sessionId];
          if (session != null) {
            session.votes[data['userName']] = data['vote'];
            broadcastSessionState(session, sessionId);
          }
          break;

        case 'reveal_votes':
          final session = sessions[sessionId];
          if (session != null) {
            session.votesRevealed = true;
            broadcastSessionState(session, sessionId);
          }
          break;

        case 'reset_voting':
          final session = sessions[sessionId];
          if (session != null) {
            session.votes.clear();
            session.votesRevealed = false;
            broadcastSessionState(session, sessionId);
          }
          break;

        case 'save_estimate':
          final session = sessions[sessionId];
          if (session != null) {
            session.finalEstimate = data['finalEstimate'];
            broadcastSessionState(session, sessionId);
          }
          break;
      }
    },
    onDone: () {
      print('Client disconnected');
      // Remove client from sessions
      sessions.forEach((sessionId, session) {
        session.participants.removeWhere((_, socket) => socket == socket);
        if (session.participants.isEmpty) {
          sessions.remove(sessionId);
        }
      });
    },
  );
}

void broadcastSessionState(SessionData session, String sessionId) {
  final state = {
    'sessionId': sessionId,
    'taskName': session.taskName,
    'participants': session.participants.map((userName, _) {
      return MapEntry(userName, {
        'userName': userName,
        'hasVoted': session.votes.containsKey(userName),
        'vote': session.votesRevealed ? session.votes[userName] : null,
        'isModerator': session.moderator == session.participants[userName],
      });
    }),
    'votesRevealed': session.votesRevealed,
    'finalEstimate': session.finalEstimate,
  };

  final message = jsonEncode(state);
  for (final socket in session.participants.values) {
    socket.add(message);
  }
}

class SessionData {
  final WebSocket moderator;
  final Map<String, WebSocket> participants;
  final Map<String, String> votes = {};
  String? taskName;
  bool votesRevealed = false;
  String? finalEstimate;

  SessionData({
    required this.moderator,
    required this.participants,
    this.taskName,
  });
} 