# ENV_SETUP

## 1. 本地运行步骤

## 项目主线说明

- 当前主线是 Flutter 工程。
- 运行入口：`lib/main.dart`
- 不要用根目录 `src/` 那套 React/Vite 脚手架来启动记账 App 主功能。

## 基础依赖

建议本地准备：

- Flutter SDK
- Dart SDK（通常跟随 Flutter）
- Android Studio 或至少 Android SDK / platform-tools
- Java 17
- Xcode（如需 iOS/macOS）

### 已知 Android 构建参数

- Java 版本：17
- Android package：`com.akabooz.bookkeeper.ledger_app`
- `compileSdk`：36
- `targetSdk`：36

## 安装依赖

```bash
flutter pub get
```

如果只是维护根目录 Flutter 主线，这一步通常够用。

根目录还存在 React/Vite 依赖，但那不是当前主线；除非你明确要处理 `src/` 目录，否则不需要先运行 `npm install`。

## 启动命令

### 本地调试运行

```bash
flutter run
```

### 指定 Android 设备

```bash
flutter devices
adb devices
flutter run -d <DEVICE_ID>
```

## 环境变量 / 配置项

### 当前没有标准 `.env` 文件

本项目大部分配置不是通过环境变量注入，而是用户在 App 设置页里输入并持久化在本地：

- 百度语音识别 API Key / Secret
- 百度 OCR API Key / Secret
- DeepSeek API Key / 模型
- 通义千问 API Key / 模型
- WebDAV URL / 用户名 / 密码

### Android 本地配置

- `android/local.properties` 需要存在
- 至少要有 `flutter.sdk=...`
- 一般由 Flutter / Android Studio 自动生成

## 2. 测试账号 / 测试数据

### 测试账号

- 当前没有内置登录体系
- 没有测试账号概念

### 测试数据

- 可直接用 App 内新增账户、流水构造测试数据
- 可通过“导入随手记数据”导入 Excel
- 可通过“导入备份数据”导入 JSON

### 自动化测试现状

- 当前只有一个轻量级 widget smoke test：
  - [test/widget_test.dart](/Users/akabooz/Documents/记账APP_副本/test/widget_test.dart)
- 测试覆盖很有限，不能替代手工验证

## 3. 构建 / 打包命令

## Android Debug

```bash
flutter build apk --debug
```

### 重要坑点

这个项目的 `flutter build apk --debug` 可能出现“最后报错但 APK 实际已经生成”的情况。

如果终端最后提示找不到 APK，请继续检查：

```bash
ls -lh android/app/build/outputs/flutter-apk/app-debug.apk
ls -lh android/app/build/outputs/apk/debug/app-debug.apk
```

通常优先使用：

```bash
android/app/build/outputs/flutter-apk/app-debug.apk
```

## 安装到 Android 设备

```bash
adb devices
adb -s <DEVICE_ID> install -r /Users/akabooz/Documents/记账APP_副本/android/app/build/outputs/flutter-apk/app-debug.apk
adb -s <DEVICE_ID> shell monkey -p com.akabooz.bookkeeper.ledger_app -c android.intent.category.LAUNCHER 1
```

## iOS / macOS / Windows / Linux

- 工程目录存在
- 但从当前维护上下文看，最近主要验证的是 Android
- 其他平台需要额外自行补验证

## Release 构建现状

理论命令：

```bash
flutter build apk --release
```

但要注意：

- 当前 Android release 仍使用 debug signing
- 适合内部测试，不适合正式上架发布

## 4. 部署流程（服务器 / 平台、注意事项）

## 当前实际部署方式

- 没有服务器部署
- 没有后端服务发布
- 主要是本地构建 APK，然后通过 ADB 手工安装到 Android 设备

## 版本管理

- 项目已初始化 git 仓库（根目录 `.git`）
- 日常修改后通过 `git add -A && git commit -m "说明"` 提交
- GitHub 仓库：`AKABOOZ/booz-ledger`（Public）
- GitHub CLI (`gh`) 已安装并认证，可用于自动发布版本

## 自动更新功能

- APP 启动时检测 GitHub Releases 最新版本
- 版本对比逻辑在 `lib/services/update_service.dart`
- APK 安装使用 Android 原生 Intent + FileProvider
- GitHub API 地址：`https://api.github.com/repos/AKABOOZ/booz-ledger/releases/latest`

## 发布新版本

```bash
# 1. 修改 pubspec.yaml 中的版本号
# 2. 构建 release APK
flutter build apk --release

# 3. 提交代码
git add -A && git commit -m "v<VERSION> 更新说明"

# 4. 发布到 GitHub Release
gh release create v<VERSION> \
  --repo AKABOOZ/booz-ledger \
  --title "波哥记账 v<VERSION>" \
  --notes "更新内容" \
  android/app/build/outputs/flutter-apk/app-release.apk
```

## 数据同步平台

- 用户自己的 NAS / WebDAV
- 同步逻辑在客户端内执行

## 推荐的 Android 交付流程

1. `flutter pub get`
2. `flutter analyze lib/main.dart`
3. `flutter test`
4. `flutter build apk --debug` 或 `flutter build apk --release`
5. 若 debug 构建出现“假失败”，检查 APK 实际输出目录
6. 用 `adb install -r` 安装到真机
7. 手工验证以下关键路径：
   - 新增支出 / 收入 / 转账
   - 编辑 / 删除流水后的余额修正
   - 高级筛选
   - 导入 / 导出
   - WebDAV 同步 / 恢复
   - 语音识别 / 图片识别（若本次涉及）

## 注意事项

### 1. 当前没有正式发布流水线

- 没有 CI/CD
- 没有统一版本发布规范
- 没有自动化产物归档

### 2. Release 签名需要补

- 当前 release 还没配置正式签名
- 若要上架或对外分发，需要先完善 keystore 与 signingConfig

### 3. 智能能力依赖第三方配置

- 语音、OCR、AI 识别在没有有效 API Key 时不可用
- 这不是代码 bug，而是运行条件不足

### 4. WebDAV 依赖外部环境

- 用户 NAS / WebDAV 配置错误时，同步与恢复会失败
- 需要重点核对：
  - URL
  - 用户名密码
  - 目录权限
  - 服务器是否支持相关方法

### 5. 本地备份策略现状

- 本地只保留最新 `1` 份备份
- NAS 端保留最新 `9` 份
- 这是近期明确确认过的需求，不要误改回去

### 6. 自动更新功能

- APP 启动时自动检测 GitHub Releases 最新版本
- 有新版本弹窗提示，支持下载安装
- GitHub 仓库：`AKABOOZ/booz-ledger`（Public）
- APK 安装使用 Android 原生 Intent + FileProvider

### 7. 账户详情页面

- 点击账户进入详情页，显示 Hero 卡片、折线图和流水列表
- 折线图显示最近30天余额变化，支持滑动查看
- 流水按日期分组，点击可进入编辑页面

### 8. 折线图优化

- 纵轴数字标签移到折线图左侧外面，用动态宽度计算间距
- 纵轴添加5条虚线参考线
- 去掉折线图上的小圆点，只保留手指滑动时的指示器
- 纵坐标数值去掉 ¥ 字符
- 折线图余额计算修复：先加当天交易再记录余额

### 9. 图片识别优化

- 增加"上海银行信用购"→"花呗"的自动分类规则
- 该规则添加在 AI 图片识别的 system prompt 中

### 10. 记一笔键盘优化

- 支持加减法运算（如 50+15=65）
- 修复小数点只能输入一次的bug
- 公式小字显示在金额输入框内，与金额数字左对齐
- 键盘弹出/收起带滑动动画

### 11. 账户管理页面优化

- 新增总资产折线图，方便查看总资产变化趋势
- 资产隐藏时折线图纵坐标和滑动指示器显示 `****`
- 去掉了"xxx个账户"的副标题

### 12. 构建建议

- 日常迭代测试优先用 `flutter build apk --debug`（约 12s）
- Release 构建约 60s，仅用于发布版本
