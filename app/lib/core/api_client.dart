import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? const String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000'),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final resp = await _client.post(uri, headers: headers, body: jsonEncode(body));
    return _decode(resp);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query, String? token}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final resp = await _client.get(uri, headers: headers);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final resp = await _client.patch(uri, headers: headers, body: jsonEncode(body));
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final body = resp.body.isEmpty ? '{}' : resp.body;
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      if (resp.statusCode >= 400) throw ApiException(resp.statusCode, decoded);
      return decoded;
    }
    if (resp.statusCode >= 400) throw ApiException(resp.statusCode, {'detail': body});
    return {'data': decoded};
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final Map<String, dynamic> body;
  @override
  String toString() => 'ApiException $statusCode $body';
}
