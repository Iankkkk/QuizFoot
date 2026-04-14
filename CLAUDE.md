# QuizFoot — CLAUDE.md

Flutter football quiz app (web + mobile). Data from SheetDB (Google Sheets).

---

## Structure

```
lib/
  main.dart
  constants/app_colors.dart
  models/
    match_model.dart       # Match (matchId, homeTeam, awayTeam, formationHome, formationAway, colorHome, colorHome2, colorAway, colorAway2, level)
    lineup_model.dart      # Lineup (matchId, playerName, position, isStarter, number, team)
    player.dart            # Player (quiz général)
    player_career.dart
    claim.dart
  data/
    lineup_game_data.dart  # loadMatches(), loadLineups(matchId)
    players_data.dart
    players_career_data.dart
    qui_a_menti_api.dart
    anecdotes_data.dart
    difficulty_plans.dart
    data_cache.dart        # Singleton cache TTL 30min pour tous les appels API
    api_exception.dart     # ApiException(type: ApiErrorType, message)
  pages/
    home_page.dart
    history_page.dart
    result_page.dart
    formation_preview_page.dart
    parcours_joueur_page.dart
    lineup/
      lineup_match_page_intro.dart   # Intro + sélection difficulté
      lineup_match_page.dart         # Page de jeu principale (Compos)
      lineup_score_page.dart         # Page de score finale
      formation_layout.dart          # Formations supportées + algorithme de placement
    coup_doeil/
      quiz_test_intro.dart
      quiz_test.dart
      quiz_score_page.dart
    qui_a_menti/
      qui_a_menti_intro.dart
      qui_a_menti_game.dart
      qui_a_menti_score.dart
      qui_a_menti_confetti.dart
```

---

## Jeu "Compos" (lineup/)

**Règles :**
- Trouver les joueurs (titulaires + remplaçants) d'un match célèbre
- Taper le nom de famille
- 6 erreurs max
- Indice (numéros) coûte 3 points, score peut être négatif
- 1 pt par joueur trouvé

**Modes de difficulté :** Très Facile / Facile / Moyenne / Difficile / Impossible / Test  
→ "Test" : filtre uniquement les matchs avec les deux formations dans `kFormationLines`

**Pitch view vs liste :**
- `_isPitchMode` = true si les deux formations du match sont dans `kFormationLines`
- Sinon : fallback tabs classiques (Domicile / Extérieur)

**Layout pitch :**
- Home : GK en bas (y=0.93), attaque vers centre (y=0.56)
- Away : miroir (GK y=0.07, attaque y=0.44)
- `slotFraction()` → coordonnées (x, y) en fractions [0..1]
- `assignPlayersToSlots()` : match exact sur `position` code, puis fallback sur les restants

**Couleurs équipes :**
- Wording français dans Sheet : "Blanc", "Noir", "Rouge", "Bleu", "Bleu clair", "Bleu foncé", "Vert", "Jaune"
- Parsé par `_parseTeamColor()` / `_parseTeamColor2()`
- Si 2 couleurs : split vertical dur (LinearGradient stops [0,0.5,0.5,1])
- Chip vide quand joueur non trouvé, rempli avec couleur(s) quand trouvé
- Animation bounce sur découverte (TweenSequence scale 1→1.4→0.9→1, 400ms)

---

## Formations supportées (`formation_layout.dart`)

```
4-4-2 / 4-3-3 / 4-2-3-1 / 3-5-2 / 4-1-2-1-2 / 3-2-4-1
```

Codes de position utilisés : `GB`, `DG`, `DC`, `DD`, `MG`, `MC`, `MD`, `MDC`, `MOC`, `MG`, `MD`, `AG`, `AD`, `BU`

---

## API / Data

- **SheetDB** : `https://sheetdb.io/api/v1/awu5uvi0qdn9s`
  - `?sheet=Matches` → liste des matchs
  - `?sheet=Lineups` → tous les lineups
- Cache TTL 30min via `DataCache.instance`
- Erreurs typées : `ApiErrorType.noInternet / timeout / serverError / parseError`

---

## Conventions

- Diffs affichés après chaque modif
- Commits en anglais
- Pas de refactor au-delà de ce qui est demandé
- Pas de commentaires sauf si logique non évidente
