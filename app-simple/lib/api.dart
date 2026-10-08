import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Thin REST client for the Laravel simple API.
/// Base URL defaults to local docker API; override with --dart-define=API_URL=...
class ApiClient {
  ApiClient({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_URL',
            defaultValue: 'http://localhost:8000/api',
          );

  final String baseUrl;
  String? token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// Lightweight reachability check for the landing page.
  /// Returns true when the API answers /health.
  Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? city,
    String? trade,
  }) async {
    return _decode(
      http.post(
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
      ),
      201,
    );
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    return _decode(
      http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      ),
      200,
    );
  }

  Future<Map<String, dynamic>> me() async {
    return _decode(
      http.get(Uri.parse('$baseUrl/auth/me'), headers: _headers),
      200,
    );
  }

  Future<Map<String, dynamic>> posts({
    String? trade,
    String? q,
    bool mine = false,
  }) async {
    final uri = Uri.parse('$baseUrl/posts').replace(
      queryParameters: {
        if (trade != null && trade.isNotEmpty) 'trade': trade,
        if (q != null && q.isNotEmpty) 'q': q,
        if (mine) 'mine': '1',
      },
    );
    return _decode(http.get(uri, headers: _headers), 200);
  }

  Future<Map<String, dynamic>> postDetail(String id) async {
    return _decode(
      http.get(Uri.parse('$baseUrl/posts/$id'), headers: _headers),
      200,
    );
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    return _decode(
      http.post(
        Uri.parse('$baseUrl/posts'),
        headers: _headers,
        body: jsonEncode(data),
      ),
      201,
    );
  }

  Future<Map<String, dynamic>> toggleLike(String id) async {
    return _decode(
      http.post(Uri.parse('$baseUrl/posts/$id/like'), headers: _headers),
      200,
    );
  }

  Future<List<dynamic>> comments(String id) async {
    final req = http.get(
      Uri.parse('$baseUrl/posts/$id/comments'),
      headers: _headers,
    );
    final body = await _decode(req, 200);
    return (body['data'] as List?) ?? (body as List<dynamic>);
  }

  Future<Map<String, dynamic>> addComment(String id, String text) async {
    return _decode(
      http.post(
        Uri.parse('$baseUrl/posts/$id/comments'),
        headers: _headers,
        body: jsonEncode({'body': text}),
      ),
      201,
    );
  }

  Future<Map<String, dynamic>> jobs({
    String? trade,
    String? status,
    String? q,
    bool mine = false,
  }) async {
    final uri = Uri.parse('$baseUrl/jobs').replace(
      queryParameters: {
        if (trade != null && trade.isNotEmpty) 'trade': trade,
        if (status != null && status.isNotEmpty) 'status': status,
        if (q != null && q.isNotEmpty) 'q': q,
        if (mine) 'mine': '1',
      },
    );
    return _decode(http.get(uri, headers: _headers), 200);
  }

  Future<Map<String, dynamic>> createJob(Map<String, dynamic> data) async {
    return _decode(
      http.post(
        Uri.parse('$baseUrl/jobs'),
        headers: _headers,
        body: jsonEncode(data),
      ),
      201,
    );
  }

  Future<Map<String, dynamic>> jobAction(String id, String action) async {
    return _decode(
      http.post(Uri.parse('$baseUrl/jobs/$id/$action'), headers: _headers),
      200,
    );
  }

  Future<List<dynamic>> messages(String jobId, {String? after}) async {
    final uri = Uri.parse(
      '$baseUrl/jobs/$jobId/messages',
    ).replace(queryParameters: {if (after != null) 'after': after});
    final req = http.get(uri, headers: _headers);
    final body = await _decode(req, 200);
    return (body['data'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> sendMessage(String jobId, String text) async {
    return _decode(
      http.post(
        Uri.parse('$baseUrl/jobs/$jobId/messages'),
        headers: _headers,
        body: jsonEncode({'body': text}),
      ),
      201,
    );
  }

  Future<Map<String, dynamic>> jobShow(String id) async {
    return _decode(
      http.get(Uri.parse('$baseUrl/jobs/$id'), headers: _headers),
      200,
    );
  }

  // ---------- Marketplace+ ----------

  Map<String, dynamic>? _metaCache;

  Future<Map<String, dynamic>> meta() async {
    if (_metaCache != null) return _metaCache!;
    final body = await _decode(http.get(Uri.parse('$baseUrl/meta')), 200);
    _metaCache = body;
    return body;
  }

  /// Uploads an image file, returns the public URL.
  Future<String> uploadPhoto(String filePath, {String folder = 'posts'}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads'));
    req.headers.addAll(_headers);
    req.fields['folder'] = folder;
    req.files.add(await http.MultipartFile.fromPath('photo', filePath));
    http.StreamedResponse streamed;
    try {
      streamed = await req.send().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw ApiException('Upload timed out. Try a smaller photo.', 0);
    } catch (e) {
      throw ApiException('Upload failed: $e', 0);
    }
    final res = await http.Response.fromStream(streamed);
    final body = await _decode(Future.value(res), 201);
    final url = (body['url'] ?? '') as String;
    if (url.isEmpty) throw ApiException('Upload failed (no URL).', 0);
    return url;
  }

  Future<Map<String, dynamic>> craftsmanProfile(String userId) async {
    return _decode(
      http.get(Uri.parse('$baseUrl/craftsmen/$userId'), headers: _headers),
      200,
    );
  }

  Future<Map<String, dynamic>> createReview(
    String jobId,
    int rating,
    String? comment,
  ) async {
    return _decode(
      http.post(
        Uri.parse('$baseUrl/jobs/$jobId/reviews'),
        headers: _headers,
        body: jsonEncode({
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        }),
      ),
      201,
    );
  }

  Future<Map<String, dynamic>> notifications() async {
    return _decode(
      http.get(Uri.parse('$baseUrl/notifications'), headers: _headers),
      200,
    );
  }

  Future<Map<String, dynamic>> markNotificationsRead([List<String>? ids]) async {
    return _decode(
      http.post(
        Uri.parse('$baseUrl/notifications/read'),
        headers: _headers,
        body: jsonEncode({if (ids != null) 'ids': ids}),
      ),
      200,
    );
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return _decode(
      http.patch(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _headers,
        body: jsonEncode(data),
      ),
      200,
    );
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    return _decode(
      http.post(
        Uri.parse('$baseUrl/auth/forgot'),
        headers: _headers,
        body: jsonEncode({'email': email}),
      ),
      200,
    );
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String password,
  ) async {
    return _decode(
      http.post(
        Uri.parse('$baseUrl/auth/reset'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'code': code,
          'password': password,
          'password_confirmation': password,
        }),
      ),
      200,
    );
  }

  /// Every request goes through here: 15s timeout + network errors
  /// become ApiException with a human message instead of hanging forever.
  Future<http.Response> _req(Future<http.Response> future) async {
    try {
      return await future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException(
        'Server not reachable (timeout). Is the API running and the phone on the same Wi-Fi?',
        0,
      );
    } on SocketException catch (e) {
      throw ApiException('No connection to the server (${e.message}).', 0);
    } on HttpException catch (e) {
      throw ApiException('Connection failed (${e.message}).', 0);
    }
  }

  Future<Map<String, dynamic>> _decode(
    Future<http.Response> future,
    int expect,
  ) async {
    final res = await _req(future);
    dynamic body;
    try {
      body = res.body.isEmpty ? {} : jsonDecode(res.body);
    } catch (_) {
      body = {'raw': res.body};
    }
    if (res.statusCode != expect) {
      final msg = body is Map
          ? (body['message'] ??
                body['detail'] ??
                'Request failed (${res.statusCode})')
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
