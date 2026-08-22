/// Defensive JSON accessors used throughout the model layer so that malformed
/// upstream payloads never crash the app.
String? asString(Map<dynamic, dynamic> m, String key) {
  final v = m[key];
  return v is String ? v : null;
}

int? asInt(Map<dynamic, dynamic> m, String key) {
  final v = m[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

double? asDouble(Map<dynamic, dynamic> m, String key) {
  final v = m[key];
  if (v is num) return v.toDouble();
  return null;
}

bool asBool(Map<dynamic, dynamic> m, String key, [bool fallback = false]) {
  final v = m[key];
  if (v is bool) return v;
  return fallback;
}

List<dynamic> asList(Map<dynamic, dynamic> m, String key) {
  final v = m[key];
  return v is List ? v : const [];
}

Map<String, dynamic> asMap(Map<dynamic, dynamic> m, String key) {
  final v = m[key];
  if (v is Map) return Map<String, dynamic>.from(v);
  return const {};
}

List<Map<String, dynamic>> asMapList(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}
