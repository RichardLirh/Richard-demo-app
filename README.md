# 小智任务 App

Flutter 原生 Android Demo：任务创建、列表、进展、事件记录、草稿版本审核、取消和同一浏览器会话的人工接管入口。

## 本机运行

环境：Flutter 3.47.6、Dart 3.13.5、Microsoft OpenJDK 17、Android API 36 / Build Tools 36，USB 手机 Redmi Note 12 Turbo（Android 15）。本机 SDK 位于 `%LOCALAPPDATA%/Flutter/flutter` 与 `%LOCALAPPDATA%/Android/Sdk`。

1. 启动 RAIOT 本机任务服务（端口 8010）。
2. 保持手机 USB 调试已授权。
3. 运行 `./Build-Demo.ps1 -Install`。脚本从 `../.local/task-tokens.json` 的 `owner` 字段读取本地访问令牌，不打印令牌。
4. 手机打开“小智任务”，创建演示 CRM 跟进任务。草稿生成后核对内容，再点击“审核并提交”。
5. 需要人工操作时，打开同一会话入口，操作后返回 App 查看进展。

USB 转发为 `adb reverse tcp:8010 tcp:8010` 和 `adb reverse tcp:18765 tcp:18765`。设置按钮可修改服务地址与访问令牌。模型密钥只保存在服务端，不进入 App 源码。

当前使用 Debug APK 本机测试；只有 Debug manifest 开启 HTTP。正式发布需要 HTTPS、正式登录/令牌轮换及发布签名；不要公开含本机访问令牌的 APK。

## API 契约

全部 `/api` 请求包含 `Authorization: Bearer <owner token>`。

| 接口 | 请求 / 返回 |
| --- | --- |
| `POST /api/runs` | `{prompt}` → Run |
| `GET /api/runs` | `{runs: Run[]}` |
| `GET /api/runs/{id}` | Run |
| `GET /api/runs/{id}/events` | `{events: Event[]}` |
| `POST /api/runs/{id}/approve` | `{approved: true, version}` → Run |
| `POST /api/runs/{id}/cancel` | `{}` → Run |

Run 字段：`id, prompt, status, created_at, updated_at, result?, error?, session_url?, approval?`。`approval={version,draft,customer}`。状态：`queued/running/waiting_approval/completed/cancelling/cancelled/failed`。Event 字段：`id,type,message,timestamp`。

App 每 2–3 秒刷新。审批携带用户打开确认框时看到的草稿版本，服务器以 409 拒绝过期批准。取消请求后由服务端确认清理完成才显示“已取消”。会话入口 URL 仅接受 HTTP(S)。

## 验证

`flutter analyze` 与 `flutter test test/api_test.dart` 检查静态代码、鉴权头和过期审批冲突。`./Build-Demo.ps1 -IntegrationTest` 在真机验证创建、事件页与取消，不依赖模型任务执行成功。完整 App → Hermes 云端执行应另行验收，不以排队状态代替执行成功。

当前验证记录（2026-10-07）：`flutter analyze` 无问题；API 单元测试与真实本机服务集成测试共 3 项通过；Android arm64 Debug APK 构建通过。真机 ADB 已连接，但安装第一次被手机返回 `INSTALL_FAILED_USER_RESTRICTED`，需要用户打开 USB 安装并允许安装提示；手机 UI 和云端模型全链路尚未验收。

可用 APK：`artifacts/xiaozhi-task-demo-debug.apk`。该文件只留在本机，不进入 Git。
