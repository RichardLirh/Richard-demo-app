import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:richard_demo_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('owner creates a task, sees its events and cancels it', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createTask')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submitTask')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 20 && find.text('任务进展').evaluate().isEmpty; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    expect(find.text('任务进展'), findsOneWidget);
    expect(find.text('执行记录'), findsOneWidget);
    await tester.tap(find.text('取消任务').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '取消任务'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 30 && find.text('已取消').evaluate().isEmpty; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    expect(find.text('已取消'), findsOneWidget);
  });
}
