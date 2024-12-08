import 'dart:async';
import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// Add extension outside the class
extension ListExtension<T> on List<T> {
  T mostCommon() {
    if (isEmpty) throw Exception('Cannot get most common element of empty list');
    return fold<Map<T, int>>(
      {},
      (map, element) => map..update(element, (count) => count + 1, ifAbsent: () => 1),
    ).entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

class PlanningPokerPage extends StatefulWidget {
  final String sessionId;
  final String userName;
  final bool isModerator;

  const PlanningPokerPage({
    Key? key,
    required this.sessionId,
    required this.userName,
    required this.isModerator,
  }) : super(key: key);

  @override
  State<PlanningPokerPage> createState() => _PlanningPokerPageState();
}

class _PlanningPokerPageState extends State<PlanningPokerPage> {
  static const String _tag = 'PlanningPokerPage';
  final _sessionService = SessionService();
  late StreamSubscription<SessionState> _sessionSubscription;
  final taskNameController = TextEditingController();
  String? _lastKnownState;
  
  // State variables
  final List<TaskData> _tasks = [];
  String? _taskName;
  final Map<String, ParticipantStatus> _participants = {};
  bool _showResults = false;
  Timer? _timer;
  Timer? _countdownTimer;
  bool _isTimerActive = false;
  bool _isCountingDown = false;
  int _countdown = 0;
  String _timerDisplay = '00:00';
  final List<String> cards = [
    '0', '½', '1', '2', '3', '5', '8', '13', '20', '40', '100', '?'
  ];
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('\n[$_tag] Initializing state');
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    debugPrint('\n[$_tag] ====== STARTING SESSION INITIALIZATION ======');
    debugPrint('[$_tag] User: ${widget.userName}, IsModerator: ${widget.isModerator}, SessionId: ${widget.sessionId}');

    try {
      // Set up stream listener first
      debugPrint('[$_tag] Setting up session stream listener');
      _sessionSubscription = _sessionService
          .getSessionStream(widget.sessionId)
          .listen(
            _handleStreamUpdate,
            onError: (error) {
              debugPrint('[$_tag] Stream error: $error');
            },
          );

      if (widget.isModerator) {
        debugPrint('\n[$_tag] MODERATOR: Creating new session');
        await _sessionService.createSession(widget.sessionId, widget.userName);
      } else {
        debugPrint('\n[$_tag] ATTENDEE: Joining existing session');
        await _sessionService.joinSession(widget.sessionId, widget.userName);
      }

      // Get initial state
      debugPrint('[$_tag] Fetching initial session state...');
      final state = await _sessionService.getSessionState(widget.sessionId);
      _handleStreamUpdate(state);

      debugPrint('[$_tag] Session initialization completed successfully\n');
    } catch (e) {
      debugPrint('[$_tag] Error during initialization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleStreamUpdate(SessionState state) {
    debugPrint('\n[$_tag] ====== STREAM UPDATE RECEIVED ======');
    
    if (mounted) {
      setState(() {
        // Update tasks
        _tasks.clear();
        _tasks.addAll(state.tasks);
        
        // Update task name
        if (state.taskName.isNotEmpty) {
          _taskName = state.taskName;
        }
        
        // Update participants
        _participants.clear();
        state.participants.forEach((key, value) {
          _participants[key] = ParticipantStatus(
            hasVoted: value.hasVoted,
            vote: value.vote,
          );
        });
        
        _showResults = state.votesRevealed;
      });

      // Handle timer state separately
      _handleTimerState(state);
    }
  }

  void _handleTimerState(SessionState state) {
    if (state.isTimerActive && state.timerEndTime != null) {
      debugPrint('[$_tag] Timer is active, end time: ${state.timerEndTime}');
      final remaining = state.timerEndTime!.difference(DateTime.now()).inSeconds;
      _remainingSeconds = remaining > 0 ? remaining : 0;
      
      if (_remainingSeconds > 0 && _countdownTimer == null) {
        debugPrint('[$_tag] Starting countdown timer');
        _startCountdown(state.timerEndTime!);
      }
      
      if (_remainingSeconds <= 0) {
        debugPrint('[$_tag] Timer completed, showing results');
        _showResults = true;
        _countdownTimer?.cancel();
        _countdownTimer = null;
      }
    }
  }

  void _startCountdown(DateTime endTime) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final remaining = endTime.difference(DateTime.now()).inSeconds;
        setState(() {
          _remainingSeconds = remaining > 0 ? remaining : 0;
          debugPrint('[$_tag] Countdown: $_remainingSeconds seconds remaining');
        });
        
        if (remaining <= 0) {
          debugPrint('[$_tag] Countdown finished, revealing votes');
          timer.cancel();
          _countdownTimer = null;
          setState(() {
            _showResults = true;
          });
          // Auto-reveal votes when timer ends
          if (widget.isModerator) {
            _sessionService.revealVotes(widget.sessionId);
          }
        }
      }
    });
  }

  Future<void> _addTask(String taskName) async {
    debugPrint('\n[$_tag] ====== CREATING NEW TASK ======');
    debugPrint('[$_tag] Task name: $taskName');
    
    try {
      // Add the task - this will automatically set it as active
      await _sessionService.addTask(
        widget.sessionId,
        TaskData(name: taskName, estimate: null),
      );
      
      // Update local state
      setState(() {
        _taskName = taskName;
      });
      
      debugPrint('[$_tag] Task creation completed successfully\n');
    } catch (e) {
      debugPrint('[$_tag] Error during task creation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setActiveTask(String taskName) {
    debugPrint('[$_tag] Setting active task: $taskName');
    setState(() => _taskName = taskName);
    _sessionService.setTaskName(widget.sessionId, taskName);
  }

  void _removeTask(String taskName) {
    debugPrint('[$_tag] Removing task: $taskName');
    _sessionService.removeTask(widget.sessionId, taskName);
  }

  void _saveEstimate() {
    debugPrint('[$_tag] Attempting to save estimate for task: $_taskName');
    if (_taskName == null) {
      debugPrint('[$_tag] No task selected, cannot save estimate');
      return;
    }

    // Find the current task in the tasks list
    final taskIndex = _tasks.indexWhere((task) => task.name == _taskName);
    if (taskIndex == -1) {
      debugPrint('[$_tag] Task not found in list: $_taskName');
      return;
    }

    // Collect and validate votes
    final votes = _participants.values
        .where((p) => p.hasVoted && p.vote != null)
        .map((p) => p.vote!)
        .toList();
    
    debugPrint('[$_tag] Collected votes: $votes');
    if (votes.isEmpty) {
      debugPrint('[$_tag] No valid votes to save');
      return;
    }

    // Calculate most common vote
    final voteCount = <String, int>{};
    String mostCommonVote = votes[0];
    int maxCount = 1;

    for (var vote in votes) {
      final count = (voteCount[vote] ?? 0) + 1;
      voteCount[vote] = count;
      if (count > maxCount) {
        maxCount = count;
        mostCommonVote = vote;
      }
    }

    debugPrint('[$_tag] Most common vote: $mostCommonVote');

    // Update local state
    setState(() {
      _tasks[taskIndex].estimate = mostCommonVote;
    });

    // Update session state
    _sessionService.updateTaskEstimate(widget.sessionId, _taskName!, mostCommonVote);
    debugPrint('[$_tag] Estimate saved successfully');

    // Reset voting state
    setState(() {
      _taskName = null;
      _showResults = false;
    });
    _sessionService.resetVotes(widget.sessionId);
    _stopTimer();

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estimate saved: $mostCommonVote'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    debugPrint('[$_tag] Showing error dialog: $message');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('[$_tag] User acknowledged error, returning to home');
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    if (_isTimerActive) return;

    setState(() {
      _isTimerActive = true;
      _timerDisplay = '00:00';
    });

    final startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final duration = DateTime.now().difference(startTime);
      setState(() {
        _timerDisplay =
            '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _isTimerActive = false;
      _isCountingDown = false;
      _countdown = 0;
      _timerDisplay = '00:00';
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _isTimerActive = false;
      _isCountingDown = false;
    });
  }

  Widget _buildCard(int index) {
    final isSelected = _taskName == cards[index];
    final bool isVotingEnabled = _taskName != null && _taskName!.isNotEmpty;
    
    return Card(
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Colors.purple.shade100 : null,
      child: InkWell(
        onTap: isVotingEnabled 
            ? () async {
                setState(() => _taskName = cards[index]);
                await _submitVote(cards[index]);
              }
            : null,
        child: Stack(
          children: [
            Center(
              child: Text(
                cards[index],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isVotingEnabled ? Colors.black : Colors.grey,
                ),
              ),
            ),
            if (!isVotingEnabled)
              Positioned.fill(
                child: Container(
                  color: Colors.grey.withOpacity(0.1),
                  child: Center(
                    child: Text(
                      'Wait for task',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _checkAllVoted() {
    final allVoted = !_participants.values.any((p) => !p.hasVoted);
    debugPrint('[$_tag] Checking if all voted: $allVoted');
    if (allVoted) {
      debugPrint('[$_tag] All participants have voted');
      _startTimer();
      if (widget.isModerator) {
        _showAllVotedDialog();
      }
    }
  }

  void _showAllVotedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Votes In!'),
        content: const Text('Everyone has voted. Would you like to reveal the votes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Wait'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _showResults = true);
              Navigator.pop(context);
            },
            child: const Text('Reveal Votes'),
          ),
        ],
      ),
    );
  }

  void _showTaskNameDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Create Task'),
        content: TextField(
          controller: taskNameController,
          decoration: const InputDecoration(
            labelText: 'Task Name',
            hintText: 'Enter the task to be estimated',
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _createNewTask(value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final taskName = taskNameController.text.trim();
              if (taskName.isNotEmpty) {
                _createNewTask(taskName);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createNewTask(String name) async {
    debugPrint('\n[$_tag] ====== CREATING NEW TASK ======');
    debugPrint('[$_tag] Task name: $name');
    
    try {
      await _addTask(name);
      taskNameController.clear();
    } catch (e) {
      debugPrint('[$_tag] ERROR creating task: $e\n');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTaskList() {
    return Expanded(
      child: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final isActive = task.name == _taskName;
          
          return ListTile(
            title: Text(task.name),
            subtitle: task.estimate != null 
                ? Text('Estimated: ${task.estimate}')
                : const Text('Not estimated'),
            tileColor: isActive ? Colors.purple.shade50 : null,
            trailing: widget.isModerator
                ? IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeTask(task.name),
                  )
                : null,
            onTap: widget.isModerator ? () => _setActiveTask(task.name) : null,
          );
        },
      ),
    );
  }

  void _showSessionIdDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this Session ID with your team:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SelectableText(
                    widget.sessionId,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy to clipboard',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: widget.sessionId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Session ID copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildVotingArea() {
    return Expanded(
      child: Column(
        children: [
          // Current Task Display
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Current Task: ${_taskName ?? "No task selected"}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Timer Display
          if (_remainingSeconds > 0)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Votes will be revealed in $_remainingSeconds seconds',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ),

          // Results Display
          if (_showResults && _participants.values.every((p) => p.hasVoted))
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Average',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _calculateAverage(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.green.shade200,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Most Common',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _calculateMostCommon(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.isModerator)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ElevatedButton(
                            onPressed: _saveEstimate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save Estimate'),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Add the analytics widget here
                _buildVoteAnalytics(),
              ],
            ),

          // Voting Cards
          if (!_showResults)
            Expanded(
              child: Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List<Widget>.from(cards.map((card) {
                    final isSelected = _participants[widget.userName]?.vote == card;
                    return _buildVoteCard(card, isSelected);
                  })),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Row(
              children: [
                const Icon(Icons.people, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Participants (${_participants.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _participants.length,
              itemBuilder: (context, index) {
                final entry = _participants.entries.elementAt(index);
                final userName = entry.key;
                final status = entry.value;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: Text(
                      userName[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                  title: Text(userName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status.hasVoted)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade400,
                          size: 20,
                        ),
                      if (_showResults && status.vote != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.vote!,
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionIdDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            'Session ID: ${widget.sessionId}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Copy Session ID',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.sessionId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session ID copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _refreshState() async {
    debugPrint('\n[$_tag] ====== MANUALLY REFRESHING STATE ======');
    try {
      // Use the public method instead of private one
      final sessions = _sessionService.getSessionsFromStorage();
      final currentState = json.encode(sessions[widget.sessionId]);
      
      // Only update if state has changed
      if (_lastKnownState != currentState) {
        _lastKnownState = currentState;
        final state = await _sessionService.getSessionState(widget.sessionId);
        _handleStreamUpdate(state);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('State refreshed successfully'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[$_tag] Error refreshing state: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Text('Session ID: ${widget.sessionId}'),
            const Spacer(),
            // Add refresh button
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshState,
              tooltip: 'Refresh state',
            ),
            // Copy session ID button
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy Session ID',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.sessionId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session ID copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          // Left Panel - Task List (visible to both moderator and attendee)
          Container(
            width: 300,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.purple.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tasks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.isModerator)
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _showTaskNameDialog(),
                          tooltip: 'Add New Task',
                        ),
                    ],
                  ),
                ),
                _buildTaskList(),
              ],
            ),
          ),

          // Center Panel - Voting Cards
          _buildVotingArea(),

          // Right Panel - Participants
          _buildParticipantsList(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sessionSubscription.cancel();
    _countdownTimer?.cancel();
    taskNameController.dispose();
    super.dispose();
  }

  // Add these helper methods
  String _calculateAverage() {
    final votes = _participants.values
        .where((p) => p.hasVoted && p.vote != null && p.vote != '?')
        .map((p) => _parseVote(p.vote!))
        .toList();
    
    if (votes.isEmpty) return 'N/A';
    final average = votes.reduce((a, b) => a + b) / votes.length;
    return average.toStringAsFixed(1);
  }

  String _calculateMostCommon() {
    final votes = _participants.values
        .where((p) => p.hasVoted && p.vote != null)
        .map((p) => p.vote!)
        .toList();
    
    if (votes.isEmpty) return 'N/A';
    return votes.mostCommon();
  }

  double _parseVote(String vote) {
    if (vote == '½') return 0.5;
    try {
      return double.parse(vote);
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _submitVote(String vote) async {
    debugPrint('[$_tag] Submitting vote: $vote for user: ${widget.userName}');
    setState(() => _taskName = vote);
    await _sessionService.submitVote(widget.sessionId, widget.userName, vote);
    
    // Check if all participants have voted
    final allVoted = _participants.values.every((p) => p.hasVoted);
    if (allVoted) {
      debugPrint('[$_tag] All participants have voted');
      // Start timer for both moderator and attendees
      if (widget.isModerator) {
        await _sessionService.startVoteTimer(widget.sessionId);
        debugPrint('[$_tag] Vote timer started by moderator');
      } else {
        // Notify moderator that all votes are in
        debugPrint('[$_tag] All votes in, notifying moderator');
        await _sessionService.notifyAllVoted(widget.sessionId);
      }
    }
  }

  // Add the vote card builder
  Widget _buildVoteCard(String card, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(4),
      decoration: _buildCardDecoration(isSelected: isSelected),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _submitVote(card),
          child: Container(
            width: 80,
            height: 120,
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text(
                card,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue.shade700 : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Add these new methods for analytics
  Map<String, int> _calculateVoteDistribution() {
    final distribution = <String, int>{};
    final votes = _participants.values
        .where((p) => p.hasVoted && p.vote != null)
        .map((p) => p.vote!)
        .toList();

    for (var vote in votes) {
      distribution[vote] = (distribution[vote] ?? 0) + 1;
    }
    return distribution;
  }

  Widget _buildVoteAnalytics() {
    final distribution = _calculateVoteDistribution();
    final totalVotes = distribution.values.fold(0, (sum, count) => sum + count);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vote Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...distribution.entries.map((entry) {
            final percentage = (entry.value / totalVotes * 100).toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: entry.value / totalVotes,
                              child: Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade400,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          ' $percentage% (${entry.value})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Add this method for a gradient background
  BoxDecoration _buildGradientBackground() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.blue.shade50,
          Colors.white,
          Colors.blue.shade50,
        ],
      ),
    );
  }

  // Add this method for card styling
  BoxDecoration _buildCardDecoration({bool isSelected = false}) {
    return BoxDecoration(
      color: isSelected ? Colors.blue.shade100 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      border: Border.all(
        color: isSelected ? Colors.blue : Colors.grey.shade300,
        width: isSelected ? 2 : 1,
      ),
    );
  }

  // Update participant list styling
  Widget _buildParticipantList() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Participants',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _participants.entries.map((entry) {
              final hasVoted = entry.value.hasVoted;
              return Chip(
                avatar: Icon(
                  hasVoted ? Icons.check_circle : Icons.person,
                  color: hasVoted ? Colors.green : Colors.grey,
                  size: 18,
                ),
                label: Text(entry.key),
                backgroundColor: hasVoted ? Colors.green.shade50 : Colors.grey.shade50,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Add a timer indicator widget
  Widget _buildTimerIndicator(int secondsRemaining) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            'Revealing in $secondsRemaining seconds',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ParticipantStatus {
  final bool hasVoted;
  final String? vote;

  ParticipantStatus({
    this.hasVoted = false,
    this.vote,
  });
}
 