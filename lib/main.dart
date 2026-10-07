import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'mail_report.dart';
import 'mail_drafts.dart';

const _native = MethodChannel('com.raiot.richard.demo/settings');
const _defaultEndpoint = String.fromEnvironment(
  'DEMO_API_URL',
  defaultValue: 'http://127.0.0.1:8010',
);
const _defaultToken = String.fromEnvironment('DEMO_API_TOKEN');
const _ink = Color(0xFF172337);
const _orange = Color(0xFFE5783C);

void main() => runApp(const RichardApp());

class RichardApp extends StatelessWidget {
  const RichardApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '小智任务',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _orange,
        surface: const Color(0xFFF6F7FA),
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F7FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F7FA),
        foregroundColor: _ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDEE3EA)),
        ),
      ),
    ),
    home: const TaskHome(),
  );
}

class TaskHome extends StatefulWidget {
  const TaskHome({super.key});
  @override
  State<TaskHome> createState() => _TaskHomeState();
}

class _TaskHomeState extends State<TaskHome> {
  DemoApi api = DemoApi(_defaultEndpoint, _defaultToken);
  List<Map<String, dynamic>> runs = [];
  String? error;
  bool loading = true, refreshing = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    loadConfig();
  }

  Future<void> loadConfig() async {
    try {
      final config = await _native.invokeMapMethod<String, dynamic>('load');
      api = DemoApi(
        config?['endpoint'] as String? ?? _defaultEndpoint,
        config?['token'] as String? ?? _defaultToken,
      );
    } on MissingPluginException {
      /* Widget tests use build-time defaults. */
    }
    if (!mounted) return;
    await refresh();
    if (mounted) {
      timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    }
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final result = await api.runs();
      if (mounted) {
        setState(() {
          runs = result;
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendly(e);
          loading = false;
        });
      }
    } finally {
      refreshing = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> settings() async {
    final endpoint = TextEditingController(text: api.endpoint);
    final token = TextEditingController(text: api.token);
    String? validation;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('连接设置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: endpoint,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '服务地址',
                    hintText: 'http://127.0.0.1:8010',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: token,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: '本地访问令牌'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'USB 联调使用本机服务。这里填写 Demo 用户令牌，模型密钥保留在服务端。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (validation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      validation!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final uri = Uri.tryParse(endpoint.text.trim());
                if (uri == null ||
                    !['http', 'https'].contains(uri.scheme) ||
                    uri.host.isEmpty ||
                    uri.userInfo.isNotEmpty ||
                    uri.hasQuery ||
                    uri.hasFragment) {
                  update(() => validation = '请输入完整的 http 或 https 服务地址');
                  return;
                }
                if (token.text.trim().isEmpty) {
                  update(() => validation = '请填写本地访问令牌');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      api = DemoApi(
        endpoint.text.trim().replaceAll(RegExp(r'/+$'), ''),
        token.text.trim(),
      );
      await _native.invokeMethod('save', {
        'endpoint': api.endpoint,
        'token': api.token,
      });
      await refresh();
    }
    endpoint.dispose();
    token.dispose();
  }

  Future<void> create() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MailDraftEditor(api: api, openRun: openRun),
      ),
    );
    await refresh();
  }

  Future<void> openDrafts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MailDraftInbox(api: api, openRun: openRun),
      ),
    );
    await refresh();
  }

  Future<void> openRun(Map<String, dynamic> run) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TaskDetail(api: api, initial: run),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final approvalCount = runs
        .where((r) => r['status'] == 'waiting_approval')
        .length;
    final activeCount = runs
        .where((r) => ['queued', 'running', 'cancelling'].contains(r['status']))
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '小智',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 26),
        ),
        actions: [
          IconButton(
            tooltip: '连接设置',
            onPressed: settings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('createTask'),
        onPressed: create,
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('写邮件'),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Color(0xFFF9BE83),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '你的任务工作台',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '小智执行，\n由你掌握。',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      stat('$activeCount', '执行中'),
                      const SizedBox(width: 32),
                      stat('$approvalCount', '待你确认'),
                      const Spacer(),
                      const Icon(
                        Icons.layers_rounded,
                        color: Color(0xFF61718C),
                        size: 52,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: openDrafts,
              icon: const Icon(Icons.mail_outline),
              label: const Text('查看语音与手机邮件草稿'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '最近任务',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                Text(
                  '${runs.length} 项',
                  style: const TextStyle(color: Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (error != null) errorCard(error!, refresh),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!loading && runs.isEmpty && error == null)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.task_alt, size: 44, color: _orange),
                    SizedBox(height: 16),
                    Text(
                      '从第一件小事开始',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '对小智口述邮件，核对内容后确认发送。\n只发给自己，不扫描邮箱。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, height: 1.6),
                    ),
                  ],
                ),
              ),
            for (final run in runs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => openRun(run),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              StatusPill(run['status']?.toString() ?? ''),
                              const Spacer(),
                              Text(
                                formatTime(run['created_at']),
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            run['prompt']?.toString() ?? '任务',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Text(
                                '查看进展',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              Spacer(),
                              Icon(
                                Icons.arrow_forward,
                                color: _orange,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget stat(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
    ],
  );
}

class TaskDetail extends StatefulWidget {
  const TaskDetail({super.key, required this.api, required this.initial});
  final DemoApi api;
  final Map<String, dynamic> initial;
  @override
  State<TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends State<TaskDetail> {
  late Map<String, dynamic> run;
  List<Map<String, dynamic>> events = [];
  Timer? timer;
  bool fetching = false, busy = false;
  String? error;
  String get id => run['id'].toString();
  @override
  void initState() {
    super.initState();
    run = widget.initial;
    refresh();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
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
      final current = await widget.api.run(id);
      final history = await widget.api.events(id);
      if (mounted) {
        setState(() {
          run = current;
          events = history;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendly(e));
    } finally {
      fetching = false;
    }
  }

  Future<void> approve() async {
    final approval = Map<String, dynamic>.from(run['approval'] as Map? ?? {});
    final version = approval['version'];
    if (version == null) {
      showError(context, ApiException('草稿版本尚未就绪，请刷新后重试。'));
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认提交这份草稿？'),
        content: SingleChildScrollView(
          child: Text(approval['draft']?.toString() ?? '请先核对任务内容。'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再看看'),
          ),
          FilledButton(
            key: const Key('confirmApproval'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );
    if (approved == true) await mutate(() => widget.api.approve(id, version));
  }

  Future<void> cancel() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消这项任务？'),
        content: const Text('小智会停止执行并清理本次会话。已产生的外部结果不会自动撤回。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续任务'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('取消任务'),
          ),
        ],
      ),
    );
    if (approved == true) await mutate(() => widget.api.cancel(id));
  }

  Future<void> mutate(Future<Map<String, dynamic>> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final current = await action();
      if (mounted) setState(() => run = current);
      await refresh();
    } catch (e) {
      if (mounted) {
        showError(context, e);
        await refresh();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openSession() async {
    final uri = Uri.tryParse(run['session_url']?.toString() ?? '');
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      showError(context, ApiException('会话入口尚未就绪'));
      return;
    }
    try {
      await _native.invokeMethod('openUrl', {'url': uri.toString()});
    } catch (e) {
      if (mounted) showError(context, ApiException('无法打开会话入口，请稍后重试。'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = run['status']?.toString() ?? '';
    final terminal = ['completed', 'cancelled', 'failed'].contains(status);
    final approval = run['approval'] as Map?;
    final approvalRequested = run['approval_requested'] == true;
    final userAction = run['user_action'] as Map?;
    final isMail = run['workflow'] == 'mail163';
    final sendOnly = isMail && run['mode'] == 'send_only';
    final mailContent = run['mail_authorization'] as Map?;
    final needsLogin = !terminal && userAction?['kind'] == 'login';
    final scanWindow = run['scan_window'] as Map?;
    final mailReport = isMail && run['report'] is Map
        ? run['report'] as Map
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务进展'),
        actions: [
          IconButton(
            onPressed: refresh,
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: terminal
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: busy || status == 'cancelling' ? null : cancel,
                      child: Text(status == 'cancelling' ? '正在取消…' : '取消任务'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: Key(needsLogin ? 'loginSession' : 'approveTask'),
                        onPressed: needsLogin && run['session_url'] != null
                            ? openSession
                            : !busy &&
                                  status == 'waiting_approval' &&
                                  !approvalRequested &&
                                  approval?['version'] != null
                            ? approve
                            : null,
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                needsLogin ? Icons.login : Icons.check_rounded,
                              ),
                        label: Text(
                          needsLogin
                              ? '打开云端邮箱登录'
                              : approvalRequested
                              ? '已确认，等待执行'
                              : status == 'waiting_approval'
                              ? '审核并提交'
                              : '等待小智执行',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (error != null) errorCard(error!, refresh),
            StatusPill(status),
            const SizedBox(height: 18),
            Text(
              run['prompt']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 23,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '创建于 ${formatTime(run['created_at'])}',
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
            const SizedBox(height: 22),
            if (sendOnly && mailContent != null)
              section('已确认的邮件内容', Icons.mail_outline, [
                const Text('仅发送到本人 163 邮箱，不扫描邮件。'),
                const SizedBox(height: 10),
                SelectableText('主题：${mailContent['subject']}'),
                const SizedBox(height: 10),
                SelectableText(mailContent['body']?.toString() ?? ''),
                if (run['phase'] != null)
                  Text('当前阶段：${mailPhase(run['phase'].toString())}'),
              ]),
            if (isMail && !sendOnly && scanWindow != null)
              section('邮件时间范围', Icons.schedule, [
                Text(
                  '${formatTime(scanWindow['from'])} 至 ${formatTime(scanWindow['to'])}',
                ),
                const SizedBox(height: 8),
                const Text(
                  '以任务创建时刻为截止时间。实际覆盖的文件夹、邮件数量及未完成事项会列在结果中。',
                  style: TextStyle(color: Colors.black54, height: 1.5),
                ),
              ]),
            if (userAction != null && !terminal)
              section('需要你操作', Icons.person_outline, [
                Text(
                  userAction['message']?.toString() ?? '请打开同一会话继续操作。',
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 8),
                const Text(
                  '密码、扫码和验证码在云端浏览器中完成，不要填进任务描述。',
                  style: TextStyle(color: Colors.black54, height: 1.5),
                ),
              ]),
            if (approval != null && approval['draft'] != null)
              section('待确认的草稿', Icons.edit_note, [
                if (approval['customer'] != null)
                  Text(
                    approval['customer'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 8),
                SelectableText(
                  approval['draft'].toString(),
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 10),
                Text(
                  '草稿版本 ${approval['version'] ?? '—'}',
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ]),
            if (run['session_url'] != null && !terminal)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OutlinedButton.icon(
                  key: const Key('openSession'),
                  onPressed: openSession,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开同一会话 · 人工接管'),
                ),
              ),
            if (run['result'] != null)
              section('执行结果', Icons.task_alt, [
                SelectableText(
                  run['result'].toString(),
                  style: const TextStyle(height: 1.6),
                ),
              ]),
            if (mailReport != null)
              section(
                sendOnly ? '邮件发送记录' : '邮件发送与扫描记录',
                Icons.fact_check_outlined,
                [
                  for (final line in mailReportLines(mailReport))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SelectableText(
                        line,
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                ],
              ),
            if (run['error'] != null)
              section('需要留意', Icons.info_outline, [
                SelectableText(
                  run['error'].toString(),
                  style: const TextStyle(color: Colors.red, height: 1.6),
                ),
              ]),
            section('执行记录', Icons.timeline, [
              if (events.isEmpty)
                const Text(
                  '等待第一条执行记录…',
                  style: TextStyle(color: Colors.black45),
                ),
              for (final event in events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 8, color: _orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event['message']?.toString() ??
                                  event['type']?.toString() ??
                                  '',
                              style: const TextStyle(height: 1.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatTime(
                                event['timestamp'] ?? event['created_at'],
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
            SelectableText(
              '任务 $id',
              style: const TextStyle(fontSize: 11, color: Colors.black38),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

Widget section(String title, IconData icon, List<Widget> children) => Container(
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, size: 20, color: _orange),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 16),
      ...children,
    ],
  ),
);
Widget errorCard(String message, VoidCallback retry) => Container(
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFFFFF0DF),
    borderRadius: BorderRadius.circular(14),
  ),
  child: Row(
    children: [
      const Icon(Icons.wifi_off, color: _orange),
      const SizedBox(width: 12),
      Expanded(
        child: Text(message, style: const TextStyle(fontSize: 13, height: 1.5)),
      ),
      IconButton(
        onPressed: retry,
        tooltip: '重试',
        icon: const Icon(Icons.refresh),
      ),
    ],
  ),
);
String friendly(Object e) =>
    e is TimeoutException ? '请求超时，请稍后重试。' : e.toString();
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(friendly(error))));
}

String formatTime(dynamic raw) {
  final time = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (time == null) return '—';
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(time.month)}-${pad(time.day)} ${pad(time.hour)}:${pad(time.minute)}';
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    const labels = {
      'queued': '排队中',
      'running': '执行中',
      'waiting_approval': '待你确认',
      'completed': '已完成',
      'cancelling': '正在取消',
      'cancelled': '已取消',
      'failed': '执行失败',
    };
    final color = status == 'completed'
        ? const Color(0xFF23795E)
        : status == 'failed'
        ? Colors.red.shade700
        : status == 'waiting_approval'
        ? const Color(0xFFB56320)
        : const Color(0xFF526580);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          labels[status] ?? status,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
