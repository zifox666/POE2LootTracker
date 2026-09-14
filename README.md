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
- `tool/update_item_base_names.ps1`：更新离线物品基础名与简中名称资源。
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

发版前更新物品名称数据并验证生成结果：

```powershell
.\tool\update_item_base_names.ps1
.\tool\update_item_base_names.ps1 -Check
```

名称更新脚本需要 PowerShell 7，并合并 RePoE、编年史简中词典、国服官方交易静态数据及本地人工修正；应用运行时不联网。

## 版本管理

`pubspec.yaml` 的 `version:` 是唯一版本来源，格式为 `MAJOR.MINOR.PATCH`。修改版本后运行：

```powershell
dart run tool/version.dart
```

该命令会同步生成：

- `lib/app_version.dart`：应用内显示、更新比较和预期发布标签。
- `tracker_host/TrackerHost.csproj`：.NET 程序集版本。

Windows EXE 版本由 Flutter 构建系统直接从 `pubspec.yaml` 传给 Runner。CI 会执行 `--check`，任何版本漂移都会阻止发布。

## 自动打包与发布

发布使用与语义版本完全一致的标签。例如 `pubspec.yaml` 为 `1.2.3` 时：

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
4. 生成 `POE2LootTracker-vX.Y.Z-windows-x64-setup.exe` 安装包和 `POE2LootTracker-vX.Y.Z-windows-x64-portable.zip` 便携包。
5. 为两个产物分别生成 `.sha256`，创建 GitHub Release 并上传四个文件。

工作流只接受已经推送的标签，不会移动或覆盖既有标签。

## 应用内更新

主程序启动后会静默查询 GitHub 最新正式版，也可在“设置 → 软件更新”手动检查。

- 安装版会下载安装程序及其 SHA-256 文件，校验完成后打开安装向导。
- 便携版不会自动覆盖文件；发现更新后会打开最新 GitHub Release 页面，由用户下载便携包并手动替换。

安装程序会请求管理员权限、提示关闭正在运行的应用，并保留 `%APPDATA%\POE2LootTracker` 中的用户数据和缓存。

## 许可证

项目许可证见 `LICENSE`，第三方归属与再分发说明见 `THIRD_PARTY_NOTICES.md` 和 `third_party/` 下的许可证文件。
