# 波哥记账APP

一款简洁的个人记账应用，支持语音输入、图片识别、AI 智能分类，数据可同步到 NAS/WebDAV。

## 核心功能

- **流水管理**：支出、收入、转账，自动修正账户余额
- **智能录入**：语音识别（百度）、图片 OCR + AI 理解账单
- **数据同步**：WebDAV 手动/自动同步到 NAS
- **统计分析**：分类排行、筛选统计、时间维度分析
- **账户管理**：现金、银行卡、在线支付、信用卡等多类型支持，支持账户详情页查看余额趋势和流水
- **自动更新**：APP 启动时自动检测 GitHub 新版本并提示更新
- **自定义键盘**：记账页面内置自定义数字键盘，支持加减法运算
- **深色模式**：支持跟随系统 / 手动切换浅色 / 深色，适合夜间使用

## 技术栈

- Flutter (Dart)
- Material 3 UI
- SharedPreferences 本地存储
- 百度语音/OCR + DeepSeek/通义千问 AI

## 构建

```bash
# 安装依赖
flutter pub get

# 构建 debug APK（推荐日常测试，约 12s）
flutter build apk --debug

# 构建 release APK（约 60s）
flutter build apk --release

# APK 输出路径
# android/app/build/outputs/flutter-apk/app-debug.apk
# android/app/build/outputs/flutter-apk/app-release.apk
```

## 安装到手机

```bash
adb devices
adb -s <DEVICE_ID> install -r android/app/build/outputs/flutter-apk/app-debug.apk
```

## 项目结构

```
lib/
├── main.dart              # 主入口 + 首页
├── models/                # 数据模型
├── pages/
│   ├── account_detail_page.dart  # 账户详情页
│   ├── statistics_page.dart
│   ├── settings_page.dart
│   ├── search_page.dart
│   └── entry_form_page.dart
├── services/
│   ├── ai_ledger_service.dart
│   ├── baidu_speech_service.dart
│   ├── baidu_ocr_service.dart
│   ├── ledger_text_parser.dart
│   ├── ledger_store.dart
│   └── update_service.dart
├── store/                 # 状态管理
├── theme/                 # 主题系统（亮色/深色）
│   └── app_theme.dart
├── utils/                 # 工具函数
└── widgets/
    ├── custom_keyboard.dart  # 自定义数字键盘
    ├── amount_display.dart   # 金额显示组件
    └── common_widgets.dart
```

## 版本发布

1. 修改 `pubspec.yaml` 中的版本号
2. `flutter build apk --debug`（日常测试）或 `flutter build apk --release`（发布）
3. 上传 APK 到 GitHub Release

```bash
gh release create v<VERSION> \
  --repo AKABOOZ/booz-ledger \
  --title "波哥记账 v<VERSION>" \
  --notes "更新内容" \
  android/app/build/outputs/flutter-apk/app-debug.apk
```
