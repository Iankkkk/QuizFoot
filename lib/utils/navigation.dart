import 'package:flutter/material.dart';

/// Crée une route nommée automatiquement d'après le type du widget.
/// Ex: QuiAMentiGame → "qui_a_menti_game" dans Firebase Analytics.
Route<T> namedRoute<T>(Widget page) {
  final name = page.runtimeType.toString()
      .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => '_')
      .toLowerCase();
  return MaterialPageRoute<T>(
    builder: (_) => page,
    settings: RouteSettings(name: name),
  );
}
