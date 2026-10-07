import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:richard_demo_app/api.dart';

void main() {
  test('approval sends the reviewed version and owner authorization', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestSeen = server.first;
    final response = DemoApi(
      'http://127.0.0.1:${server.port}',
      'test-owner-token',
    ).approve('run one', 7);
    final request = await requestSeen;
    expect(request.method, 'POST');
    expect(Uri.decodeComponent(request.uri.path), '/api/runs/run one/approve');
    expect(
      request.headers.value(HttpHeaders.authorizationHeader),
      'Bearer test-owner-token',
    );
    expect(jsonDecode(await utf8.decoder.bind(request).join()), {
      'approved': true,
      'version': 7,
    });
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'id': 'run one', 'status': 'running'}));
    await request.response.close();
    expect((await response)['status'], 'running');
  });

  test(
    'stale approval conflict is shown without marking task complete',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requestSeen = server.first;
      final response = DemoApi(
        'http://127.0.0.1:${server.port}',
        'token',
      ).approve('run-1', 1);
      final expectation = expectLater(
        response,
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', '草稿已更新'),
        ),
      );
      final request = await requestSeen;
      await request.drain<void>();
      request.response.statusCode = 409;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': '草稿已更新'}));
      await request.response.close();
      await expectation;
    },
  );
}
