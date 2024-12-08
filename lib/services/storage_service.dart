import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/team.dart';

class StorageService {
  static const String _teamsKey = 'teams';

  static Future<List<Team>> loadTeams() async {
    final prefs = await SharedPreferences.getInstance();
    final teamsJson = prefs.getString(_teamsKey);
    if (teamsJson != null) {
      final List<dynamic> decodedTeams = jsonDecode(teamsJson);
      return decodedTeams
          .map((team) => Team.fromJson(team as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  static Future<void> saveTeams(List<Team> teams) async {
    final prefs = await SharedPreferences.getInstance();
    final teamsJson = jsonEncode(teams.map((team) => team.toJson()).toList());
    await prefs.setString(_teamsKey, teamsJson);
  }
} 