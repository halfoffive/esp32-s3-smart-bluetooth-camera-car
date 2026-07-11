#!/usr/bin/env pwsh
# setup-android.ps1 - 本地 Android 开发环境一键初始化（PowerShell 版本）
#
# 从仓库根目录执行，镜像 CI 中对 android/ 的 patch 逻辑。
# 注意：android/ 不在版本控制中，本脚本会重新生成并修改它。

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location "$repoRoot/app"

function Get-PythonCmd {
    # Windows 开发机通常有 python；部分环境只有 python3
    if (Get-Command python -ErrorAction SilentlyContinue) { return "python" }
    if (Get-Command python3 -ErrorAction SilentlyContinue) { return "python3" }
    throw "未找到 python 或 python3，无法执行 Android manifest/gradle patch"
}

Write-Host '[setup-android] Bootstrapping Flutter Android platform...'
flutter create . --platforms=android --org com.smartcar --project-name smart_car_remote

Write-Host '[setup-android] Integrating flutter_rust_bridge for Android...'
flutter_rust_bridge_codegen integrate

# integrate 会覆写 lib/main.dart，须从版本控制恢复真实入口文件。
git checkout -- lib/main.dart

# 清理 integrate 生成的模板演示文件，避免编译/测试污染。
$templateFiles = @(
    "rust/src/api/simple.rs",
    "lib/src/rust/api/simple.dart",
    "integration_test/simple_test.dart",
    "test_driver/integration_test.dart"
)
foreach ($f in $templateFiles) {
    if (Test-Path $f) {
        Remove-Item $f -Force
    }
}

# --- patch cargokit plugin.gradle（Gradle 9 兼容） ---
$CargokitPlugin = "rust_builder/cargokit/gradle/plugin.gradle"
if (Test-Path $CargokitPlugin) {
    Write-Host '[setup-android] Patching cargokit plugin.gradle for Gradle 9...'
    $text = Get-Content $CargokitPlugin -Raw
    if ($text -notmatch 'javax\.inject\.Inject') {
        $text = $text -replace "import org\.apache\.tools\.ant\.taskdefs\.condition\.Os`r?`n", "import org.apache.tools.ant.taskdefs.condition.Os`nimport javax.inject.Inject`nimport org.gradle.process.ExecOperations`n"
    }
    if ($text -notmatch 'getExecOperations') {
        $text = $text -replace "    \@TaskAction`r?`n", "    @Inject`n    abstract ExecOperations getExecOperations()`n`n    @TaskAction`n"
    }
    $text = $text -replace 'project\.exec \{', 'getExecOperations().exec {'
    Set-Content $CargokitPlugin $text -NoNewline
}

# --- patch app/build.gradle(.kts) compileSdk -> 35 ---
Write-Host '[setup-android] Patching app compileSdk to 35...'
$AppGradleKts = "android/app/build.gradle.kts"
$AppGradle = "android/app/build.gradle"
if (Test-Path $AppGradleKts) {
    $text = Get-Content $AppGradleKts -Raw
    $text = $text -replace 'compileSdk\s*=\s*\d+', 'compileSdk = 35'
    $text = $text -replace 'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 35'
    Set-Content $AppGradleKts $text -NoNewline
}
elseif (Test-Path $AppGradle) {
    $text = Get-Content $AppGradle -Raw
    $text = $text -replace 'compileSdk\s+\d+', 'compileSdk 35'
    $text = $text -replace 'compileSdk\s+flutter\.compileSdkVersion', 'compileSdk 35'
    $text = $text -replace 'compileSdkVersion\s+flutter\.compileSdkVersion', 'compileSdkVersion 35'
    Set-Content $AppGradle $text -NoNewline
}

# --- patch 根 build.gradle(.kts) 强制所有插件模块 compileSdk 35 ---
$RootGradleKts = "android/build.gradle.kts"
$RootGradle = "android/build.gradle"
$RootGradlePath = $null
if (Test-Path $RootGradleKts) { $RootGradlePath = $RootGradleKts }
elseif (Test-Path $RootGradle) { $RootGradlePath = $RootGradle }

if ($RootGradlePath) {
    Write-Host '[setup-android] Patching root compileSdk for plugin modules...'
    $py = Get-PythonCmd
    $script = @'
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
'@
    $script | & $py - $RootGradlePath
}

# --- 注入 Android BLE 运行时权限 ---
$Manifest = "android/app/src/main/AndroidManifest.xml"
if (-not (Test-Path $Manifest)) {
    throw "ERROR: 未找到 AndroidManifest.xml: $Manifest"
}
Write-Host '[setup-android] Injecting BLE permissions into AndroidManifest.xml...'
$py = Get-PythonCmd
$script = @'
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
'@
$script | & $py - $Manifest

Write-Host 'Android setup complete. Run: cd app && flutter pub get && flutter_rust_bridge_codegen generate'
