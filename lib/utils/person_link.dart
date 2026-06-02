import '../models/person.dart';

String buildPersonLink(Person person) {
  return 'https://nastroi.app/person/${person.publicId}';
}

String? tryParsePublicIdFromRaw(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  try {
    final uri = Uri.parse(trimmed);

    if (uri.host == 'nastroi.app' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'person') {
      return uri.pathSegments[1];
    }

    if (uri.scheme == 'nastroi' &&
        uri.host == 'person' &&
        uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
  } catch (_) {}

  if (trimmed.startsWith('user_')) {
    return trimmed;
  }

  return null;
}

Person? tryParsePersonFromRaw(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  try {
    return Person.fromExportCode(trimmed);
  } catch (_) {}

  try {
    final uri = Uri.parse(trimmed);
    return tryParsePersonFromUri(uri);
  } catch (_) {
    return null;
  }
}

Person? tryParsePersonFromUri(Uri uri) {
  final data = uri.queryParameters['data'];
  if (data == null || data.isEmpty) return null;

  try {
    return Person.fromExportCode(data);
  } catch (_) {
    return null;
  }
}