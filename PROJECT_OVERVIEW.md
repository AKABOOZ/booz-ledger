# PROJECT_OVERVIEW

## 1. 项目名称、核心功能、目标用户

- 项目名称：`波哥记账` / `ledger_app`
- 应用类型：Flutter 单机记账 App，当前主要面向 Android，工程同时保留 iOS/macOS/Web/Windows/Linux 模板目录。
- 目标用户：
  - 个人记账用户
  - 希望手动记账，但又希望借助截图识别、语音识别提升录入效率的用户
  - 需要把本地账本同步到 NAS / WebDAV 的用户

### 核心功能

- 流水管理
  - 支出 / 收入 / 转账三种流水类型
  - 新增、编辑、删除流水
  - 根据流水自动修正账户余额
- 账户管理
  - 账户新增、编辑、删除
  - 支持现金、储蓄卡、在线支付、信用卡等类型
  - 支持账户图标和还款日等信息
- 分类体系
  - 内置支出 / 收入大类与小类
  - 支持自定义小类
  - 分类管理目前是“基于固定大类追加小类”的模式，不是完全自由配置
- 查询与统计
  - 文本搜索
  - 高级筛选：按类型、时间、分类、账户筛选
  - 分类统计、筛选后统计、分类明细查看
- 数据导入导出
  - 导出本地 JSON 备份
  - 导入 JSON 备份
  - 导入随手记 Excel 数据
- 同步与恢复
  - WebDAV 手动同步
  - 启动时自动同步
  - 从 WebDAV 恢复最新备份
- 智能录入
  - 百度语音识别：语音转文本
  - 百度 OCR：图片文字识别
  - DeepSeek / 通义千问：基于 OCR 文本理解金额、分类、账户、备注等，并回填表单

## 2. 整体架构

### 总体形态

- 主线项目是一个 Flutter 客户端应用。
- 没有自建后端服务。
- 没有独立数据库服务。
- 数据以本地 JSON 结构保存在 `SharedPreferences` 中，并辅以文件备份。
- 外部依赖主要是第三方 HTTP 服务，而不是项目自有后端。

### 架构分层

- UI 层：
  - 几乎全部界面都在 [lib/main.dart](/Users/akabooz/Documents/记账APP_副本/lib/main.dart) 中
  - 使用 `MaterialApp` + 多个 `StatefulWidget` / `StatelessWidget`
- 状态与数据层：
  - `LedgerStore extends ChangeNotifier`
  - 负责加载 / 保存数据、账户余额计算、备份同步、导入导出
- 领域模型：
  - `Account`
  - `LedgerEntry`
  - `CustomCategory`
  - `EntryFormDefaults`
- 外部服务层：
  - `BaiduSpeechService`
  - `BaiduOcrService`
  - `AiLedgerService`
  - WebDAV 相关方法在 `LedgerStore` 内部

### 前端 / 后端 / 数据库结论

- 前端：Flutter（Dart）
- 后端：无项目自有后端
- 数据库：无独立数据库，当前使用 `SharedPreferences` 存整个账本 JSON
- 外部服务：
  - 百度语音识别
  - 百度 OCR
  - DeepSeek API
  - 通义千问 API
  - WebDAV / NAS

## 3. 技术栈清单

### 主线技术栈

- 语言：Dart
- 框架：Flutter
- UI：Material 3
- 本地存储：`shared_preferences ^2.2.3`
- 文件 / 路径：
  - `file_picker ^8.1.2`
  - `path_provider ^2.1.5`
- Excel 导入：`excel ^4.0.6`
- 分享：`share_plus ^12.0.2`
- SVG：`flutter_svg ^2.0.10`
- 网络请求：`http ^1.1.0`
- 权限：`permission_handler ^11.0.0`
- 录音：`flutter_sound ^9.2.13`
- 国际化/时间：`intl ^0.20.2`
- 拼音辅助匹配：`pinyin ^3.3.0`
- 测试：`flutter_test`
- Lint：`flutter_lints ^6.0.0`

### 构建相关版本

- Dart SDK 约束：`^3.11.4`
- Android Gradle Plugin：`8.13.1`
- Kotlin Android Plugin：`2.2.20`
- Java 目标版本：`17`
- Android `compileSdk`：`36`
- Android `targetSdk`：`36`
- Android 包名：`com.akabooz.bookkeeper.ledger_app`

### 非主线 / 历史遗留技术栈

仓库根目录同时存在一套 React + TypeScript + Vite 脚手架：

- React 18
- TypeScript 5
- Vite 6
- TailwindCSS 3
- Zustand
- React Router

这套前端从当前仓库状态看不是主线记账 App 的运行入口，主线仍然是 Flutter。后续 AI 接手时不要把 `src/` 误判为当前线上主应用。

## 4. 目录结构说明

### 当前应优先关注的目录

- [lib](/Users/akabooz/Documents/记账APP_副本/lib)
  - Flutter 主代码目录
  - 当前几乎所有业务、UI、状态、服务都集中在 `main.dart`
- [lib/services](/Users/akabooz/Documents/记账APP_副本/lib/services)
  - 服务层：AI、语音、OCR、文本解析、更新检测
- [lib/pages](/Users/akabooz/Documents/记账APP_副本/lib/pages)
  - 页面：统计、设置、搜索、记账表单
- [assets](/Users/akabooz/Documents/记账APP_副本/assets)
  - 图标、背景图、字体资源
- [android](/Users/akabooz/Documents/记账APP_副本/android)
  - Android 工程
  - 当前 Android 构建、安装、调试都主要围绕这里

### 明显的历史遗留 / 非主线目录

- [src](/Users/akabooz/Documents/记账APP_副本/src)
  - React/Vite 源码，非当前 Flutter 主应用
- [public](/Users/akabooz/Documents/记账APP_副本/public)
  - React/Vite 公共资源
- [dist](/Users/akabooz/Documents/记账APP_副本/dist)
  - React/Vite 构建产物
- [node_modules](/Users/akabooz/Documents/记账APP_副本/node_modules)
  - React/Vite 依赖目录
- [flutter_app](/Users/akabooz/Documents/记账APP_副本/flutter_app)
  - 疑似旧版 Flutter 副本 / 历史快照，不是当前主线入口
- [clean_version](/Users/akabooz/Documents/记账APP_副本/clean_version)
  - 疑似“清爽版”或历史归档，不是当前主线入口
- [build](/Users/akabooz/Documents/记账APP_副本/build)
  - 本地 Flutter 构建产物，不应手改

### 单文件现状

- 当前项目业务代码高度集中在 [lib/main.dart](/Users/akabooz/Documents/记账APP_副本/lib/main.dart)
- 接手者应预期：
  - 阅读成本高
  - 改动时容易引起连锁影响
  - 后续较大迭代建议逐步拆分

## 5. 当前进度

### 已完成功能

- 基础记账主流程
  - 首页 / 流水 / 统计 / 账户管理主骨架
  - 支出、收入、转账录入
  - 账户余额随流水自动联动
- 分类体系
  - 内置分类
  - 自定义分类追加
- 数据操作
  - 本地持久化
  - JSON 备份导入导出
  - 随手记 Excel 导入
- 统计分析
  - 分类排行
  - 分类明细
  - 筛选后统计
- 搜索筛选
  - 文本搜索
  - 高级筛选
  - 最近一次需求已加入：
    - 分类“取消全选”
    - 账户“取消全选”
    - 仅在内部选项全选时显示按钮
- 智能辅助录入
  - 语音输入
  - 图片 OCR
  - AI 理解账单并回填
- 数据同步
  - WebDAV 手动同步
  - 自动同步
  - 从 NAS 恢复
- 备份治理
  - 最近一次需求已处理：
    - 本地备份只保留 `1` 份
    - NAS 仍保留 `9` 份
    - WebDAV 同步产生的本地中间备份会自动删除
- 自动更新
  - APP 启动时自动检测 GitHub Releases 新版本
  - 下载 APK 并触发系统安装界面
  - 设置页手动检查更新
  - 版本对比逻辑（major.minor.patch）
- 语音记账优化
  - 新增大量支出分类别名匹配规则
  - 覆盖更多日常用语（快递、房贷、AI工具等）
- 账户详情页面
  - Hero 卡片显示账户名称、当前余额、最近30天余额变化折线图
  - 折线图支持滑动查看不同日期的余额数值
  - 流水列表按日期分组显示，点击可进入编辑页面
- 图片识别优化
  - 增加"上海银行信用购"→"花呗"的自动分类规则
- 记一笔键盘优化
  - 支持加减法运算（如 50+15=65）
  - 修复小数点只能输入一次的bug
  - 公式小字显示在金额输入框内，与金额数字左对齐
- 账户管理页面优化
  - 新增总资产折线图，方便查看总资产变化趋势
  - 资产隐藏时折线图纵坐标和滑动指示器显示 `****`
- 折线图优化
  - 纵坐标数字标签移到折线图左侧外面
  - 纵轴添加5条虚线参考线
  - 纵坐标数值统一使用"W"代替"万"

### 待完成功能 / 可继续演进项

以下内容没有在代码里看到完整闭环，或明显还有优化空间：

- 代码拆分与模块化
  - `lib/main.dart` 过大，尚未拆分为 feature/module
- 更稳健的数据存储
  - 目前仍是 `SharedPreferences + JSON`，数据规模增大后风险上升
- 更完整的测试体系
  - 目前没有成体系的单元测试 / 集成测试 / 回归测试
- 更正式的发布流程
  - Android release 仍使用 debug signing
  - 没有正式 CI/CD
- iOS / 桌面端实机验证
  - 工程模板在，但从当前上下文看主要只验证了 Android
- 分类管理能力
  - 当前提示”本版本暂不开放编辑”，说明分类管理仍有限制
- 自动更新方案优化
  - 当前使用 GitHub Releases（源码公开）
  - 可考虑迁移到蒲公英/fir.im 等国内平台（下载更快、源码不暴露）
- 收入/支出类型选择器溢出
  - 使用 `ClipRect` 裁剪溢出内容，但根本原因是 `childAspectRatio: 1` 导致格子高度不足
  - 后续可考虑优化网格布局或减小图标/文字尺寸

## 6. 已知问题 / 坑点（必须看）

### 1. 代码集中在单文件，维护成本高

- 几乎所有业务都在 [lib/main.dart](/Users/akabooz/Documents/记账APP_副本/lib/main.dart)
- 页面、状态、服务、模型混在一起
- 改动局部功能时，要谨慎搜索相关逻辑，避免遗漏

### 2. 仓库混有多套工程，容易误判

- 根目录同时有 Flutter 主工程、React/Vite 工程、旧版 Flutter 副本、clean 版本目录
- 当前实际应维护的是：
  - 根目录 Flutter 工程
  - 入口是 `lib/main.dart`
- `src/`、`flutter_app/`、`clean_version/` 很容易误导新的 AI 或新同事

### 3. Android debug 构建常出现“假失败”

- `flutter build apk --debug` 可能最终报：
  - “Gradle build failed to produce an .apk file”
- 但 APK 实际已经产出，通常在：
  - `android/app/build/outputs/flutter-apk/app-debug.apk`
  - 或 `android/app/build/outputs/apk/debug/app-debug.apk`
- 不要只看 Flutter 终端最后一句话就判断构建失败

### 4. Release 配置还不正式

- [android/app/build.gradle.kts](/Users/akabooz/Documents/记账APP_副本/android/app/build.gradle.kts) 中 release 仍使用 debug signing
- 这意味着：
  - 可用于内部安装测试
  - 不适合作为正式商店发布配置

### 5. 数据存储方案存在规模风险

- 主账本保存在 `SharedPreferences` 的一个大 JSON 字符串里
- 当流水很多时，性能、读写耗时、数据损坏恢复能力都不如数据库方案
- 这是当前最重要的中长期技术债之一

### 6. 本地备份历史上会膨胀

- 之前本地 `app_flutter/ledger_backup_*.json` 会长期累积，导致 Android “用户数据”暴涨
- 当前已修复为本地只保留 `1` 份
- NAS 仍保留 `9` 份
- 但接手者要知道：这个问题曾真实出现过，后续不要回退逻辑

### 7. Debug 版安装后“用户数据”看起来偏大，不全是脏数据

- 手机上的“用户数据”并不全是账本备份
- debug 版 Flutter 本身会在应用私有目录里产生较大的运行资源
- 之前清理后仍约 `100MB+`，其中大头不是用户账本，而是 debug 运行资产

### 8. Analyzer 目前有历史告警

- `flutter analyze lib/main.dart` 当前存在一批 info / warning
- 主要包括：
  - `use_build_context_synchronously`
  - `deprecated_member_use`
  - `non_constant_identifier_names`
  - `unused_local_variable`
- 当前不是零告警仓库，新改动要避免继续放大

### 9. README 不是当前项目说明

- 根目录 [README.md](/Users/akabooz/Documents/记账APP_副本/README.md) 还是 React + Vite 模板内容
- 不能作为当前 Flutter 记账项目的真实文档依据

### 10. 没有自建后端，所以很多能力依赖第三方配置

- OCR、语音、AI 识别都依赖外部 API Key
- WebDAV 依赖 NAS / WebDAV 服务配置正确
- 这些配置大多是”运行时在 App 设置页输入”，而不是标准 `.env` 文件

### 11. APP 启动时背景曾黑屏一下（已修复）

- 问题：冷启动或后台恢复时，首页透明容器区域显示为黑色，约半秒后背景图 `bg.jpg` 加载完才恢复
- 根因：Scaffold 和所有页面容器背景全透明，依赖背景图一张图打底，图片解码延迟时透出黑色
- 修复方案（已落地）：
  - Android `NormalTheme` 窗口背景色改为 `#FFF8FAF6`
  - Flutter body Stack 中背景图下方增加后备色层
  - 页面容器保持透明，不影响背景图显示
