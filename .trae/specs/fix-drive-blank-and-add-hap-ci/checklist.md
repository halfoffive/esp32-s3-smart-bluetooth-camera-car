# Checklist

## Part A: 驾驶 tab 空白修复

- [x] `app/lib/main.dart` 的 `_HomeScreenState` 已在 `initState` 中用 `ref.listenManual` 注册 errorMessage 监听
- [x] `app/lib/main.dart` 的 `_HomeScreenState.build` 顶部已删除原 `ref.listen(bleControllerProvider, ...)` 块
- [x] SnackBar 逻辑保留（`ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar`）
- [x] `app/lib/ble/ble_controller.dart` 已在 `BleController()` 构造处加 `debugPrint('[BleController] constructed')`
- [x] `app/lib/ble/ble_controller.dart` 已在 `_onConnectionStateChange` / `_onConnected` / `_onDisconnected` 加 debugPrint
- [x] `app/lib/ble/ble_controller.dart` 已在 `startScan` / `connect` 入口加 debugPrint
- [x] `app/lib/ble/ble_controller.dart` 已在 stream 订阅 onError 回调加 debugPrint
- [x] debugPrint 在 release 构建无副作用（Flutter 框架自动剥离，或用 `if (kDebugMode)` 守卫）
- [x] 改动遵循 M3 原生组件清单（未引入第三方 UI 包）
- [x] 改动遵循中文注释约定

## Part B: CI 增加 HAP 构建

- [x] `.github/workflows/app.yml` 已新增 `build-hap` job（runs-on: ubuntu-latest）
- [x] `build-hap` job 已配置 JDK 17（actions/setup-java@v4）
- [x] `build-hap` job 已 clone flutter_flutter SDK 并加入 PATH
- [x] `build-hap` job 已下载 OpenHarmony SDK 并配置环境变量
- [x] `build-hap` job 已安装 hvigor / ohpm（npm，`@ohos:registry`）
- [x] `build-hap` job 已执行 `flutter create . --platforms=ohos`（在 app/ 下）
- [x] `build-hap` job 已执行 frb codegen + `flutter pub get`
- [x] `build-hap` job 已执行 `flutter build hap --release`
- [x] `build-hap` job 已用 actions/upload-artifact@v7 上传 HAP 产物
- [x] `build-hap` job 用 `continue-on-error: true` 标注实验性（不阻塞其他 job）
- [x] CI actions/* 系列使用 Node 24 原生版本（checkout@v7 / cache@v6 / upload-artifact@v7 / setup-java@v4）
- [x] release job 的 `needs` 列表已包含 `build-hap`（或确认 continue-on-error 语义不影响 release）
- [x] release job 的 `files` 列表已增加 `artifacts/app-hap/*`
- [x] YAML 语法校验通过（python yaml.safe_load 解析 4 个 job：cargo-doc / build-matrix / build-hap / release）

## Part C: 文档同步

- [x] CHANGELOG.md `[Unreleased]` Added 新增 CI build-hap job 条目
- [x] CHANGELOG.md `[Unreleased]` Fixed 新增驾驶 tab 空白修复条目（ref.listen 移 initState + 诊断日志）
- [x] CHANGELOG.md `[Unreleased]` Added 新增 BleController debugPrint 诊断日志条目
- [x] AGENTS.md 工具链陷阱新增 OpenHarmony SDK / hvigor / ohpm 安装约定
- [x] AGENTS.md 工具链陷阱新增 flutter_flutter SDK fork 用法说明
- [x] AGENTS.md 工具链陷阱新增 Riverpod ref.listenManual 推荐用法
- [x] README.md 若涉及构建命令/平台支持，已同步 HAP 构建说明（仅在有用户可见变化时）

## Part D: 修复 build-hap job（鸿蒙构建 bug）

- [x] 已定位 build-hap 失败根因：`gitcode.com/CPF-Flutter/flutter_flutter` fork 的 `version` 文件为 `0.0.0-unknown`，`flutter create --platforms=ohos` 内部 `flutter pub get` 因版本约束失败
- [x] `.github/workflows/app.yml` 的 `build-hap` job 已在 Clone flutter_flutter 后新增版本补丁步骤，写入真实版本号（如 `3.27.4`）并同步修正 `bin/cache/flutter.version.json`
- [x] `.github/workflows/app.yml` 的 `build-hap` job 已将 OpenHarmony SDK 下载与环境变量配置步骤提前到 `flutter create --platforms=ohos` 之前
- [x] HAP artifact 上传路径已调优，优先常见 hvigor 产物目录
- [x] YAML 语法校验通过

## CI 验证

- [x] push 触发 App Build workflow，`cargo-doc` job ✅ success（clippy 零警告门槛通过）—— run 29135900710 已确认
- [x] `build-matrix` job 4 平台（apk/linux/windows/macos）✅ success（Part A 改动编译通过）—— run 29135900710 已确认
- [x] `build-hap` job 版本补丁顺序修复经子代理本地复现验证（`flutter --version` bootstrap 后 patch `bin/cache/flutter.version.json`，pub get 通过 `Got dependencies.`）—— 本地复现通过
- [~] CI workflow_dispatch 实跑验证：用户决策跳过（信任本地复现直接结项；build-hap gate 为 `if: github.event_name == 'workflow_dispatch'`，token 无 actions:write 权限无法自动触发）
- [~] release job（若 tag 推送）包含 HAP 产物：依赖 build-hap 实跑成功，本轮跳过

## 用户实测验证（CI 通过后请用户确认）

- [ ] 用户运行 `flutter run`，控制台输出 `[BleController] constructed` 等诊断日志
- [ ] 驾驶 tab 显示摄像头占位（"等待画面..."）+ 遥测面板（——）+ 操控面板，**不再空白**
- [ ] 点击底部「设备」/「设置」/「驾驶」tab 正常切换
- [ ] 若 bug 仍在，用户已提供 `flutter run` 完整控制台日志供深入排查
