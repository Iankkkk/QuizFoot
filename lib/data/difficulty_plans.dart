// difficulty_plans.dart
//
// Defines how many players of each level are selected for each difficulty.
//
// Structure: Map<difficultyLabel, List<steps>>
//   Each step is a Map<playerLevel, count>.
//   The total number of players across all steps always equals 10 (one quiz = 10 questions).
//
// Player levels go from 1 (very famous) to 10 (very obscure).

/// Difficulty plans for the Coup d'œil game.
///
/// Example for "Pro": pick 3 players at level 3, 3 at level 4, 4 at level 5.
const Map<String, List<Map<int, int>>> kDifficultyPlans = {
  'Amateur': [
    {1: 8}, // 8 very famous players
    {2: 2}, // 2 well-known players
  ],
  'Semi-Pro': [
    {1: 1},
    {2: 5},
    {3: 3},
    {4: 1},
  ],
  'Pro': [
    {3: 3},
    {4: 3},
    {5: 4},
  ],
  'International': [
    {4: 1},
    {5: 3},
    {6: 3},
    {7: 2},
    {8: 1},
  ],
  'Légende': [
    {8: 2},
    {9: 4},
    {10: 4}, // 4 very obscure players
  ],
};
