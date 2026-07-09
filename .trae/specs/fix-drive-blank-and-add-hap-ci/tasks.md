# Tasks

## Part A: 驾驶 tab 空白修复（防御性 + 诊断）

- [x] Task 1: `ref.listen` 移到 `initState` 用 `ref.listenManual` ✅
  - 文件：`app/lib/main.dart` 的 `_HomeScreenState`
  - 改动：
    - `initState` 中调用 `ref.listenManual(bleControllerProvider, (previous, next) { ... })`，保留原 SnackBar 逻辑
    - `build` 顶部删除原 `ref.listen(bleControllerProvider, ...)` 块
    - 保留 `kReleaseMode` 无关的注释说明
  - 验证：`flutter analyze`（若有 flutter 命令）零警告；CI build-matrix linux 通过
  - 依赖：无

- [x] Task 2: `BleController` 加 debugPrint 诊断日志 ✅（10 处 debugPrint + import foundation）
  - 文件：`app/lib/ble/ble_controller.dart`
  - 改动（仅 debug 生效，用 `if (kDebugMode)` 守卫或直接 `debugPrint`，release 自动剥离）：
    - `BleController()` 构造：`debugPrint('[BleController] constructed')`
    - `_onConnectionStateChange`：`debugPrint('[BleController] conn state: ${update.connectionState}')`
    - `_onConnected` / `_onDisconnected`：`debugPrint('[BleController] connected/disconnected')`
    - `startScan` / `connect`：`debugPrint('[BleController] scan/connect start')`
    - stream 订阅 onError：`debugPrint('[BleController] stream error: $e')`
  - 验证：release 构建无副作用；CI clippy 零警告（Rust 侧未改）
  - 依赖：无

## Part B: CI 增加 HAP 构建

- [x] Task 3: 调研 flutter_flutter SDK 与 OpenHarmony 工具链可用性 ✅（gitcode branches API 返回 No Data，CI 用 git clone --depth 1；华为官方文档确认 JDK 17 + hvigor 可 npm 安装 + @ohos:registry；SDK 走 gitee openharmony docs 公开下载）
  - 子任务：
    - [ ] 3.1 WebFetch `https://gitcode.com/CPF-Flutter/flutter_flutter` 确认默认分支与 clone URL（README 为空，需检查分支结构）
    - [ ] 3.2 确认 `flutter build hap` 命令是否需要额外的 `ohos/` 平台目录模板（`flutter create --platforms ohos` 是否由 flutter_flutter SDK 支持）
    - [ ] 3.3 确认 OpenHarmony SDK 公开下载 URL（gitee openharmony docs release-notes，选 API 14+ 版本）
    - [ ] 3.4 确认 hvigor/ohpm npm 安装方式（`@ohos:registry=https://repo.harmonyos.com/npm/` + `npm install -g @ohos/hvigor` 或类似）
  - 输出：Task 4 实施所需的确切 URL、版本号、命令
  - 依赖：无（可与 Task 1/2 并行）

- [x] Task 4: 在 `.github/workflows/app.yml` 新增 `build-hap` job ✅
  - 文件：`.github/workflows/app.yml`
  - 改动：
    - 新增 `build-hap` job（runs-on: ubuntu-latest，permissions: contents: read）
    - 步骤：
      1. Checkout（actions/checkout@v7）
      2. Setup JDK 17（actions/setup-java@v4，distribution temurin）
      3. Clone flutter_flutter SDK 到 `$HOME/flutter_ohos`（git clone gitcode 仓库）
      4. 把 flutter_flutter 加入 PATH（`echo "$HOME/flutter_ohos/bin" >> $GITHUB_PATH`）
      5. 验证 `flutter --version` + `flutter doctor`（ohos 支持检测）
      6. Setup Rust（dtolnay/rust-toolchain@stable）+ cargo 缓存（actions/cache@v6）
      7. Install cargo-expand + flutter_rust_bridge_codegen（与现有 build-matrix 一致版本）
      8. Clean 平台目录 + `flutter create . --platforms=ohos --org com.smartcar --project-name smart_car_remote`（在 app/ 下）
      9. 下载 OpenHarmony SDK（公开 URL）+ 解压到 `$HOME/ohos-sdk`
      10. 配置 ohpm：`npm install -g @ohos/hvigor @ohos/ohpm`（或对应包名）+ `ohpm config set registry https://ohpm.openharmony.cn/ohpm/`
      11. 配置环境变量：`OHOS_SDK_HOME` / `HOS_SDK_HOME` / PATH
      12. Generate frb bindings + `flutter pub get`
      13. `flutter build hap --release`（unsigned）
      14. Upload artifact（actions/upload-artifact@v7，name: app-hap，path: 查找 hvigor 产物路径）
    - `continue-on-error: true` 标注为实验性 job（不阻塞 release，因工具链不确定性高）
  - 验证：push 触发 CI，build-hap job 运行（允许失败但记录日志供调试）
  - 依赖：Task 3（需确切 URL/版本）

- [x] Task 5: release job artifact 列表增加 `app-hap` ✅
  - 文件：`.github/workflows/app.yml` 的 release job
  - 改动：
    - `Download all artifacts` 的 pattern 保持 `app-*`（已涵盖 app-hap）
    - `Create Release` 的 files 列表增加 `artifacts/app-hap/*`
    - release job 的 `needs` 增加 `build-hap`（但 build-hap 用 continue-on-error，release 仍可触发——需确认 GitHub Actions 语义：continue-on-error 失败的 job 在 needs 中视为 success）
  - 验证：tag 推送时 release 包含 HAP（若 build-hap 成功）
  - 依赖：Task 4

## Part C: 文档同步

- [x] Task 6: 同步 CHANGELOG / AGENTS / README ✅
  - 子任务：
    - [ ] 6.1 CHANGELOG.md `[Unreleased]` Added 新增「CI build-hap job」+ Fixed 新增「驾驶 tab 空白：ref.listen 移到 initState + 诊断日志」
    - [ ] 6.2 AGENTS.md 工具链陷阱新增：OpenHarmony SDK / hvigor / ohpm 安装约定 + flutter_flutter SDK fork 用法 + HAP 构建注意事项
    - [ ] 6.3 README.md 若涉及构建命令/平台支持，同步新增 HAP 构建说明（仅在有用户可见变化时）
  - 依赖：Task 1/2/4/5 完成

## Part D: 修复 build-hap job（鸿蒙构建 bug）

- [x] Task 8: 修复 `build-hap` job 因 flutter_flutter SDK fork `version` 为 `0.0.0-unknown` 导致 `flutter create --platforms=ohos` 失败 ✅
  - 文件：`.github/workflows/app.yml` 的 `build-hap` job
  - 根因：gitcode fork 默认分支 `br_3.27.4-ohos-1.0.4` 的 `version` 文件写死为 `0.0.0-unknown`；`flutter create` 内部会跑 `flutter pub get`，项目 `pubspec.yaml` 要求 `flutter: '>=3.27.0'`，`flutter_test` 约束要求 `>=3.18.0-18.0.pre.54`，因此 `0.0.0-unknown` 不满足约束，版本解析失败。
  - 改动：
    - Clone 步骤后新增 `Fix Flutter SDK version for fork` 步骤，写入真实版本号（如 `3.27.4`）到 `$HOME/flutter_ohos/version`
    - 同步修正 `bin/cache/flutter.version.json` 中的 `0.0.0-unknown` 占位（若存在）
    - 在 `flutter create --platforms=ohos` 前下载并配置 OpenHarmony SDK，确保 `HOS_SDK_HOME` / `OHOS_SDK_HOME` / `PATH` 已设置；`flutter create` 可能需要 SDK 定位
    - 将 OpenHarmony SDK 下载步骤从第 9 步提前到 `flutter create` 之前（Bootstrap ohos platform 之前）
    - 调优 artifact 上传路径，优先 `app/build/ohos/**/*.hap` / `app/ohos/entry/build/default/outputs/default/*.hap` 等常见 hvigor 产物路径
  - 验证：push 触发 CI，`build-hap` job 的 `Bootstrap ohos platform` 步骤通过；`Build HarmonyOS HAP` 步骤至少能继续向下执行；最终若成功则上传 `app-hap` artifact
  - 依赖：无（仅修改 CI 步骤顺序与版本补丁）

## Task Dependencies

- Task 1 ⟂ Task 2（独立，可并行）
- Task 3 ⟂ Task 1/2（独立调研，可并行）
- Task 4 depends on Task 3（需确切 URL/版本）
- Task 5 depends on Task 4
- Task 6 depends on Task 1/2/4/5
- Task 8 depends on Task 4（仅修改已有 build-hap job，不阻塞之前完成项）

## Parallelization Batches

- **Batch 1**（并行）：Task 1 + Task 2 + Task 3
- **Batch 2**（串行）：Task 4 → Task 5
- **Batch 3**（最后）：Task 6
- **Batch 4（追加）**：Task 8
