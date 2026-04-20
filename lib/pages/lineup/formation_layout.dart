// formation_layout.dart
//
// Supported formations and player-to-slot assignment algorithm.
// If a match's formation isn't in [kFormationLines], the app falls back
// to the classic list view (tabs).

import 'package:flutter/material.dart';
import '../../models/lineup_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Formation definitions
// Each entry: list of lines from GK outward, left → right visually.
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, List<List<String>>> kFormationLines = {
  '4-4-2': [
    ['GB'],
    ['DG', 'DC', 'DC', 'DD'],
    ['MG', 'MC', 'MC', 'MD'],
    ['BU', 'BU'],
  ],
  '4-3-3': [
    ['GB'],
    ['DG', 'DC', 'DC', 'DD'],
    ['MC', 'MC', 'MC'],
    ['AG', 'BU', 'AD'],
  ],
  '4-2-3-1': [
    ['GB'],
    ['DG', 'DC', 'DC', 'DD'],
    ['MC', 'MC'],
    ['MG', 'MOC', 'MD'],
    ['BU'],
  ],
  '3-5-2': [
    ['GB'],
    ['DC', 'DC', 'DC'],
    ['MG', 'MC', 'MC', 'MC', 'MD'],
    ['BU', 'BU'],
  ],
  '4-1-2-1-2': [
    ['GB'],
    ['DG', 'DC', 'DC', 'DD'],
    ['MDC'],
    ['MC', 'MC'],
    ['MOC'],
    ['BU', 'BU'],
  ],
  '3-2-4-1': [
    ['GB'],
    ['DC', 'DC', 'DC'],
    ['MDC', 'MDC'],
    ['MG', 'MOC', 'MOC', 'MD'],
    ['BU'],
  ],
};

bool isFormationSupported(String f) => kFormationLines.containsKey(f);

// ─────────────────────────────────────────────────────────────────────────────
// Slot assignment
// ─────────────────────────────────────────────────────────────────────────────

/// Assigns [starters] to slots defined by [formation].
/// Returns a flat list (line by line, left→right) of Lineup? (null = unmatched slot).
List<Lineup?> assignPlayersToSlots(List<Lineup> starters, String formation) {
  final lines = kFormationLines[formation];
  if (lines == null) return [];

  final pool = List<Lineup>.from(starters);
  final result = <Lineup?>[];

  // First pass: exact position-code match
  for (final line in lines) {
    for (final code in line) {
      final idx = pool.indexWhere((p) => p.position == code);
      if (idx != -1) {
        result.add(pool.removeAt(idx));
      } else {
        result.add(null);
      }
    }
  }

  // Second pass: fill remaining nulls with leftover starters (fallback)
  int poolIdx = 0;
  for (int i = 0; i < result.length; i++) {
    if (result[i] == null && poolIdx < pool.length) {
      result[i] = pool[poolIdx++];
    }
  }

  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot positioning
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the (x, y) fractions [0..1] for a given slot.
///
/// Home team: GK at bottom (y≈0.93), attackers toward center (y≈0.56).
/// Away team: mirror on both axes — GK at top (y≈0.07), attackers toward y≈0.44.
/// X is mirrored for the away team so that DG/DD (defined left→right from the
/// team's own perspective) stay consistent with the player's point of view
/// when the team is flipped at the top of the pitch.
Offset slotFraction({
  required int lineIndex,
  required int slotIndex,
  required int totalSlotsInLine,
  required int totalLines,
  required bool isHomeTeam,
}) {
  final double xRaw = (slotIndex + 1) / (totalSlotsInLine + 1);
  final double x = isHomeTeam ? xRaw : 1.0 - xRaw;

  const double gkY = 0.93; // GK side
  const double attackY = 0.56; // nearest to center line
  final double range = gkY - attackY;
  final double step = totalLines > 1 ? range / (totalLines - 1) : 0.0;

  final double yHome = gkY - lineIndex * step;
  final double y = isHomeTeam ? yHome : 1.0 - yHome;

  return Offset(x, y);
}
