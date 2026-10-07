import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:richard_demo_app/api.dart';

void main() {
  final tokenFile = Platform.environment['DEMO_LOCAL_TOKEN_FILE'];
  test(
    'native client creates, reads and cancels a local queued run',
    () async {
      final credentials = jsonDecode(await File(tokenFile!).readAsString());
      final api = DemoApi('http://127.0.0.1:8010', credentials['owner']);
      final run = await api.create('搜索关键词演示，起草跟进记录，等待人工审核。');
      final id = run['id'].toString();
      try {
        expect(
          run['status'],
          'queued',
          reason: 'This local smoke test requires the cloud worker to stay stopped.',
        );
        expect((await api.runs()).any((item) => item['id'] == id), isTrue);
        expect((await api.run(id))['id'], id);
        expect(await api.events(id), isNotEmpty);
      } finally {
        final cancelled = await api.cancel(id);
        expect(cancelled['status'], 'cancelled');
      }
    },
    skip: tokenFile == null
        ? 'Opt in with DEMO_LOCAL_TOKEN_FILE while worker is stopped.'
        : false,
  );
}
