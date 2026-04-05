import '../models/player.dart';
import '../models/match_model.dart';
import '../models/lineup_model.dart';
import '../models/player_career.dart';
import '../models/claim.dart';

/// Cache in-memory avec TTL de 30 minutes.
/// Singleton : même instance pour toute la session.
class DataCache {
  DataCache._();
  static final DataCache instance = DataCache._();

  static const _ttl = Duration(minutes: 30);

  List<Player>? _players;
  DateTime? _playersExpiry;

  List<Match>? _matches;
  DateTime? _matchesExpiry;

  List<Lineup>? _lineups;
  DateTime? _lineupsExpiry;

  List<PlayerCareer>? _careerPlayers;
  DateTime? _careerPlayersExpiry;

  List<Claim>? _claims;
  DateTime? _claimsExpiry;

  bool _valid(DateTime? expiry) =>
      expiry != null && DateTime.now().isBefore(expiry);

  List<Player>? get players => _valid(_playersExpiry) ? _players : null;
  void setPlayers(List<Player> data) {
    _players = data;
    _playersExpiry = DateTime.now().add(_ttl);
  }

  List<Match>? get matches => _valid(_matchesExpiry) ? _matches : null;
  void setMatches(List<Match> data) {
    _matches = data;
    _matchesExpiry = DateTime.now().add(_ttl);
  }

  List<Lineup>? get lineups => _valid(_lineupsExpiry) ? _lineups : null;
  void setLineups(List<Lineup> data) {
    _lineups = data;
    _lineupsExpiry = DateTime.now().add(_ttl);
  }

  List<PlayerCareer>? get careerPlayers =>
      _valid(_careerPlayersExpiry) ? _careerPlayers : null;
  void setCareerPlayers(List<PlayerCareer> data) {
    _careerPlayers = data;
    _careerPlayersExpiry = DateTime.now().add(_ttl);
  }

  List<Claim>? get claims => _valid(_claimsExpiry) ? _claims : null;
  void setClaims(List<Claim> data) {
    _claims = data;
    _claimsExpiry = DateTime.now().add(_ttl);
  }

  void invalidateAll() {
    _players = null; _playersExpiry = null;
    _matches = null; _matchesExpiry = null;
    _lineups = null; _lineupsExpiry = null;
    _careerPlayers = null; _careerPlayersExpiry = null;
    _claims = null; _claimsExpiry = null;
  }
}
