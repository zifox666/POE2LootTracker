# POE2 LootTracker

POE2 LootTracker 是面向 Windows 的《Path of Exile 2》掉落、地图、击杀和市场价格追踪工具。界面使用 Flutter，内存读取与本地数据存储由自包含的 .NET 辅助进程完成。

> 本项目通过读取游戏进程内存获取数据。使用前请自行了解并承担游戏规则与账号风险。

## 项目结构

- `lib/`：Flutter 桌面界面、应用状态和自动更新。
- `tracker_host/`：.NET 10 追踪进程。
- `tracker_host_tests/`：追踪进程测试。
- `third_party/`：带许可证信息的上游源码与数据。
- `windows/`：Windows Runner 与组合构建规则。
- `tool/version.dart`：项目版本同步与发布标签校验。
- `.github/workflows/release.yml`：Windows 构建和 GitHub Release 发布。

## 本地开发

需要 Windows、Flutter 3.41.3、Visual Studio 的“使用 C++ 的桌面开发”工作负载，以及 .NET 10 SDK。

```powershell
flutter pub get
dart run tool/version.dart --check
flutter run -d windows
```

提交前可执行：

```powershell
flutter analyze
flutter test
dotnet test tracker_host_tests/TrackerHost.Tests.csproj -c Release
```

正式构建产物位于 `build\windows\x64\runner\Release`。该目录已经包含 Flutter 应用、`tracker_host` 自包含运行时、许可证和运行所需资源，发布时必须整体打包。

## 版本管理

`pubspec.yaml` 的 `version:` 是唯一版本来源，格式为 `MAJOR.MINOR.PATCH+BUILD`。修改版本后运行：

```powershell
dart run tool/version.dart
```

该命令会同步生成：

- `lib/app_version.dart`：应用内显示、更新比较和预期发布标签。
- `tracker_host/TrackerHost.csproj`：.NET 程序集版本。

Windows EXE 版本由 Flutter 构建系统直接从 `pubspec.yaml` 传给 Runner。CI 会执行 `--check`，任何版本漂移都会阻止发布。

## 自动打包与发布

发布使用与语义版本完全一致的标签。例如 `pubspec.yaml` 为 `1.2.3+7` 时：

```powershell
dart run tool/version.dart
git add .
git commit -m "release: v1.2.3"
git tag v1.2.3
git push origin main --follow-tags
```

推送 `vMAJOR.MINOR.PATCH` 标签后，GitHub Actions 会自动：

1. 校验标签和项目版本一致。
2. 执行 Flutter 静态检查、Flutter 测试和 .NET 测试。
3. 构建完整 Windows x64 目录。
4. 生成 `POE2LootTracker-vX.Y.Z-windows-x64.zip` 和对应 `.sha256`。
5. 创建 GitHub Release、生成发行说明并上传两个文件。

工作流只接受已经推送的标签，不会移动或覆盖既有标签。

## 应用内更新

主程序启动后会静默查询 GitHub 最新正式版，也可在“设置 → 软件更新”手动检查。发现新版本后：

1. 下载完整 Windows x64 压缩包及 SHA-256 文件。
2. 校验压缩包完整性。
3. 启动独立更新脚本并关闭追踪进程和主程序。
4. 更新脚本解压完整包、覆盖当前安装目录并重新启动应用。

更新失败时会保留当前可执行文件并尝试重新启动，错误详情写入系统临时目录下的 `POE2LootTracker-update-error.log`。这是便携版覆盖更新；请将程序放在当前用户有写权限的目录中。

## 许可证

项目许可证见 `LICENSE`，第三方归属与再分发说明见 `THIRD_PARTY_NOTICES.md` 和 `third_party/` 下的许可证文件。
