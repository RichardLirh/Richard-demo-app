/// Preserve external effects even if a mailbox task was stopped or failed.
String mailPhase(String phase) =>
    const {
      'starting': '正在启动浏览器',
      'waiting_login': '等待你登录',
      'preparing': '正在核对内容',
      'submitting': '正在发送',
      'verifying': '正在核验发送结果',
      'cleaning': '正在释放云资源',
    }[phase] ??
    phase;

List<String> mailReportLines(Map report) {
  final lines = <String>[];
  final receipt = report['sent_receipt'];
  final state = report['send_state']?.toString();
  if (receipt is Map && receipt['verified'] == true) {
    lines.add('邮件已确认发送。取消任务不会撤回这封邮件；尚未据此核实收件箱送达。');
    if (receipt['recipient'] != null) {
      lines.add('收件人：${receipt['recipient']}');
    }
    if (receipt['subject'] != null) {
      lines.add('主题：${receipt['subject']}');
    }
  } else if (state == 'not_started') {
    lines.add('邮件尚未开始发送。');
  } else if (state == 'rejected') {
    lines.add('发送在提交前已停止，邮件未发送。');
  } else {
    lines.add('邮件发送结果尚未确认，请先检查已发送文件夹，避免重复发送。');
  }
  final coverage = report['scan_coverage'];
  if (coverage is Map) {
    lines.add(
      coverage['complete'] == true ? '邮件扫描已完成。' : '邮件扫描尚未完成，以下仅为已检查的范围。',
    );
    if (coverage['messages_read'] != null) {
      lines.add('已读取邮件：${coverage['messages_read']} 封');
    }
    final folders = coverage['folders'];
    if (folders is List && folders.isNotEmpty) {
      lines.add(
        '已检查文件夹：${folders.map((f) => f is Map ? f['name'] ?? f['folder'] ?? '未命名' : f).join('、')}',
      );
    }
  }
  final summary = report['summary'];
  if (summary is String && summary.trim().isNotEmpty) lines.add(summary);
  final limitations = report['limitations'];
  if (limitations is List) {
    lines.addAll(limitations.whereType<String>().map((item) => '未完成或限制：$item'));
  }
  return lines;
}
