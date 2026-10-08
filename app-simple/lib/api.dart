import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin REST client for the Laravel simple API.
/// Base URL defaults to local docker API; override with --dart-define=API_URL=...
class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment('API_URL',
                defaultValue: 'http://localhost:8000/api');

  final String baseUrl;
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? city,
    String? trade,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        'role': role,
        if (city != null) 'city': city,
        if (trade != null) 'trade': trade,
      }),
    );
    return _decode(res, 201);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(res, 200);
  }

  Future<Map<String, dynamic>> me() async {
    final res =
        await http.get(Uri.parse('$baseUrl/auth/me'), headers: _headers);
    return _decode(res, 200);
  }

  Future<Map<String, dynamic>> posts({String? trade, String? q}) async {
    final uri = Uri.parse('$baseUrl/posts').replace(queryParameters: {
      if (trade != null && trade.isNotEmpty) 'trade': trade,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    final res = await http.get(uri, headers: _headers);
    return _decode(res, 200);
  }

  Future<Map<String, dynamic>> postDetail(int id) async {
    final res =
        await http.get(Uri.parse('$baseUrl/posts/$id'), headers: _headers);
    return _decode(res, 200);
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/posts'),
        headers: _headers, body: jsonEncode(data));
    return _decode(res, 201);
  }

  Future<Map<String, dynamic>> toggleLike(int id) async {
    final res = await http.post(Uri.parse('$baseUrl/posts/$id/like'),
        headers: _headers);
    return _decode(res, 200);
  }

  Future<List<dynamic>> comments(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/posts/$id/comments'),
        headers: _headers);
    final body = _decode(res, 200);
    return (body['data'] as List?) ?? (body as List<dynamic>);
  }

  Future<Map<String, dynamic>> addComment(int id, String text) async {
    final res = await http.post(Uri.parse('$baseUrl/posts/$id/comments'),
        headers: _headers, body: jsonEncode({'body': text}));
    return _decode(res, 201);
  }

  Future<Map<String, dynamic>> jobs(
      {String? trade, String? status, String? q, bool mine = false}) async {
    final uri = Uri.parse('$baseUrl/jobs').replace(queryParameters: {
      if (trade != null && trade.isNotEmpty) 'trade': trade,
      if (status != null && status.isNotEmpty) 'status': status,
      if (q != null && q.isNotEmpty) 'q': q,
      if (mine) 'mine': '1',
    });
    final res = await http.get(uri, headers: _headers);
    return _decode(res, 200);
  }

  Future<Map<String, dynamic>> createJob(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/jobs'),
        headers: _headers, body: jsonEncode(data));
    return _decode(res, 201);
  }

  Future<Map<String, dynamic>> jobAction(int id, String action) async {
    final res = await http.post(Uri.parse('$baseUrl/jobs/$id/$action'),
        headers: _headers);
    return _decode(res, 200);
  }

  Future<List<dynamic>> messages(int jobId, {int? afterId}) async {
    final uri = Uri.parse('$baseUrl/jobs/$jobId/messages')
        .replace(queryParameters: {if (afterId != null) 'after_id': '$afterId'});
    final res = await http.get(uri, headers: _headers);
    final body = _decode(res, 200);
    return (body['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> sendMessage(int jobId, String text) async {
    final res = await http.post(Uri.parse('$baseUrl/jobs/$jobId/messages'),
        headers: _headers, body: jsonEncode({'body': text}));
    return _decode(res, 201);
  }

  Future<Map<String, dynamic>> jobShow(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/jobs/$id'), headers: _headers);
    return _decode(res, 200);
  }

  Map<String, dynamic> _decode(http.Response res, int expect) {
    dynamic body;
    try {
      body = res.body.isEmpty ? {} : jsonDecode(res.body);
    } catch (_) {
      body = {'raw': res.body};
    }
    if (res.statusCode != expect) {
      final msg = body is Map
          ? (body['message'] ?? body['detail'] ?? 'Request failed (${res.statusCode})')
          : 'Request failed (${res.statusCode})';
      throw ApiException(msg.toString(), res.statusCode);
    }
    return body is Map<String, dynamic> ? body : {'data': body};
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}
