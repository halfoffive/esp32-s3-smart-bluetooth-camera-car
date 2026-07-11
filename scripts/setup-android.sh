#!/usr/bin/env bash
# setup-android.sh - 本地 Android 开发环境一键初始化
#
# 从仓库根目录执行，镜像 CI 中对 android/ 的 patch 逻辑。
# 注意：android/ 不在版本控制中，本脚本会重新生成并修改它。

set -euo pipefail

cd "$(dirname "$0")/.."
cd app

echo '[setup-android] Bootstrapping Flutter Android platform...'
flutter create . --platforms=android --org com.smartcar --project-name smart_car_remote

echo '[setup-android] Integrating flutter_rust_bridge for Android...'
flutter_rust_bridge_codegen integrate

# integrate 会覆写 lib/main.dart，须从版本控制恢复真实入口文件。
git checkout -- lib/main.dart

# 清理 integrate 生成的模板演示文件，避免编译/测试污染。
rm -f rust/src/api/simple.rs \
      lib/src/rust/api/simple.dart \
      integration_test/simple_test.dart \
      test_driver/integration_test.dart

# --- patch cargokit plugin.gradle（Gradle 9 兼容） ---
# integrate 生成的 rust_builder/cargokit/gradle/plugin.gradle 使用 project.exec {}，
# Gradle 9 已移除该方法，须替换为 ExecOperations 注入式调用。
CARGOKIT_PLUGIN="rust_builder/cargokit/gradle/plugin.gradle"
if [ -f "$CARGOKIT_PLUGIN" ]; then
  echo '[setup-android] Patching cargokit plugin.gradle for Gradle 9...'
  python3 - "$CARGOKIT_PLUGIN" <<'PY'
import sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()
if 'javax.inject.Inject' not in text:
    text = text.replace(
        "import org.apache.tools.ant.taskdefs.condition.Os\n",
        "import org.apache.tools.ant.taskdefs.condition.Os\nimport javax.inject.Inject\nimport org.gradle.process.ExecOperations\n",
    )
if 'getExecOperations' not in text:
    text = text.replace(
        "    @TaskAction\n",
        "    @Inject\n    abstract ExecOperations getExecOperations()\n\n    @TaskAction\n",
    )
text = text.replace("project.exec {", "getExecOperations().exec {")
with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
PY
fi

# --- patch app/build.gradle(.kts) compileSdk -> 35 ---
echo '[setup-android] Patching app compileSdk to 35...'
for f in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$f" ]; then
    case "$f" in
      *.gradle.kts)
        sed -i -E 's/compileSdk[[:space:]]*=[[:space:]]*[0-9]+/compileSdk = 35/g; s/compileSdk[[:space:]]*=[[:space:]]*flutter\.compileSdkVersion/compileSdk = 35/g' "$f"
        ;;
      *.gradle)
        sed -i -E 's/compileSdk[[:space:]]+[0-9]+/compileSdk 35/g; s/compileSdk[[:space:]]+flutter\.compileSdkVersion/compileSdk 35/g; s/compileSdkVersion[[:space:]]+flutter\.compileSdkVersion/compileSdkVersion 35/g' "$f"
        ;;
    esac
  fi
done

# --- patch 根 build.gradle(.kts) 强制所有插件模块 compileSdk 35 ---
ROOT_GRADLE=""
for f in android/build.gradle android/build.gradle.kts; do
  if [ -f "$f" ]; then ROOT_GRADLE="$f"; break; fi
done
if [ -n "$ROOT_GRADLE" ]; then
  echo '[setup-android] Patching root compileSdk for plugin modules...'
  python3 - "$ROOT_GRADLE" <<'PY'
import sys, re
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()
if path.endswith('.kts'):
    block = '''    afterEvaluate {
        if (hasProperty("android")) {
            extensions.findByName("android")?.let { ext ->
                try {
                    ext::class.java.getMethod("setCompileSdk", Int::class.javaPrimitiveType).invoke(ext, 35)
                } catch (_: Throwable) {
                    try {
                        ext::class.java.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, 35)
                    } catch (_: Throwable) {
                    }
                }
            }
        }
    }
'''
else:
    block = '''    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            project.android {
                compileSdk 35
            }
        }
    }
'''
pattern = re.compile(r'^(subprojects\s*\{)\s*$', re.MULTILINE)
def repl(m, block=block):
    return m.group(1) + '\n' + block
new_text, count = pattern.subn(repl, text, count=1)
if count == 0:
    new_text = text.rstrip() + '\n\n' + block.strip() + '\n'
with open(path, 'w', encoding='utf-8') as f:
    f.write(new_text)
PY
fi

# --- 注入 Android BLE 运行时权限 ---
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: 未找到 AndroidManifest.xml: $MANIFEST"
  exit 1
fi
echo '[setup-android] Injecting BLE permissions into AndroidManifest.xml...'
python3 - "$MANIFEST" <<'PY'
import sys
path = sys.argv[1]
perms = [
    '    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />',
    '    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />',
    '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
]
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()
if 'android.permission.BLUETOOTH_SCAN' not in text:
    text = text.replace('</manifest>', '\n'.join(perms) + '\n</manifest>')
with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
PY

echo 'Android setup complete. Run: cd app && flutter pub get && flutter_rust_bridge_codegen generate'
