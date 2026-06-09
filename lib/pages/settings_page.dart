import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/services/ai_ledger_service.dart';
import 'package:ledger_app/services/import_helpers.dart';
import 'package:ledger_app/services/update_service.dart';
import 'package:ledger_app/store/ledger_store.dart';
import 'package:ledger_app/utils/helpers.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isTestingConnection = false;
  bool _isRestoringFromWebdav = false;
  bool _isSyncingToWebdav = false;
  bool _hasLoadedSettings = false;
  AiProvider _selectedAiProvider = AiProvider.deepSeek;
  String _appVersion = '1.0.0';
  final _apiKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _deepSeekApiKeyController = TextEditingController();
  final _deepSeekModelController = TextEditingController();
  final _qwenApiKeyController = TextEditingController();
  final _qwenModelController = TextEditingController();
  final _webdavUrlController = TextEditingController();
  final _webdavUsernameController = TextEditingController();
  final _webdavPasswordController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedSettings) {
      return;
    }
    _loadAppVersion();
    final store = LedgerScope.of(context);
    _apiKeyController.text = store.baiduApiKey ?? '';
    _secretKeyController.text = store.baiduSecretKey ?? '';
    _selectedAiProvider = store.aiProvider;
    _deepSeekApiKeyController.text = store.deepSeekApiKey ?? '';
    _deepSeekModelController.text = store.deepSeekModel;
    _qwenApiKeyController.text = store.qwenApiKey ?? '';
    _qwenModelController.text = store.qwenModel;
    _ensureProviderDefaults(AiProvider.deepSeek);
    _ensureProviderDefaults(AiProvider.qwen);
    _webdavUrlController.text = store.webdavUrl ?? '';
    _webdavUsernameController.text = store.webdavUsername ?? '';
    _webdavPasswordController.text = store.webdavPassword ?? '';
    _hasLoadedSettings = true;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _secretKeyController.dispose();
    _deepSeekApiKeyController.dispose();
    _deepSeekModelController.dispose();
    _qwenApiKeyController.dispose();
    _qwenModelController.dispose();
    _webdavUrlController.dispose();
    _webdavUsernameController.dispose();
    _webdavPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    final version = await UpdateService.getCurrentVersion();
    if (mounted) {
      setState(() => _appVersion = version);
    }
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (!mounted) return;

    if (updateInfo == null) {
      if (context.mounted) {
        showSnack(context, '已是最新版本');
      }
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(updateInfo: updateInfo),
    );
  }

  Widget _buildMainPage() {
    final store = LedgerScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingCard(
          icon: Icons.mic,
          title: '语音识别',
          description: '百度智能云API配置',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => _VoiceSettingsPage()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildSettingCard(
          icon: Icons.auto_awesome,
          title: 'AI识别',
          description: '${store.aiProvider.label}图片记账增强',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => _AiSettingsPage()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildSettingCard(
          icon: Icons.cloud,
          title: '数据同步',
          description: 'WebDAV同步和备份',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => _SyncSettingsPage()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildSettingCard(
          icon: Icons.storage,
          title: '数据管理',
          description: '导入导出备份数据',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => _DataSettingsPage()),
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '工资收入打码',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('开启后，工资收入流水金额显示为 ****'),
              value: store.isSalaryIncomeMasked,
              onChanged: (value) => _toggleSalaryIncomeMasked(store, value),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingCard(
          icon: Icons.system_update,
          title: '检查更新',
          description: '当前版本：v$_appVersion',
          onTap: () => _checkForUpdate(context),
        ),
      ],
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF167C80).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF167C80), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16211F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF65736F),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF65736F)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Color(0xFF65736F)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF16211F),
          ),
        ),
      ],
    );
  }

  // 语音识别设置页面
  Widget _VoiceSettingsPage() {
    final store = LedgerScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('语音识别')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '百度智能云API配置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(labelText: 'API Key'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _secretKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Secret Key',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        await store.setBaiduApiKey(
                          _apiKeyController.text.isEmpty
                              ? null
                              : _apiKeyController.text,
                        );
                        await store.setBaiduSecretKey(
                          _secretKeyController.text.isEmpty
                              ? null
                              : _secretKeyController.text,
                        );
                        if (mounted) {
                          showSnack(context, '配置已保存');
                        }
                      },
                      child: const Text('保存配置'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _AiSettingsPage() {
    final store = LedgerScope.of(context);
    final selectedProvider = _selectedAiProvider;
    final activeModel = _modelControllerFor(selectedProvider).text.trim();
    final activeApiKey = _apiKeyControllerFor(selectedProvider).text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('AI识别')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前生效配置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${selectedProvider.providerSummary}\n图片识别仍然会先走百度OCR，再交给当前服务商做理解。',
                      style: const TextStyle(color: Color(0xFF65736F)),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '语音识别AI增强',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        '开启后，语音会先转文字，再交给当前AI服务商补全类型、金额、分类和账户。',
                      ),
                      value: store.isVoiceAiEnabled,
                      onChanged: (value) async {
                        await store.setVoiceAiEnabled(value);
                        if (!mounted) {
                          return;
                        }
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F7F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前服务商：${selectedProvider.label}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16211F),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '当前模型：${activeModel.isEmpty ? selectedProvider.model : activeModel}',
                            style: const TextStyle(color: Color(0xFF65736F)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '语音AI增强：${store.isVoiceAiEnabled ? '已开启' : '已关闭'}',
                            style: const TextStyle(color: Color(0xFF65736F)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AiProvider>(
                      initialValue: selectedProvider,
                      decoration: const InputDecoration(labelText: '当前AI服务商'),
                      items: [
                        for (final provider in AiProvider.values)
                          DropdownMenuItem<AiProvider>(
                            value: provider,
                            child: Text(provider.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedAiProvider = value;
                          _ensureProviderDefaults(value);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _modelControllerFor(selectedProvider),
                      decoration: InputDecoration(
                        labelText: '${selectedProvider.label} 模型名',
                        hintText: selectedProvider.model,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _apiKeyControllerFor(selectedProvider),
                      decoration: InputDecoration(
                        labelText: selectedProvider.apiKeyLabel,
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed:
                                  _isTestingConnection || activeApiKey.isEmpty
                                  ? null
                                  : () async {
                                      await _testAiConnection(store);
                                    },
                              child: _isTestingConnection
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('测试连接'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: () async {
                                await _saveAiSettings(store);
                              },
                              child: const Text('保存配置'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '提示：当前只展示正在生效的服务商配置；切换服务商后，输入框会自动切到对应的模型和 API Key。语音AI增强关闭时，语音仍会按原来的本地规则解析。',
                      style: TextStyle(fontSize: 12, color: Color(0xFF65736F)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAiSettings(LedgerStore store) async {
    _ensureProviderDefaults(AiProvider.deepSeek);
    _ensureProviderDefaults(AiProvider.qwen);
    final deepSeekModel = _deepSeekModelController.text.trim();
    final qwenModel = _qwenModelController.text.trim();
    await store.setAiProvider(_selectedAiProvider);
    await store.setDeepSeekApiKey(
      _deepSeekApiKeyController.text.trim().isEmpty
          ? null
          : _deepSeekApiKeyController.text.trim(),
    );
    await store.setDeepSeekModel(deepSeekModel);
    await store.setQwenApiKey(
      _qwenApiKeyController.text.trim().isEmpty
          ? null
          : _qwenApiKeyController.text.trim(),
    );
    await store.setQwenModel(qwenModel);
    if (!mounted) {
      return;
    }
    showSnack(context, 'AI识别配置已保存');
    setState(() {});
  }

  Future<void> _testAiConnection(LedgerStore store) async {
    final provider = _selectedAiProvider;
    _ensureProviderDefaults(provider);
    final apiKey = _apiKeyControllerFor(provider).text.trim();
    final model = _modelControllerFor(provider).text.trim();
    if (apiKey.isEmpty) {
      showSnack(context, '请先填写${provider.label} API Key');
      return;
    }
    setState(() {
      _isTestingConnection = true;
    });
    try {
      final error = await AiLedgerService(
        provider: provider,
        apiKey: apiKey,
        model: model,
      ).testConnection();
      if (!mounted) {
        return;
      }
      if (error == null) {
        showSnack(context, '${provider.label} 连接成功');
      } else {
        showSnack(context, '${provider.label} 连接失败：$error');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      showSnack(context, '${provider.label} 连接失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  TextEditingController _apiKeyControllerFor(AiProvider provider) {
    return provider == AiProvider.deepSeek
        ? _deepSeekApiKeyController
        : _qwenApiKeyController;
  }

  TextEditingController _modelControllerFor(AiProvider provider) {
    return provider == AiProvider.deepSeek
        ? _deepSeekModelController
        : _qwenModelController;
  }

  void _ensureProviderDefaults(AiProvider provider) {
    final controller = _modelControllerFor(provider);
    final normalized = controller.text.trim();
    if (normalized.isEmpty ||
        (provider == AiProvider.deepSeek && normalized == 'deepseek-chat') ||
        (provider == AiProvider.qwen && normalized == 'qwen-plus')) {
      controller.text = provider.model;
    }
  }

  // 数据同步设置页面
  Widget _SyncSettingsPage() {
    final store = LedgerScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('数据同步')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WebDAV 同步设置',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '配置 NAS 地址后，可以手动同步、自动备份或从 WebDAV 恢复数据。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7A8783),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _webdavUrlController,
                          decoration: const InputDecoration(
                            labelText: '服务器地址',
                            hintText: 'https://xxx.zspace.cn/dav/',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _webdavUsernameController,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            hintText: 'admin',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _webdavPasswordController,
                          decoration: const InputDecoration(
                            labelText: '密码',
                            hintText: '••••••',
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '自动同步备份',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '开启后，App 启动时会自动备份到 WebDAV',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF7A8783),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: store.isWebdavAutoSyncEnabled,
                              onChanged: (value) async {
                                setState(() {});
                                await store.setWebdavAutoSyncEnabled(value);
                                if (!mounted) return;
                                showSnack(
                                  context,
                                  value ? '已开启自动同步备份' : '已关闭自动同步备份',
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6FAF8),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color:
                                      (store.lastSyncSuccess == true
                                              ? const Color(0xFF2E8B57)
                                              : const Color(0xFF7A8783))
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  store.lastSyncSuccess == true
                                      ? Icons.cloud_done_rounded
                                      : Icons.cloud_outlined,
                                  size: 18,
                                  color: store.lastSyncSuccess == true
                                      ? const Color(0xFF2E8B57)
                                      : const Color(0xFF7A8783),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '同步状态',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF7A8783),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      store.lastSyncTime == null
                                          ? '尚未同步'
                                          : '上次同步 ${_formatSyncTime(store.lastSyncTime!)}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: store.lastSyncTime == null
                                            ? const Color(0xFF8E9A96)
                                            : (store.lastSyncSuccess == true
                                                  ? const Color(0xFF2E8B57)
                                                  : const Color(0xFFC95858)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '同步操作',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '先测试连接并保存配置，再按需手动同步或恢复。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7A8783),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                onPressed: _isTestingConnection
                                    ? null
                                    : () => _testWebdavConnection(store),
                                child: _isTestingConnection
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('测试连接'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  await store.setWebdavConfig(
                                    _webdavUrlController.text.isEmpty
                                        ? null
                                        : _webdavUrlController.text,
                                    _webdavUsernameController.text.isEmpty
                                        ? null
                                        : _webdavUsernameController.text,
                                    _webdavPasswordController.text.isEmpty
                                        ? null
                                        : _webdavPasswordController.text,
                                  );
                                  if (mounted) {
                                    showSnack(context, '配置已保存');
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                child: const Text('保存配置'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                onPressed: _isSyncingToWebdav
                                    ? null
                                    : () => _syncToWebdav(store),
                                icon: _isSyncingToWebdav
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.cloud_upload_rounded),
                                label: const Text('手动同步'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                onPressed: _isRestoringFromWebdav
                                    ? null
                                    : () => _restoreFromWebdav(store),
                                icon: _isRestoringFromWebdav
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.cloud_download_rounded),
                                label: const Text('从 NAS 恢复数据'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 数据管理设置页面
  Widget _DataSettingsPage() {
    final store = LedgerScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: _isExporting
                          ? null
                          : () => _exportBackup(store),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: const Text('导出备份数据'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: _isImporting
                          ? null
                          : () => _importBackup(store),
                      icon: _isImporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: const Text('导入备份数据'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: _isImporting ? null : _importSuiShouJiExcel,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.table_chart),
                      label: const Text('导入随手记数据'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(child: _buildMainPage()),
    );
  }

  Future<void> _toggleSalaryIncomeMasked(LedgerStore store, bool value) async {
    if (value) {
      await store.setSalaryIncomeMasked(true);
      return;
    }

    var inputPassword = '';
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关闭工资收入打码'),
        content: TextField(
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '请输入密码'),
          onChanged: (value) => inputPassword = value,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(inputPassword),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (!mounted || password == null) {
      return;
    }
    if (password == '0402') {
      await store.setSalaryIncomeMasked(false);
      return;
    }
    showSnack(context, '密码错误');
  }

  Future<void> _testWebdavConnection(LedgerStore store) async {
    setState(() => _isTestingConnection = true);
    try {
      final success = await store.testWebdavConnection();
      if (mounted) {
        showSnack(
          context,
          success ? '连接成功' : (store.lastWebdavError ?? '连接失败，请检查配置'),
        );
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, '连接失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingConnection = false);
      }
    }
  }

  Future<void> _restoreFromWebdav(LedgerStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从 NAS 恢复数据？'),
        content: const Text('恢复会覆盖当前所有账户、流水和自定义分类，确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isRestoringFromWebdav = true);
    try {
      final success = await store.restoreFromWebdav();
      if (mounted) {
        if (success) {
          showSnack(context, '恢复成功');
        } else {
          showSnack(context, store.lastWebdavError ?? '恢复失败，请检查配置和网络连接');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, '恢复失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoringFromWebdav = false);
      }
    }
  }

  Future<void> _syncToWebdav(LedgerStore store) async {
    setState(() => _isSyncingToWebdav = true);
    try {
      final success = await store.syncToWebdav();
      if (!mounted) {
        return;
      }
      if (success) {
        showSnack(context, '同步成功');
      } else {
        showSnack(context, store.lastWebdavError ?? '同步失败，请检查配置和网络连接');
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, '同步失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingToWebdav = false);
      }
    }
  }

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  Future<void> _importSuiShouJiExcel() async {
    final store = LedgerScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入随手记数据？'),
        content: const Text('导入会覆盖当前账户、流水和自定义分类，并按 Excel 里的支出、收入、转账重新计算账户余额。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('选择 Excel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) {
      return;
    }

    setState(() => _isImporting = true);
    try {
      final file = picked.files.single;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final imported = parseSuiShouJiExcel(bytes);
      if (!mounted) {
        return;
      }
      if (imported.summary.entryCount == 0) {
        showSnack(context, '没有识别到可导入的支出、收入或转账');
        return;
      }
      await store.replaceImportedData(imported);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入完成'),
          content: Text(
            [
              '账户：${imported.summary.accountCount} 个',
              '支出：${imported.summary.expenseCount} 条',
              '收入：${imported.summary.incomeCount} 条',
              '转账：${imported.summary.transferCount} 条',
              '跳过：${imported.summary.skippedCount} 条',
            ].join('\n'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showSnack(context, '导入失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _exportBackup(LedgerStore store) async {
    setState(() => _isExporting = true);
    try {
      final file = await store.exportBackupData();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导出成功'),
          content: Text('备份文件已生成，您可以选择分享或保存到其他位置。'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Share.shareXFiles(
                  [XFile(file.path)],
                  subject: '记账APP备份数据',
                  text: '这是记账APP的备份数据，请妥善保存。',
                );
              },
              child: const Text('分享'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showSnack(context, '导出失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _importBackup(LedgerStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入备份数据？'),
        content: const Text('导入会覆盖当前所有账户、流水和自定义分类，确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
    );

    if (picked == null || picked.files.isEmpty || !mounted) return;

    setState(() => _isImporting = true);
    try {
      final file = picked.files.single;
      await store.importBackupData(file.path!);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入完成'),
          content: const Text('备份数据已成功导入'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showSnack(context, '导入失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.updateInfo});
  final UpdateInfo updateInfo;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    final releaseNotes = widget.updateInfo.body ?? '暂无更新说明';

    return AlertDialog(
      title: Text('发现新版本 v${widget.updateInfo.version}'),
      content: _isDownloading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('正在下载...'),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text('${(_progress * 100).toInt()}%'),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '更新内容：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(releaseNotes),
                ],
              ),
            ),
      actions: _isDownloading
          ? null
          : [
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await UpdateService.skipVersion(widget.updateInfo.version);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('稍后再说'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _download,
                  child: const Text('立即更新'),
                ),
              ),
            ],
    );
  }

  Future<void> _download() async {
    final url = widget.updateInfo.downloadUrl;
    if (url == null) {
      if (mounted) {
        showSnack(context, '未找到下载链接');
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    try {
      await UpdateService.downloadAndInstall(
        url,
        widget.updateInfo.version,
        (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        showSnack(context, '下载失败：$e');
      }
    }
  }
}

