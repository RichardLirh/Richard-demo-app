import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richard_demo_app/api.dart';
import 'package:richard_demo_app/mail_drafts.dart';

class FakeDraftApi extends DemoApi {
  FakeDraftApi() : super('http://unused', 'test');
  int saves = 0, sends = 0;
  @override
  Future<Map<String, dynamic>> saveMailDraft(
    String subject,
    String body, {
    String? id,
    int? version,
  }) async {
    saves++;
    return {
      'draft_id': 'draft-one',
      'subject': subject,
      'body': body,
      'version': 1,
      'content_hash': 'hash-one',
      'state': 'draft',
    };
  }

  @override
  Future<Map<String, dynamic>> confirmMailDraft(
    String id,
    int version,
    String hash,
  ) async {
    expect(id, 'draft-one');
    expect(version, 1);
    expect(hash, 'hash-one');
    sends++;
    return {'id': 'run-one', 'mode': 'send_only'};
  }
}

void main() {
  testWidgets(
    'saving and reviewing do not dispatch; separate confirmation dispatches once',
    (tester) async {
      final api = FakeDraftApi();
      int opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MailDraftEditor(
            api: api,
            openRun: (_) async {
              opened++;
            },
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('mailSubject')), '测试邮件');
      await tester.enterText(find.byKey(const Key('mailBody')), '这是口述后核对的正文。');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('saveMailDraft')));
      await tester.tap(find.byKey(const Key('saveMailDraft')));
      await tester.pumpAndSettle();
      expect(api.saves, 1);
      expect(api.sends, 0);
      await tester.ensureVisible(find.byKey(const Key('reviewMailDraft')));
      await tester.tap(find.byKey(const Key('reviewMailDraft')));
      await tester.pumpAndSettle();
      expect(find.textContaining('这是口述后核对的正文。'), findsWidgets);
      expect(api.sends, 0);
      await tester.tap(find.byKey(const Key('confirmMailSend')));
      await tester.pumpAndSettle();
      expect(api.sends, 1);
      expect(opened, 1);
      expect(find.byKey(const Key('reviewMailDraft')), findsNothing);
    },
  );

  testWidgets(
    'editing invalidates the displayed confirmation until saved again',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MailDraftEditor(
            api: FakeDraftApi(),
            initial: {
              'draft_id': 'draft-one',
              'subject': '主题',
              'body': '旧正文',
              'version': 1,
              'content_hash': 'hash-one',
              'state': 'draft',
            },
            openRun: (_) async {},
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('mailBody')), '新正文');
      await tester.pump();
      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('reviewMailDraft')),
      );
      expect(button.onPressed, isNull);
    },
  );
}
