enum ApiErrorType { noInternet, timeout, serverError, parseError }

class ApiException implements Exception {
  final ApiErrorType type;
  final String message;

  const ApiException({required this.type, required this.message});

  @override
  String toString() => 'ApiException(${type.name}): $message';

  String get userMessage {
    switch (type) {
      case ApiErrorType.noInternet:
        return 'Pas de connexion internet. Vérifie ton réseau.';
      case ApiErrorType.timeout:
        return 'Le serveur met trop de temps à répondre. Réessaie.';
      case ApiErrorType.serverError:
        return 'Erreur serveur. Réessaie plus tard.';
      case ApiErrorType.parseError:
        return 'Données reçues invalides. Réessaie plus tard.';
    }
  }
}
