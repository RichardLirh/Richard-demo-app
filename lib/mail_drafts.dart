import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';

String mailDraftId(Map draft) => (draft['draft_id'] ?? draft['id']).toString();
typedef OpenMailRun = Future<void> Function(Map<String, dynamic> run);

class MailDraftInbox extends StatefulWidget {
  const MailDraftInbox({super.key, required this.api, required this.openRun});
  final DemoApi api;
  final OpenMailRun openRun;
  @override
  State<MailDraftInbox> createState() => _MailDraftInboxState();
}

class _MailDraftInboxState extends State<MailDraftInbox> {
  List<Map<String, dynamic>> drafts = [];
  String? error;
  bool fetching = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (fetching) return;
    fetching = true;
    try {
      final value = await widget.api.mailDrafts();
      if (mounted) {
        setState(() {
          drafts = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      fetching = false;
    }
  }

  Future<void> open([Map<String, dynamic>? draft]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MailDraftEditor(
          api: widget.api,
          initial: draft,
          openRun: widget.openRun,
        ),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('邮件草稿'),
      actions: [
        IconButton(
          onPressed: refresh,
          tooltip: '刷新',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => open(),
      icon: const Icon(Icons.edit),
      label: const Text('新草稿'),
    ),
    body: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          const Text('对小智口述主题和正文，草稿会出现在这里。\n确认后只向本人发信，不扫描邮箱。'),
          const SizedBox(height: 20),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (drafts.isEmpty && error == null)
            const Text('还没有草稿。也可以点击“新草稿”输入内容。'),
          for (final draft in drafts)
            Card(
              child: ListTile(
                title: Text(draft['subject']?.toString() ?? '未命名邮件'),
                subtitle: Text('${draftState(draft)} · 版本 ${draft['version']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(draft),
              ),
            ),
        ],
      ),
    ),
  );
}

String draftState(Map draft) {
  if (draft['run_id'] != null) return '已确认，查看任务';
  return const {
        'draft': '待复核',
        'readback': '正在复述',
        'awaiting_confirmation': '待确认',
        'cancelled': '已取消',
        'expired': '确认已过期',
        'queued': '已派发',
        'confirmed': '已确认',
      }[draft['state']] ??
      '待复核';
}

class MailDraftEditor extends StatefulWidget {
  const MailDraftEditor({
    super.key,
    required this.api,
    required this.openRun,
    this.initial,
  });
  final DemoApi api;
  final OpenMailRun openRun;
  final Map<String, dynamic>? initial;
  @override
  State<MailDraftEditor> createState() => _MailDraftEditorState();
}

class _MailDraftEditorState extends State<MailDraftEditor> {
  final subject = TextEditingController();
  final body = TextEditingController();
  Map<String, dynamic>? draft;
  bool busy = false, dirty = false;
  String? error;
  @override
  void initState() {
    super.initState();
    apply(widget.initial);
  }

  void apply(Map<String, dynamic>? value) {
    draft = value;
    subject.text = value?['subject']?.toString() ?? '';
    body.text = value?['body']?.toString() ?? '';
    dirty = false;
  }

  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> act(Future<void> Function() fn) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => error = '$e\n如草稿已变化，请返回列表重新核对，不能沿用旧确认。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() => act(() async {
    final value = await widget.api.saveMailDraft(
      subject.text,
      body.text,
      id: draft == null ? null : mailDraftId(draft!),
      version: draft?['version'] as int?,
    );
    if (mounted) setState(() => apply(value));
  });
  Future<void> confirm() async {
    if (draft == null || dirty || busy) return;
    // Keep the reviewed snapshot even if another client edits while the dialog is open.
    final reviewed = Map<String, dynamic>.from(draft!);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认发送给自己？'),
        content: SingleChildScrollView(
          child: Text(
            '收件人：当前本人登录的 163 账号\n\n主题：${reviewed['subject']}\n\n${reviewed['body']}\n\n确认后启动云端任务；如需登录，请在任务页完成。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续修改'),
          ),
          FilledButton(
            key: const Key('confirmMailSend'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认发送'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await act(() async {
      final run = await widget.api.confirmMailDraft(
        mailDraftId(reviewed),
        reviewed['version'] as int,
        reviewed['content_hash'] as String,
      );
      if (!mounted) return;
      setState(
        () => draft = {...reviewed, 'run_id': run['id'], 'state': 'queued'},
      );
      await widget.openRun(run);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasRun = draft?['run_id'] != null;
    final cancelled = draft?['state'] == 'cancelled';
    final editable = !busy && !hasRun && !cancelled;
    return Scaffold(
      appBar: AppBar(title: Text(draft == null ? '新邮件草稿' : '核对邮件内容')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('收件人：本人 163 邮箱。只发信，不扫描。'),
          const SizedBox(height: 16),
          if (draft != null)
            Text('${draftState(draft!)} · 版本 ${draft!['version']}'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('mailSubject'),
            controller: subject,
            enabled: editable,
            maxLength: 120,
            onChanged: (_) => setState(() => dirty = true),
            decoration: const InputDecoration(labelText: '主题'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('mailBody'),
            controller: body,
            enabled: editable,
            minLines: 5,
            maxLines: 15,
            maxLength: 2000,
            onChanged: (_) => setState(() => dirty = true),
            decoration: const InputDecoration(labelText: '正文'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          if (!hasRun && !cancelled) ...[
            FilledButton(
              key: const Key('saveMailDraft'),
              onPressed:
                  editable &&
                      subject.text.trim().isNotEmpty &&
                      body.text.trim().isNotEmpty
                  ? save
                  : null,
              child: Text(busy ? '保存中…' : '保存草稿'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('reviewMailDraft'),
              onPressed: editable && draft != null && !dirty ? confirm : null,
              child: const Text('核对并发送'),
            ),
            const Text(
              '也可以让小智复述后，在硬件上说“确认发送”。修改后需要重新核对。',
              style: TextStyle(color: Colors.black54),
            ),
            if (draft != null)
              TextButton(
                onPressed: !busy
                    ? () => act(() async {
                        final value = await widget.api.cancelMailDraft(
                          mailDraftId(draft!),
                        );
                        if (mounted) setState(() => apply(value));
                      })
                    : null,
                child: const Text('取消这份草稿'),
              ),
          ],
          if (hasRun)
            FilledButton(
              onPressed: !busy
                  ? () => act(() async {
                      final run = await widget.api.run(
                        draft!['run_id'].toString(),
                      );
                      if (mounted) await widget.openRun(run);
                    })
                  : null,
              child: const Text('查看发信任务'),
            ),
        ],
      ),
    );
  }
}
