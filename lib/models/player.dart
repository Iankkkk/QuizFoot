class Player {
  final String name;
  final String imageUrl;
  final int level;
  final List<String> categories;

  Player({
    required this.name,
    required this.imageUrl,
    required this.level,
    required this.categories,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      level: int.tryParse(json['level']?.toString() ?? '') ?? 1,
      categories: [
        json['category1'],
        json['category2'],
        json['category3'],
        json['category4'],
      ].whereType<String>().where((e) => e.isNotEmpty).toList(),
    );
  }

  bool get isValid => imageUrl.isNotEmpty;
}
