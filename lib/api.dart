import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Your server (cPanel). The Gemini key stays there, never in the app.
const String apiUrl = 'https://labresultsreader.moezzadigital.com/api.php';

class ApiError implements Exception {
  ApiError(this.code, [this.detail = '']);
  final String code;
  final String detail;
}

const Map<String, String> errorCopy = {
  'busy': 'The AI service is busy right now. Please try again in a minute.',
  'rate_limited': 'Too many requests right now. Please wait a few minutes and try again.',
  'too_large': 'Those pages are too large to upload. Try fewer pages.',
  'invalid_json': "The explanation didn't come out right. Please try again.",
  'refused': "We couldn't explain these images. Try different photos.",
  'not_configured': "The app isn't set up yet (the server is missing its AI key).",
  'upstream_config': 'The AI service rejected the request. The app owner needs to check the server settings.',
  'network': "Couldn't reach the server. Check your internet connection and try again.",
  'timeout': 'The server took too long to answer. Please try again with fewer pages.',
  'empty': "The AI didn't return an answer. Please try again.",
  'limit_reached': "You've used all your free reports. Choose a plan or redeem a code to keep going.",
  'bad_code': "That code isn't valid.",
  'purchase_invalid': "We couldn't confirm this purchase with Google Play.",
  'signin_off': "Sign in with Google isn't available yet.",
  'signin_failed': "Google sign-in couldn't be confirmed. Please try again.",
  'signed_out': 'You were signed out. Please sign in again.',
};

String errorText(ApiError e) =>
    errorCopy[e.code] ?? 'Something went wrong. Please try again. (${e.code}${e.detail.isNotEmpty ? ': ${e.detail}' : ''})';

class Api {
  /// Anonymous id for this phone, so the server can count free reports (set at startup).
  static String device = '';

  /// Session token when signed in with Google ('' when signed out).
  static String auth = '';
  static http.Client? _client;
  static bool _cancelled = false;

  static void cancel() {
    _cancelled = true;
    _client?.close();
  }

  static Future<Map<String, dynamic>> post(Map<String, dynamic> body) async {
    _cancelled = false;
    final c = http.Client();
    _client = c;
    try {
      final res = await c
          .post(Uri.parse(apiUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'device': device, 'platform': 'android', if (auth.isNotEmpty) 'auth': auth, ...body}))
          .timeout(const Duration(seconds: 200));
      Map<String, dynamic>? data;
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {}
      if (res.statusCode >= 300 || data == null || data['error'] != null) {
        final err = data?['error'];
        String code;
        if (err is Map && err['code'] is String) {
          code = err['code'] as String;
        } else if (res.statusCode == 413) {
          code = 'too_large';
        } else if ([502, 503, 504, 520, 522, 524].contains(res.statusCode)) {
          code = 'timeout';
        } else {
          code = 'upstream_error';
        }
        throw ApiError(code, err is Map ? '${err['message'] ?? ''}' : 'HTTP ${res.statusCode}');
      }
      return data;
    } on ApiError {
      rethrow;
    } on TimeoutException {
      throw ApiError('timeout');
    } catch (e) {
      if (_cancelled) throw ApiError('cancelled');
      throw ApiError('network');
    } finally {
      c.close();
      if (identical(_client, c)) _client = null;
    }
  }
}
