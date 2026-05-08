import '../models/person.dart';

// Собираем человеко-понятную HTTPS-ссылку.
// Пока это ещё не universal link, а "веб-формат" ссылки,
// который можно пересылать и вставлять в импорт.
String buildPersonLink(Person person) {
  final uri = Uri(
    scheme: 'https',
    host: 'nastroi.app',
    path: '/person',
    queryParameters: {
      // Пока в ссылке всё ещё лежит exportCode.
      // Позже это можно будет заменить на реальный backend-id.
      'data': person.toExportCode(),
    },
  );

  return uri.toString();
}

// Универсальный парсер:
// - если пришёл raw export code -> тоже попробуем распарсить
// - если пришла deep link ссылка -> достанем query data
Person? tryParsePersonFromRaw(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // Сначала пробуем как обычный экспортный код.
  try {
    return Person.fromExportCode(trimmed);
  } catch (_) {
    // Идём дальше.
  }

  // Потом пробуем как ссылку.
  try {
    final uri = Uri.parse(trimmed);
    return tryParsePersonFromUri(uri);
  } catch (_) {
    return null;
  }
}

// Парсим человека из ссылки.
// Поддерживаем:
// - https://nastroi.app/person?data=...
// - старый кастомный формат, если он где-то ещё остался
Person? tryParsePersonFromUri(Uri uri) {
  final data = uri.queryParameters['data'];
  if (data == null || data.isEmpty) return null;

  try {
    return Person.fromExportCode(data);
  } catch (_) {
    return null;
  }
}