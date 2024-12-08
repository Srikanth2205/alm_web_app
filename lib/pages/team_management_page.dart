import 'package:flutter/material.dart';
import '../models/team.dart';
import '../services/storage_service.dart';

class TeamManagementPage extends StatefulWidget {
  const TeamManagementPage({super.key});

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  List<Team> teams = [];
  Team? selectedTeam;
  TextEditingController teamNameController = TextEditingController();
  TextEditingController memberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final loadedTeams = await StorageService.loadTeams();
    setState(() {
      teams = loadedTeams;
    });
  }

  void _createTeam(String name) {
    if (name.isEmpty) return;
    
    setState(() {
      teams.add(Team(name: name, members: []));
      selectedTeam = teams.last;
      StorageService.saveTeams(teams);
    });
    teamNameController.clear();
  }

  void _addMember(String name) {
    if (name.isEmpty || selectedTeam == null) return;

    setState(() {
      final teamIndex = teams.indexWhere((team) => team.name == selectedTeam!.name);
      if (teamIndex != -1) {
        final updatedMembers = List<String>.from(teams[teamIndex].members)..add(name);
        teams[teamIndex] = Team(name: teams[teamIndex].name, members: updatedMembers);
        selectedTeam = teams[teamIndex];
        StorageService.saveTeams(teams);
      }
    });
    memberController.clear();
  }

  void _removeMember(int index) {
    if (selectedTeam == null) return;

    setState(() {
      final teamIndex = teams.indexWhere((team) => team.name == selectedTeam!.name);
      if (teamIndex != -1) {
        final updatedMembers = List<String>.from(teams[teamIndex].members)..removeAt(index);
        teams[teamIndex] = Team(name: teams[teamIndex].name, members: updatedMembers);
        selectedTeam = teams[teamIndex];
        StorageService.saveTeams(teams);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: teamNameController,
                    decoration: const InputDecoration(
                      labelText: 'Create New Team',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _createTeam,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _createTeam(teamNameController.text),
                  child: const Text('Create Team'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (teams.isNotEmpty) ...[
              DropdownButton<Team>(
                value: selectedTeam,
                hint: const Text('Select Team to Manage'),
                isExpanded: true,
                items: teams.map((Team team) {
                  return DropdownMenuItem<Team>(
                    value: team,
                    child: Text(team.name),
                  );
                }).toList(),
                onChanged: (Team? newValue) {
                  setState(() {
                    selectedTeam = newValue;
                  });
                },
              ),
            ],

            if (selectedTeam != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: memberController,
                      decoration: const InputDecoration(
                        labelText: 'Add Team Member',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _addMember,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _addMember(memberController.text),
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: selectedTeam!.members.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(selectedTeam!.members[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeMember(index),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 