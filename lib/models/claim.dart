class Candidate {
  final String name;
  final bool isTrue;

  Candidate({required this.name, required this.isTrue});
}

class Claim {
  final String claim;
  final String level;
  final List<Candidate> candidates;

  Claim({required this.claim, required this.level, required this.candidates});

  factory Claim.fromJson(Map<String, dynamic> json) {
    List<Candidate> candidates = [];
    for (int i = 1; i <= 10; i++) {
      final name = json['name$i'];
      final isTrue = json['isTrue$i'];

      if (name != null && name.toString().trim().isNotEmpty) {
        candidates.add(
          Candidate(
            name: name,
            isTrue: isTrue.toString().toLowerCase() == 'true',
          ),
        );
      }
    }
    final rawLevel = (json['level'] ?? '').toString().trim();
    final level = switch (rawLevel) {
      '1' => 'Amateur',
      '2' => 'Semi-Pro',
      '3' => 'Pro',
      '4' => 'International',
      '5' => 'Légende',
      _   => 'Légende',
    };
    return Claim(
      claim: json['claim'] ?? '',
      level: level,
      candidates: candidates,
    );
  }
}
