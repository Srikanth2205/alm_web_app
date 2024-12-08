import 'package:flutter/material.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import '../models/team.dart';
import '../services/storage_service.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import '../services/logger_service.dart';

enum OvertimePolicy { optional, always, never }

class StandupMeetingPage extends StatefulWidget {
  const StandupMeetingPage({super.key});

  @override
  State<StandupMeetingPage> createState() => _StandupMeetingPageState();
}

class _StandupMeetingPageState extends State<StandupMeetingPage> with SingleTickerProviderStateMixin {
  List<Team> teams = [];
  Team? selectedTeam;
  int totalMinutes = 15;
  int numberOfPeople = 1;
  bool useCustomCount = true;
  bool isMeetingInProgress = false;
  int currentMemberIndex = -1;
  Timer? meetingTimer;
  int remainingSeconds = 0;
  OvertimePolicy overtimePolicy = OvertimePolicy.optional;

  late AnimationController _animationController;
  late Animation<double> _animation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool showEndGif = false;
  String? gifUrl;
  String? dadJoke;
  bool isLoadingJoke = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _audioPlayer.setSource(AssetSource('audio/beep-6-96243.mp3'));
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    meetingTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final loadedTeams = await StorageService.loadTeams();
    setState(() {
      teams = loadedTeams;
    });
  }

  void startMeeting() async {
    int memberCount = useCustomCount ? numberOfPeople : (selectedTeam?.members.length ?? 1);
    if (memberCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one person!')),
      );
      await LoggerService.log('Meeting start failed: No members selected');
      return;
    }

    await LoggerService.log('Starting meeting with $memberCount members for $totalMinutes minutes');
    setState(() {
      isMeetingInProgress = true;
      currentMemberIndex = 0;
      remainingSeconds = ((totalMinutes / memberCount) * 60).round();
    });
    
    _animationController.forward();
    startTimer();
  }

  void startTimer() {
    meetingTimer?.cancel();
    meetingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        remainingSeconds--;
        if (remainingSeconds == 0) {
          _playTimerEndSound();
        }
      });
    });
  }

  Future<void> _playTimerEndSound() async {
    try {
      await _audioPlayer.setSource(AssetSource('audio/beep-6-96243.mp3'));
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  String formatTime(int seconds) {
    final isNegative = seconds < 0;
    final absoluteSeconds = seconds.abs();
    final minutes = absoluteSeconds ~/ 60;
    final remainingSecs = absoluteSeconds % 60;
    return '${isNegative ? '-' : ''}$minutes:${remainingSecs.toString().padLeft(2, '0')}';
  }

  void nextMember() async {
    int totalMembers = useCustomCount ? numberOfPeople : (selectedTeam?.members.length ?? 1);
    if (currentMemberIndex < totalMembers - 1) {
      await LoggerService.log('Moving to next member (${currentMemberIndex + 2}/$totalMembers)');
      setState(() {
        currentMemberIndex++;
        remainingSeconds = ((totalMinutes / totalMembers) * 60).round();
      });
      _animationController.reset();
      _animationController.forward();
    } else {
      await LoggerService.log('Last member finished, ending meeting');
      endMeeting();
    }
  }

  Future<String?> _getRandomGif() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.giphy.com/v1/gifs/random?api_key=$GIPHY_API_KEY&tag=celebration&rating=g'
        ),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['images']['original']['url'];
      }
    } catch (e) {
      debugPrint('Error fetching GIF: $e');
    }
    return null;
  }

  Future<String?> _getDadJoke() async {
    const String apiUrl = "https://icanhazdadjoke.com/";
    
    try {
      await LoggerService.log('Fetching dad joke...');
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          "Accept": "application/json",
          "User-Agent": "Standup Timer App (https://github.com/yourusername/standuptimer)"
        },
      );

      await LoggerService.log('Dad joke API response status: ${response.statusCode}');
      await LoggerService.log('Dad joke API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['joke'] ?? "Why did the developer quit his job? Because he didn't get arrays!";
      }
    } catch (e) {
      await LoggerService.log('Error fetching joke: $e');
    }
    return "Why did the programmer go broke?\nBecause they used up all their cache!";
  }

  void endMeeting() async {
    await LoggerService.log('Meeting ended');
    meetingTimer?.cancel();
    setState(() {
      isLoadingJoke = true;
    });
    
    await LoggerService.log('Fetching end-of-meeting content');
    final Future<String?> gifFuture = _getRandomGif();
    final Future<String?> jokeFuture = _getDadJoke();
    
    final results = await Future.wait([gifFuture, jokeFuture]);
    final randomGif = results[0];
    final joke = results[1];
    
    await LoggerService.log('End-of-meeting content loaded');
    setState(() {
      showEndGif = true;
      gifUrl = randomGif;
      dadJoke = joke;
      isLoadingJoke = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Standup Meeting'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: isMeetingInProgress ? buildMeetingView() : buildSetupView(),
    );
  }

  Widget buildMeetingView() {
    if (showEndGif) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Meeting Ended!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: gifUrl != null
                    ? Image.network(
                        gifUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / 
                                    loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text('🎉 Meeting Complete! 🎉'),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            if (isLoadingJoke)
              const CircularProgressIndicator()
            else if (dadJoke != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  dadJoke!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  showEndGif = false;
                  gifUrl = null;
                  dadJoke = null;
                  isMeetingInProgress = false;
                  currentMemberIndex = -1;
                });
                _animationController.reset();
              },
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Exit Meeting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }

    String currentSpeaker = useCustomCount 
        ? 'Person ${currentMemberIndex + 1}'
        : selectedTeam!.members[currentMemberIndex];

    final timeColor = remainingSeconds < 0 ? Colors.red : null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: _animation,
            child: Text(
              'Current Speaker:\n$currentSpeaker',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            formatTime(remainingSeconds),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: timeColor,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: nextMember,
                child: const Text('Next Speaker'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: endMeeting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('End Meeting'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSetupView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meeting Type Selection
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Use Team'),
                  value: false,
                  groupValue: useCustomCount,
                  onChanged: (value) {
                    setState(() {
                      useCustomCount = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text('Custom Count'),
                  value: true,
                  groupValue: useCustomCount,
                  onChanged: (value) {
                    setState(() {
                      useCustomCount = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Different UI based on selection
          if (useCustomCount)
            buildCustomCountSetup()
          else
            buildTeamSetup(),

          const Spacer(),
          Center(
            child: ElevatedButton(
              onPressed: startMeeting,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Create Meeting'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
    Widget buildCustomCountSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meeting Duration
        Row(
          children: [
            const Text(
              'The meeting duration will be',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              width: 100,
              child: SpinBox(
                min: 1,
                max: 60,
                value: totalMinutes.toDouble(),
                onChanged: (value) {
                  setState(() {
                    totalMinutes = value.toInt();
                  });
                },
                textStyle: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
                spacing: 0,
                showCursor: false,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'minutes',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Number of Speakers
        Row(
          children: [
            const Text(
              'There are',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              width: 80,
              child: SpinBox(
                min: 1,
                max: 50,
                value: numberOfPeople.toDouble(),
                onChanged: (value) {
                  setState(() {
                    numberOfPeople = value.toInt();
                  });
                },
                textStyle: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
                spacing: 0,
                showCursor: false,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'speakers',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Time per Speaker
        Row(
          children: [
            const Text(
              'Each speaking for',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              width: 100,
              child: Text(
                '${(totalMinutes / numberOfPeople).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'minutes',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 48),

        // Overtime Policy
        const Text(
          "Allow overtime when a speaker's time is up:",
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Radio<OvertimePolicy>(
              value: OvertimePolicy.optional,
              groupValue: overtimePolicy,
              onChanged: (OvertimePolicy? value) {
                setState(() {
                  overtimePolicy = value!;
                });
              },
            ),
            const Text('Optional'),
            const SizedBox(width: 24),
            Radio<OvertimePolicy>(
              value: OvertimePolicy.always,
              groupValue: overtimePolicy,
              onChanged: (OvertimePolicy? value) {
                setState(() {
                  overtimePolicy = value!;
                });
              },
            ),
            const Text('Always'),
            const SizedBox(width: 24),
            Radio<OvertimePolicy>(
              value: OvertimePolicy.never,
              groupValue: overtimePolicy,
              onChanged: (OvertimePolicy? value) {
                setState(() {
                  overtimePolicy = value!;
                });
              },
            ),
            const Text('Never'),
          ],
        ),
      ],
    );
  }
Widget buildTeamSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Team Selection
        DropdownButton<Team>(
          value: selectedTeam,
          hint: const Text('Select Team'),
          isExpanded: true,
          items: teams.map((Team team) {
            return DropdownMenuItem<Team>(
              value: team,
              child: Text('${team.name} (${team.members.length} members)'),
            );
          }).toList(),
          onChanged: (Team? newValue) {
            setState(() {
              selectedTeam = newValue;
            });
          },
        ),
        const SizedBox(height: 24),

        // Meeting Duration
        TextField(
          decoration: const InputDecoration(
            labelText: 'Meeting Duration (minutes)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() {
              totalMinutes = int.tryParse(value) ?? 15;
            });
          },
        ),

        if (selectedTeam != null) ...[
          const SizedBox(height: 24),
          Text(
            'Time per person: ${(totalMinutes / selectedTeam!.members.length).toStringAsFixed(2)} minutes',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Team Members: ${selectedTeam!.members.join(", ")}',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ],
    );
  }
}