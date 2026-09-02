import 'dart:convert';

import 'package:http/http.dart' as http;

/// Shared decoding helpers for the thin vehicle-service HTTP wrappers.
///
/// The backend returns page envelopes shaped `{ "items": [...] }` but older
/// / adjacent endpoints have used `content` / `data`; every list reader in
/// this app tolerates all three, so that logic lives here once.
class ApiResponse {
  const ApiResponse._();

  /// Throws [ApiException] when [response] is not 2xx.
  static void ensureOk(http.Response response, String what) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(what, response.statusCode, response.body);
    }
  }

  /// Decodes a list body, unwrapping a page envelope if present.
  static List<Map<String, dynamic>> items(String body) {
    if (body.trim().isEmpty) return const [];
    final decoded = jsonDecode(body);
    final raw = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
            ? decoded['items'] ?? decoded['content'] ?? decoded['data']
            : null;
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Decodes a single-object body, unwrapping `{ "<key>": {...} }` if [key]
  /// is given and present.
  static Map<String, dynamic> object(String body, {String? key}) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    if (key != null && decoded[key] is Map<String, dynamic>) {
      return decoded[key] as Map<String, dynamic>;
    }
    return decoded;
  }
}

/// A non-2xx response from the vehicle service.
class ApiException implements Exception {
  const ApiException(this.what, this.statusCode, [this.body = '']);

  final String what;
  final int statusCode;
  final String body;

  @override
  String toString() => '$what failed: HTTP $statusCode';
}
