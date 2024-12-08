class Team {
  final String name;
  final List<String> members;

  Team({required this.name, required this.members});

  Map<String, dynamic> toJson() => {
    'name': name,
    'members': members,
  };

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      name: json['name'] as String,
      members: List<String>.from(json['members']),
    );
  }
} 