class GeminiException implements Exception {
  GeminiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class GeminiNotConfiguredException extends GeminiException {
  GeminiNotConfiguredException()
      : super(
          'La génération intelligente n’est pas encore activée sur cet appareil.',
          code: 'not_configured',
        );
}

class GeminiNetworkException extends GeminiException {
  GeminiNetworkException([String? detail])
      : super(
          detail == null || detail.isEmpty
              ? 'Impossible de joindre le service Gemini (réseau).'
              : 'Impossible de joindre le service Gemini : $detail',
          code: 'network',
        );
}

class GeminiQuotaException extends GeminiException {
  GeminiQuotaException()
      : super('Quota Gemini dépassé. Réessayez plus tard.', code: 'quota');
}

class GeminiTimeoutException extends GeminiException {
  GeminiTimeoutException()
      : super('Délai dépassé lors de l’appel Gemini.', code: 'timeout');
}

class GeminiInvalidJsonException extends GeminiException {
  GeminiInvalidJsonException([String? detail])
      : super(
          detail == null || detail.isEmpty
              ? 'Réponse Gemini JSON invalide ou incomplète.'
              : 'Réponse Gemini JSON invalide : $detail',
          code: 'invalid_json',
        );
}

class GeminiUnavailableException extends GeminiException {
  GeminiUnavailableException([String? detail])
      : super(
          detail == null || detail.isEmpty
              ? 'Service Gemini indisponible.'
              : 'Service Gemini indisponible : $detail',
          code: 'unavailable',
        );
}
