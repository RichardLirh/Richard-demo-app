import 'package:flutter_test/flutter_test.dart';
import 'package:richard_demo_app/mail_report.dart';

void main() {
  test('cancellation preserves uncertain external effects', () {
    final text = mailReportLines({
      'cancelled': true,
      'send_state': 'submitting',
    }).join('\n');
    expect(text, contains('尚未确认'));
    expect(text, isNot(contains('尚未开始发送')));
  });
  test('verified receipt survives cancellation while scan stays partial', () {
    final text = mailReportLines({
      'cancelled': true,
      'sent_receipt': {'verified': true, 'recipient': 'me@163.com'},
      'scan_coverage': {'complete': false, 'messages_read': 3},
    }).join('\n');
    expect(text, contains('已确认发送'));
    expect(text, contains('扫描尚未完成'));
    expect(text, contains('3 封'));
  });
}
