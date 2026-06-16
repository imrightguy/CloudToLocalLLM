/// Centralized defensive JSON parsing helpers.
///
/// These functions never throw on unexpected types. They exist to prevent the
/// "Erreur de connexion" class of bugs where the API responds 200 but a single
/// non-defensive cast in a `fromJson` (a field arriving as Map instead of List,
/// int instead of String, or null) crashes the whole screen.
///
/// Rule: prefer these over raw `as`/`DateTime.parse` casts in every `fromJson`.
library;

/// Safe string list parser.
/// Handles List (maps each element to its String form), Map / null / other
/// types (returns an empty list). Never throws.
List<String> parseStringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  return <String>[];
}

/// Safe nullable DateTime parser.
/// Handles DateTime, String, null, and other types (best-effort via toString()).
/// Returns null instead of throwing when parsing fails.
DateTime? parseNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

/// Safe nullable int parser.
/// Handles num, null, and numeric strings. Returns null on failure.
int? parseNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// Safe nullable double parser.
/// Handles num, null, and numeric strings. Returns null on failure.
double? parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Safe nullable bool parser.
/// Handles bool, null, and the common string/number encodings
/// ("true"/"false", "1"/"0"). Returns null when it cannot decide.
bool? parseNullableBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return null;
}

/// Safe nullable String parser.
/// Returns null for null, otherwise the value's String form. Never throws.
String? parseNullableString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

/// Safe Map parser.
/// Returns the value as `Map<String, dynamic>` when it is a Map, otherwise null.
/// Never throws on a type mismatch.
Map<String, dynamic>? parseNullableMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return null;
}

/// Safe list-of-objects parser.
/// Maps each Map element through [fromJson]; skips non-Map elements.
/// Returns an empty list for null / non-List / Map inputs. Never throws.
List<T> parseObjectList<T>(
  dynamic value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! List) return <T>[];
  final result = <T>[];
  for (final e in value) {
    final map = parseNullableMap(e);
    if (map != null) result.add(fromJson(map));
  }
  return result;
}
