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
      imageUrl: json['imageUrl'] as String? ?? '',
      level: int.tryParse(json['level']?.toString() ?? '') ?? 1,
      categories: cats,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'imageUrl': imageUrl,
        'level': level,
        'categories': categories,
      };

  bool get isValid => imageUrl.isNotEmpty;
}
