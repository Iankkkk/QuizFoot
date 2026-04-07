class Player {
  final String name;
  final String? name2;
  final String? name3;
  final String imageUrl;
  final int level;
  final List<String> categories;

  Player({
    required this.name,
    this.name2,
    this.name3,
    required this.imageUrl,
    required this.level,
    required this.categories,
  });

  /// Tous les noms acceptés pour ce joueur (name toujours présent, name2/name3 si non vides)
  List<String> get allNames => [
        name,
        if (name2 != null && name2!.trim().isNotEmpty) name2!,
        if (name3 != null && name3!.trim().isNotEmpty) name3!,
      ];

  factory Player.fromJson(Map<String, dynamic> json) {
    // Support both API format (category1-4) and cached format (categories list)
    final List<String> cats;
    if (json['categories'] is List) {
      cats = List<String>.from(json['categories']);
    } else {
      cats = [
        json['category1'],
        json['category2'],
        json['category3'],
        json['category4'],
      ].whereType<String>().where((e) => e.trim().isNotEmpty).toList();
    }
    return Player(
      name: json['name'] as String? ?? '',
      name2: json['name2'] as String?,
      name3: json['name3'] as String?,
      imageUrl: json['imageUrl'] as String? ?? '',
      level: int.tryParse(json['level']?.toString() ?? '') ?? 1,
      categories: cats,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (name2 != null) 'name2': name2,
        if (name3 != null) 'name3': name3,
        'imageUrl': imageUrl,
        'level': level,
        'categories': categories,
      };

  bool get isValid => imageUrl.isNotEmpty;
}
