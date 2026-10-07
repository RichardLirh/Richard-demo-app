import 'dart:convert';
import 'dart:io';

class DemoApi {
  DemoApi(this.endpoint, this.token);
  final String endpoint;
  final String token;

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('${endpoint.replaceAll(RegExp(r'/+$'), '')}$path');
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        final bytes = utf8.encode(jsonEncode(body));
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final text = await utf8.decoder.bind(response).join();
      dynamic data;
      try {
        data = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      } on FormatException {
        throw ApiException('服务返回了非 JSON 内容（HTTP ${response.statusCode}）');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = data is Map
            ? (data['detail'] ?? data['error'] ?? data['message'])
            : null;
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw ApiException('访问令牌无效，请在连接设置中更新。');
        }
        throw ApiException(
          detail?.toString() ?? '请求失败（HTTP ${response.statusCode}）',
        );
      }
      return data;
    } on SocketException {
      throw ApiException('暂时连接不到本机服务，请检查 USB 转发和服务地址。');
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> runs() async {
    final data = await request('/api/runs');
    return ((data is List ? data : data['runs']) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> run(String id) async =>
      _run(await request('/api/runs/${Uri.encodeComponent(id)}'));
  Future<Map<String, dynamic>> create(String prompt) async => _run(
    await request('/api/runs', method: 'POST', body: {'prompt': prompt}),
  );
  Future<List<Map<String, dynamic>>> events(String id) async {
    final data = await request('/api/runs/${Uri.encodeComponent(id)}/events');
    return ((data is List ? data : data['events']) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> approve(String id, dynamic version) async =>
      _run(
        await request(
          '/api/runs/${Uri.encodeComponent(id)}/approve',
          method: 'POST',
          body: {'approved': true, 'version': version},
        ),
      );
  Future<Map<String, dynamic>> cancel(String id) async => _run(
    await request(
      '/api/runs/${Uri.encodeComponent(id)}/cancel',
      method: 'POST',
      body: {},
    ),
  );
  Map<String, dynamic> _run(dynamic data) =>
      Map<String, dynamic>.from(data['run'] ?? data);
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
