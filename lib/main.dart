import 'package:flutter/material.dart';
import 'pages/planning_poker_page.dart';
import 'pages/standup_meeting_page.dart';
import 'pages/estimation_history_page.dart';
import 'pages/team_management_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Work Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Management'),
        backgroundColor: Colors.purple,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.purple,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Work Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Main Features
            ListTile(
              leading: const Icon(Icons.casino, color: Colors.purple),
              title: const Text('Planning Poker'),
              subtitle: const Text('Estimate user stories'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Planning Poker'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: const Text('Create New Session'),
                          onTap: () {
                            Navigator.pop(context);
                            _showCreateSessionDialog(context);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.group_add),
                          title: const Text('Join Session'),
                          onTap: () {
                            Navigator.pop(context);
                            _showJoinSessionDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: Colors.purple),
              title: const Text('Standup Meeting'),
              subtitle: const Text('Run daily standups'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StandupMeetingPage()),
                );
              },
            ),
            const Divider(),
            // Management Tools
            ListTile(
              leading: const Icon(Icons.people, color: Colors.purple),
              title: const Text('Team Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TeamManagementPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.purple),
              title: const Text('Estimation History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EstimationHistoryPage()),
                );
              },
            ),
            const Divider(),
            // About Section
            ListTile(
              leading: const Icon(Icons.info, color: Colors.purple),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'Work Management',
                  applicationVersion: '1.0.0',
                  children: const [
                    Text('A tool for agile teams to manage their daily work.'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.yellow[50],
        child: const Center(
          child: Text(
            'Welcome to Work Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Session'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            hintText: 'Enter your name (Moderator)',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlanningPokerPage(
                      sessionId: sessionId,
                      userName: name,
                      isModerator: true,
                    ),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinSessionDialog(BuildContext context) {
    final sessionIdController = TextEditingController();
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sessionIdController,
              decoration: const InputDecoration(
                labelText: 'Session ID',
                hintText: 'Enter the session ID',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final sessionId = sessionIdController.text.trim();
              final name = nameController.text.trim();
              if (sessionId.isNotEmpty && name.isNotEmpty) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlanningPokerPage(
                      sessionId: sessionId,
                      userName: name,
                      isModerator: false,
                    ),
                  ),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

