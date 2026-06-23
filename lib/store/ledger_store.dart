import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/models/ledger_entry.dart';

class LedgerStore extends ChangeNotifier {
  static const _storageKey = 'ledger_app_state_v1';
  static const _apiKey = 'baidu_api_key';
  static const _secretKey = 'baidu_secret_key';
  static const _aiProviderKey = 'ai_provider';
  static const _deepSeekApiKeyKey = 'deepseek_api_key';
  static const _deepSeekModelKey = 'deepseek_model';
  static const _qwenApiKeyKey = 'qwen_api_key';
  static const _qwenModelKey = 'qwen_model';
  static const _voiceAiEnabledKey = 'voice_ai_enabled';
  static const _salaryIncomeMaskedKey = 'salary_income_masked';
  static const _entryFormDefaultsKey = 'entry_form_defaults_v1';
  static const _webdavAutoSyncEnabledKey = 'webdav_auto_sync_enabled';
  static const _themeModeKey = 'theme_mode';

  final List<Account> _accounts = [];
  final List<LedgerEntry> _entries = [];
  final List<CustomCategory> _customCategories = [];
  SharedPreferences? _prefs;
  Future<void> _pendingPersist = Future<void>.value();
  bool _isLoading = true;
  bool _isAmountHidden = true;
  bool _isSalaryIncomeMasked = true;
  bool _isWebdavAutoSyncEnabled = false;
  int _themeMode = 0; // 0=system, 1=light, 2=dark
  bool _isVoiceAiEnabled = true;
  final Map<LedgerEntryType, EntryFormDefaults> _entryFormDefaults = {};
  String? _baiduApiKey;
  String? _baiduSecretKey;
  AiProvider _aiProvider = AiProvider.deepSeek;
  String? _deepSeekApiKey;
  String _deepSeekModel = AiProvider.deepSeek.model;
  String? _qwenApiKey;
  String _qwenModel = AiProvider.qwen.model;
  String? _webdavUrl;
  String? _webdavUsername;
  String? _webdavPassword;
  DateTime? _lastSyncTime;
  bool? _lastSyncSuccess;
  String? _lastWebdavError;

  bool get isLoading => _isLoading;
  bool get isAmountHidden => _isAmountHidden;
  bool get isSalaryIncomeMasked => _isSalaryIncomeMasked;
  bool get isWebdavAutoSyncEnabled => _isWebdavAutoSyncEnabled;
  int get themeMode => _themeMode;
  bool get isVoiceAiEnabled => _isVoiceAiEnabled;
  List<Account> get accounts => List.unmodifiable(_accounts);
  EntryFormDefaults defaultsFor(LedgerEntryType type) {
    return _entryFormDefaults[type] ?? const EntryFormDefaults();
  }

  String? get baiduApiKey => _baiduApiKey;
  String? get baiduSecretKey => _baiduSecretKey;
  AiProvider get aiProvider => _aiProvider;
  String? get deepSeekApiKey => _deepSeekApiKey;
  String get deepSeekModel => _deepSeekModel;
  String? get qwenApiKey => _qwenApiKey;
  String get qwenModel => _qwenModel;
  String? get selectedAiApiKey => switch (_aiProvider) {
    AiProvider.deepSeek => _deepSeekApiKey,
    AiProvider.qwen => _qwenApiKey,
  };
  String get selectedAiModel => switch (_aiProvider) {
    AiProvider.deepSeek => _deepSeekModel,
    AiProvider.qwen => _qwenModel,
  };
  String? get webdavUrl => _webdavUrl;
  String? get webdavUsername => _webdavUsername;
  String? get webdavPassword => _webdavPassword;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool? get lastSyncSuccess => _lastSyncSuccess;
  String? get lastWebdavError => _lastWebdavError;

  void setAmountHidden(bool value) {
    _isAmountHidden = value;
    notifyListeners();
  }

  Future<void> setSalaryIncomeMasked(bool value) async {
    _isSalaryIncomeMasked = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_salaryIncomeMaskedKey, value);
    notifyListeners();
  }

  Future<void> setWebdavAutoSyncEnabled(bool value) async {
    _isWebdavAutoSyncEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_webdavAutoSyncEnabledKey, value);
    notifyListeners();
  }

  Future<void> setThemeMode(int value) async {
    _themeMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, value);
    notifyListeners();
  }

  Future<void> setVoiceAiEnabled(bool value) async {
    _isVoiceAiEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceAiEnabledKey, value);
    notifyListeners();
  }

  Future<void> setBaiduApiKey(String? value) async {
    _baiduApiKey = value;
    final prefs = await SharedPreferences.getInstance();
    if (value != null) {
      await prefs.setString(_apiKey, value);
    } else {
      await prefs.remove(_apiKey);
    }
    notifyListeners();
  }

  Future<void> setBaiduSecretKey(String? value) async {
    _baiduSecretKey = value;
    final prefs = await SharedPreferences.getInstance();
    if (value != null) {
      await prefs.setString(_secretKey, value);
    } else {
      await prefs.remove(_secretKey);
    }
    notifyListeners();
  }

  Future<void> setDeepSeekApiKey(String? value) async {
    _deepSeekApiKey = value;
    final prefs = await SharedPreferences.getInstance();
    if (value != null) {
      await prefs.setString(_deepSeekApiKeyKey, value);
    } else {
      await prefs.remove(_deepSeekApiKeyKey);
    }
    notifyListeners();
  }

  Future<void> setDeepSeekModel(String value) async {
    _deepSeekModel = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deepSeekModelKey, value);
    notifyListeners();
  }

  Future<void> setAiProvider(AiProvider value) async {
    _aiProvider = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiProviderKey, value.storageValue);
    notifyListeners();
  }

  Future<void> setQwenApiKey(String? value) async {
    _qwenApiKey = value;
    final prefs = await SharedPreferences.getInstance();
    if (value != null) {
      await prefs.setString(_qwenApiKeyKey, value);
    } else {
      await prefs.remove(_qwenApiKeyKey);
    }
    notifyListeners();
  }

  Future<void> setQwenModel(String value) async {
    _qwenModel = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qwenModelKey, value);
    notifyListeners();
  }

  static String _normalizeStoredModel(AiProvider provider, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return provider.model;
    }
    if (provider == AiProvider.deepSeek && trimmed == 'deepseek-chat') {
      return provider.model;
    }
    if (provider == AiProvider.qwen && trimmed == 'qwen-plus') {
      return provider.model;
    }
    return trimmed;
  }

  Future<void> setWebdavConfig(
    String? url,
    String? username,
    String? password,
  ) async {
    _webdavUrl = url;
    _webdavUsername = username;
    _webdavPassword = password;
    final prefs = await SharedPreferences.getInstance();
    if (url != null) {
      await prefs.setString('webdav_url', url);
    } else {
      await prefs.remove('webdav_url');
    }
    if (username != null) {
      await prefs.setString('webdav_username', username);
    } else {
      await prefs.remove('webdav_username');
    }
    if (password != null) {
      await prefs.setString('webdav_password', password);
    } else {
      await prefs.remove('webdav_password');
    }
    notifyListeners();
  }

  Future<void> setSyncStatus(DateTime time, bool success) async {
    _lastSyncTime = time;
    _lastSyncSuccess = success;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', time.toIso8601String());
    await prefs.setBool('last_sync_success', success);
    notifyListeners();
  }

  List<ExpenseCategoryGroup> get expenseCategoryGroups {
    return defaultExpenseCategoryGroups.map((group) {
      return ExpenseCategoryGroup(group.name, [
        ...group.children,
        ..._customCategories
            .where((item) {
              return item.type == LedgerEntryType.expense &&
                  item.groupName == group.name;
            })
            .map((item) => ExpenseCategoryItem(item.name, item.iconKey)),
      ]);
    }).toList();
  }

  List<IncomeCategoryGroup> get incomeCategoryGroups {
    return defaultIncomeCategoryGroups.map((group) {
      return IncomeCategoryGroup(group.name, [
        ...group.children,
        ..._customCategories
            .where((item) {
              return item.type == LedgerEntryType.income &&
                  item.groupName == group.name;
            })
            .map((item) => ExpenseCategoryItem(item.name, item.iconKey)),
      ]);
    }).toList();
  }

  List<LedgerEntry> get entries {
    final sorted = [..._entries]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return List.unmodifiable(sorted);
  }

  int get totalBalanceInCents {
    return _accounts.fold(0, (sum, account) => sum + account.balanceInCents);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final accounts = decoded['accounts'] as List<Object?>? ?? [];
      final entries = decoded['entries'] as List<Object?>? ?? [];
      final customCategories =
          decoded['customCategories'] as List<Object?>? ?? [];
      _accounts
        ..clear()
        ..addAll(
          accounts.map((item) {
            return Account.fromJson((item as Map).cast<String, Object?>());
          }),
        );
      _entries
        ..clear()
        ..addAll(
          entries.map((item) {
            return LedgerEntry.fromJson((item as Map).cast<String, Object?>());
          }),
        );
      _customCategories
        ..clear()
        ..addAll(
          customCategories.map((item) {
            return CustomCategory.fromJson(
              (item as Map).cast<String, Object?>(),
            );
          }),
        );
    }
    _baiduApiKey = prefs.getString(_apiKey);
    _baiduSecretKey = prefs.getString(_secretKey);
    _aiProvider = AiProviderX.fromStorageValue(prefs.getString(_aiProviderKey));
    _deepSeekApiKey = prefs.getString(_deepSeekApiKeyKey);
    _deepSeekModel = _normalizeStoredModel(
      AiProvider.deepSeek,
      prefs.getString(_deepSeekModelKey),
    );
    _qwenApiKey = prefs.getString(_qwenApiKeyKey);
    _qwenModel = _normalizeStoredModel(
      AiProvider.qwen,
      prefs.getString(_qwenModelKey),
    );
    _isVoiceAiEnabled = prefs.getBool(_voiceAiEnabledKey) ?? true;
    _isSalaryIncomeMasked = prefs.getBool(_salaryIncomeMaskedKey) ?? true;
    _isWebdavAutoSyncEnabled =
        prefs.getBool(_webdavAutoSyncEnabledKey) ?? false;
    _themeMode = prefs.getInt(_themeModeKey) ?? 0;
    final rawDefaults = prefs.getString(_entryFormDefaultsKey);
    if (rawDefaults != null) {
      final decoded = jsonDecode(rawDefaults) as Map<String, Object?>;
      _entryFormDefaults
        ..clear()
        ..addEntries(
          decoded.entries.map((entry) {
            return MapEntry(
              LedgerEntryType.values.byName(entry.key),
              EntryFormDefaults.fromJson(
                (entry.value as Map).cast<String, Object?>(),
              ),
            );
          }),
        );
    }
    _webdavUrl = prefs.getString('webdav_url');
    _webdavUsername = prefs.getString('webdav_username');
    _webdavPassword = prefs.getString('webdav_password');
    final lastSyncTimeStr = prefs.getString('last_sync_time');
    if (lastSyncTimeStr != null) {
      _lastSyncTime = DateTime.parse(lastSyncTimeStr);
    }
    _lastSyncSuccess = prefs.getBool('last_sync_success');
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addCustomCategory(CustomCategory category) async {
    if (categoryExists(category.type, category.name)) {
      return false;
    }
    _customCategories.add(category);
    await _save(waitForDisk: true);
    return true;
  }

  bool categoryExists(LedgerEntryType type, String name) {
    return categoriesFor(type).any((item) => item == name);
  }

  Future<void> replaceImportedData(ImportedLedgerData data) async {
    _accounts
      ..clear()
      ..addAll(
        data.accounts.map((account) {
          return account.copyWith(balanceInCents: 0);
        }),
      );
    _entries
      ..clear()
      ..addAll(data.entries);
    _customCategories
      ..clear()
      ..addAll(data.customCategories);
    for (final entry in _entries) {
      _applyEntryEffect(entry);
    }
    await _save(waitForDisk: true);
  }

  Future<void> addAccount(Account account) async {
    _accounts.add(account);
    await _save(waitForDisk: false);
  }

  Future<void> updateAccount(Account account) async {
    final index = _accounts.indexWhere((item) => item.id == account.id);
    if (index == -1) {
      return;
    }
    _accounts[index] = account;
    await _save(waitForDisk: false);
  }

  Future<void> deleteAccount(String accountId) async {
    final relatedEntries = _entries.where((entry) {
      return entry.fromAccountId == accountId || entry.toAccountId == accountId;
    }).toList();
    for (final entry in relatedEntries) {
      _applyEntryEffect(entry, reverse: true);
      _entries.removeWhere((item) => item.id == entry.id);
    }
    _accounts.removeWhere((account) => account.id == accountId);
    await _save(waitForDisk: false);
  }

  Future<void> addEntry(LedgerEntry entry) async {
    _entries.add(entry);
    _applyEntryEffect(entry);
    await _save(waitForDisk: false);
  }

  Future<void> updateEntry(LedgerEntry entry) async {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      return;
    }
    _applyEntryEffect(_entries[index], reverse: true);
    _entries[index] = entry;
    _applyEntryEffect(entry);
    await _save(waitForDisk: false);
  }

  Future<void> deleteEntry(String entryId) async {
    final index = _entries.indexWhere((entry) => entry.id == entryId);
    if (index == -1) {
      return;
    }
    _applyEntryEffect(_entries[index], reverse: true);
    _entries.removeAt(index);
    await _save(waitForDisk: false);
  }

  Future<void> rememberEntryFormDefaults(
    LedgerEntryType type,
    EntryFormDefaults defaults,
  ) async {
    _entryFormDefaults[type] = defaults;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final payload = jsonEncode({
      for (final entry in _entryFormDefaults.entries)
        entry.key.name: entry.value.toJson(),
    });
    await prefs.setString(_entryFormDefaultsKey, payload);
  }

  List<Account> recentAccounts({int limit = 4}) {
    final seen = <String>{};
    final result = <Account>[];
    void add(String? id) {
      if (id == null || seen.contains(id)) {
        return;
      }
      final account = accountById(id);
      if (account == null) {
        return;
      }
      seen.add(id);
      result.add(account);
    }

    for (final type in const [
      LedgerEntryType.expense,
      LedgerEntryType.income,
      LedgerEntryType.transfer,
    ]) {
      final defaults = defaultsFor(type);
      add(defaults.fromAccountId);
      add(defaults.toAccountId);
      if (result.length >= limit) {
        break;
      }
    }
    return result.take(limit).toList();
  }

  Account? accountById(String? id) {
    if (id == null) {
      return null;
    }
    for (final account in _accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }

  List<String> categoriesFor(LedgerEntryType type) {
    return switch (type) {
      LedgerEntryType.expense => expenseLeafNames,
      LedgerEntryType.income => incomeLeafNames,
      LedgerEntryType.transfer => const [],
    };
  }

  List<String> get expenseLeafNames {
    return [
      for (final group in expenseCategoryGroups)
        for (final child in group.children) child.name,
    ];
  }

  List<String> get incomeLeafNames {
    return [
      for (final group in incomeCategoryGroups)
        for (final child in group.children) child.name,
    ];
  }

  ExpenseCategoryGroup? expenseGroupByName(String? name) {
    for (final group in expenseCategoryGroups) {
      if (group.name == name) {
        return group;
      }
    }
    return null;
  }

  ExpenseCategoryItem? expenseItemByName(String? name) {
    for (final group in expenseCategoryGroups) {
      for (final item in group.children) {
        if (item.name == name) {
          return item;
        }
      }
    }
    return null;
  }

  String? groupNameForExpenseCategory(String? category) {
    for (final group in expenseCategoryGroups) {
      for (final item in group.children) {
        if (item.name == category) {
          return group.name;
        }
      }
    }
    return null;
  }

  ExpenseCategoryItem? incomeItemByName(String? name) {
    for (final group in incomeCategoryGroups) {
      for (final item in group.children) {
        if (item.name == name) {
          return item;
        }
      }
    }
    return null;
  }

  String? groupNameForIncomeCategory(String? category) {
    for (final group in incomeCategoryGroups) {
      for (final item in group.children) {
        if (item.name == category) {
          return group.name;
        }
      }
    }
    return null;
  }

  void _applyEntryEffect(LedgerEntry entry, {bool reverse = false}) {
    final sign = reverse ? -1 : 1;
    if (entry.type == LedgerEntryType.expense && entry.fromAccountId != null) {
      _adjustAccount(entry.fromAccountId!, -entry.amountInCents * sign);
    }
    if (entry.type == LedgerEntryType.income && entry.toAccountId != null) {
      _adjustAccount(entry.toAccountId!, entry.amountInCents * sign);
    }
    if (entry.type == LedgerEntryType.transfer) {
      if (entry.fromAccountId != null) {
        _adjustAccount(entry.fromAccountId!, -entry.amountInCents * sign);
      }
      if (entry.toAccountId != null) {
        _adjustAccount(entry.toAccountId!, entry.amountInCents * sign);
      }
    }
  }

  void _adjustAccount(String id, int deltaInCents) {
    final index = _accounts.indexWhere((account) => account.id == id);
    if (index == -1) {
      return;
    }
    final account = _accounts[index];
    _accounts[index] = account.copyWith(
      balanceInCents: account.balanceInCents + deltaInCents,
      repaymentDay: account.repaymentDay,
    );
  }

  Future<void> _save({bool waitForDisk = true}) async {
    final payload = jsonEncode({
      'accounts': _accounts.map((account) => account.toJson()).toList(),
      'entries': _entries.map((entry) => entry.toJson()).toList(),
      'customCategories': _customCategories
          .map((category) => category.toJson())
          .toList(),
    });
    notifyListeners();
    _pendingPersist = _pendingPersist.then((_) async {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      await prefs.setString(_storageKey, payload);
    });
    if (waitForDisk) {
      await _pendingPersist;
    } else {
      unawaited(_pendingPersist);
    }
  }

  Future<File> exportBackupData() async {
    final payload = jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': _accounts.map((account) => account.toJson()).toList(),
      'entries': _entries.map((entry) => entry.toJson()).toList(),
      'customCategories': _customCategories
          .map((category) => category.toJson())
          .toList(),
    });

    final directory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final formattedDate =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final file = File('${directory.path}/ledger_backup_$formattedDate.json');
    await file.writeAsString(payload);
    await _cleanupLocalBackupFiles(directory, keepLatest: 1);
    return file;
  }

  Future<void> importBackupData(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final decoded = jsonDecode(content) as Map<String, Object?>;

    final version = decoded['version'] as int? ?? 1;
    if (version > 1) {
      throw UnsupportedError('备份文件版本过高，无法导入');
    }

    final accounts = decoded['accounts'] as List<Object?>? ?? [];
    final entries = decoded['entries'] as List<Object?>? ?? [];
    final customCategories =
        decoded['customCategories'] as List<Object?>? ?? [];

    _accounts
      ..clear()
      ..addAll(
        accounts.map((item) {
          return Account.fromJson((item as Map).cast<String, Object?>());
        }),
      );
    _entries
      ..clear()
      ..addAll(
        entries.map((item) {
          return LedgerEntry.fromJson((item as Map).cast<String, Object?>());
        }),
      );
    _customCategories
      ..clear()
      ..addAll(
        customCategories.map((item) {
          return CustomCategory.fromJson((item as Map).cast<String, Object?>());
        }),
      );

    await _save(waitForDisk: true);
  }

  Future<bool> testWebdavConnection() async {
    if (_webdavUrl == null ||
        _webdavUsername == null ||
        _webdavPassword == null) {
      _lastWebdavError = '请先配置 WebDAV 地址、用户名和密码';
      return false;
    }

    try {
      final encodedAuth = _encodedWebdavAuth();
      final url = _webdavDirectoryUri();
      final response = await _sendWebdavRequest(
        'PROPFIND',
        url,
        headers: {
          'Authorization': 'Basic $encodedAuth',
          'Depth': '0',
          'Content-Type': 'application/xml; charset=utf-8',
        },
        body: _propfindBody,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _lastWebdavError = null;
        return true;
      }

      final fallback = await http.get(
        url,
        headers: {'Authorization': 'Basic $encodedAuth'},
      );
      final success = fallback.statusCode >= 200 && fallback.statusCode < 300;
      _lastWebdavError = success
          ? null
          : '服务器返回 ${response.statusCode}/${fallback.statusCode}';
      return success;
    } catch (e) {
      _lastWebdavError = '连接异常：$e';
      return false;
    }
  }

  Future<bool> syncToWebdav() async {
    if (_webdavUrl == null ||
        _webdavUsername == null ||
        _webdavPassword == null) {
      return false;
    }

    File? backupFile;
    try {
      backupFile = await exportBackupData();
      final fileContent = await backupFile.readAsString();
      final fileName = backupFile.path.split('/').last;

      final url = _webdavDirectoryUri().resolve(Uri.encodeComponent(fileName));
      final encodedAuth = _encodedWebdavAuth();

      // 上传新的备份文件
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Basic $encodedAuth',
          'Content-Type': 'application/json',
        },
        body: fileContent,
      );

      final success = response.statusCode >= 200 && response.statusCode < 300;

      if (success) {
        _lastWebdavError = null;
        // 上传成功后，删除旧的备份文件，只保留最新的9份
        await _cleanupOldBackups(encodedAuth);
      } else {
        _lastWebdavError = '上传失败，服务器返回 ${response.statusCode}';
      }

      await setSyncStatus(DateTime.now(), success);
      return success;
    } catch (e) {
      _lastWebdavError = '同步异常：$e';
      await setSyncStatus(DateTime.now(), false);
      return false;
    } finally {
      if (backupFile != null && await backupFile.exists()) {
        try {
          await backupFile.delete();
        } catch (_) {
          // 删除同步产生的本地中间备份失败时，不影响同步结果。
        }
      }
    }
  }

  Future<void> _cleanupLocalBackupFiles(
    Directory directory, {
    int keepLatest = 1,
  }) async {
    final entities = await directory.list().toList();
    final backupFiles = entities.whereType<File>().where((file) {
      final fileName = file.path.split('/').last;
      return RegExp(r'^ledger_backup_.*\.json$').hasMatch(fileName);
    }).toList()..sort((a, b) => a.path.compareTo(b.path));

    if (backupFiles.length <= keepLatest) {
      return;
    }

    for (final file in backupFiles.take(backupFiles.length - keepLatest)) {
      try {
        await file.delete();
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _cleanupOldBackups(String encodedAuth) async {
    try {
      final backupFiles = await _listWebdavBackupFiles(encodedAuth);

      if (backupFiles.length <= 9) {
        // 如果备份文件不超过9份，不需要删除
        return;
      }

      // 按文件名排序，最新的文件在最后
      backupFiles.sort();

      // 计算需要删除的旧备份文件数量（保留最新的9份）
      final filesToDelete = backupFiles.sublist(0, backupFiles.length - 9);

      // 删除旧的备份文件
      for (final oldFileName in filesToDelete) {
        try {
          final deleteUrl = _webdavDirectoryUri().resolve(
            Uri.encodeComponent(oldFileName),
          );
          await http.delete(
            deleteUrl,
            headers: {'Authorization': 'Basic $encodedAuth'},
          );
        } catch (_) {
          // 如果某个文件删除失败，继续删除其他文件
          continue;
        }
      }
    } catch (_) {
      // 清理旧备份文件时出错，不影响备份本身的成功状态
    }
  }

  Future<bool> restoreFromWebdav() async {
    if (_webdavUrl == null ||
        _webdavUsername == null ||
        _webdavPassword == null) {
      return false;
    }

    try {
      final encodedAuth = _encodedWebdavAuth();
      final backupFiles = await _listWebdavBackupFiles(encodedAuth);

      if (backupFiles.isEmpty) {
        _lastWebdavError = 'NAS 目录里没有可恢复的备份文件';
        return false;
      }

      // 按文件名排序，最新的文件在最后
      backupFiles.sort();
      final latestFile = backupFiles.last;

      // 下载最新的备份文件
      final fileUrl = _webdavDirectoryUri().resolve(
        Uri.encodeComponent(latestFile),
      );
      final fileResponse = await http.get(
        fileUrl,
        headers: {'Authorization': 'Basic $encodedAuth'},
      );

      if (fileResponse.statusCode < 200 || fileResponse.statusCode >= 300) {
        _lastWebdavError = '下载备份失败，服务器返回 ${fileResponse.statusCode}';
        return false;
      }

      // 保存到临时文件并导入
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_backup.json');
      await tempFile.writeAsString(fileResponse.body);
      await importBackupData(tempFile.path);
      await tempFile.delete();

      _lastWebdavError = null;
      return true;
    } catch (e) {
      _lastWebdavError = '恢复异常：$e';
      return false;
    }
  }

  Uri _webdavDirectoryUri() {
    final url = _webdavUrl!;
    final normalizedUrl = url.endsWith('/') ? url : '$url/';
    return Uri.parse(_sanitizeUriLikePath(normalizedUrl));
  }

  String _encodedWebdavAuth() {
    final auth = '${_webdavUsername}:${_webdavPassword}';
    return base64Encode(utf8.encode(auth));
  }

  Future<List<String>> _listWebdavBackupFiles(String encodedAuth) async {
    final dirUrl = _webdavDirectoryUri();
    final response = await _sendWebdavRequest(
      'PROPFIND',
      dirUrl,
      headers: {
        'Authorization': 'Basic $encodedAuth',
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      body: _propfindBody,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final files = _extractBackupFileNames(response.body, dirUrl);
      if (files.isNotEmpty) {
        return files;
      }
    }

    final fallback = await http.get(
      dirUrl,
      headers: {'Authorization': 'Basic $encodedAuth'},
    );
    if (fallback.statusCode >= 200 && fallback.statusCode < 300) {
      return _extractBackupFileNames(fallback.body, dirUrl);
    }

    throw StateError(
      '无法列出 WebDAV 目录（PROPFIND ${response.statusCode} / GET ${fallback.statusCode}）',
    );
  }

  Future<http.Response> _sendWebdavRequest(
    String method,
    Uri url, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final request = http.Request(method, url);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (body != null) {
      request.body = body;
    }
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  List<String> _extractBackupFileNames(String content, Uri dirUrl) {
    final fileNames = <String>{};
    final patterns = [
      RegExp(r'<[^>]*:?href[^>]*>([^<]+)</[^>]*:?href>', caseSensitive: false),
      RegExp(r'href="([^"]+)"', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(content)) {
        final raw = match.group(1);
        if (raw == null) {
          continue;
        }
        final normalized = _normalizeBackupFileName(raw, dirUrl);
        if (normalized != null) {
          fileNames.add(normalized);
        }
      }
    }

    final files = fileNames.toList()..sort();
    return files;
  }

  String? _normalizeBackupFileName(String rawHref, Uri dirUrl) {
    final cleaned = rawHref
        .trim()
        .replaceAll('&amp;', '&')
        .replaceAll('&#47;', '/');
    if (cleaned.isEmpty) {
      return null;
    }
    final sanitized = _sanitizeUriLikePath(cleaned);

    Uri? uri;
    try {
      uri = Uri.parse(sanitized);
      if (!uri.hasScheme && !sanitized.startsWith('/')) {
        uri = dirUrl.resolveUri(uri);
      }
    } catch (_) {
      final fallbackPath = sanitized.startsWith('/')
          ? sanitized
          : '${dirUrl.path}$sanitized';
      uri = Uri(
        scheme: dirUrl.scheme,
        userInfo: dirUrl.userInfo,
        host: dirUrl.host,
        port: dirUrl.hasPort ? dirUrl.port : null,
        path: fallbackPath,
      );
    }

    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) {
      return null;
    }
    final fileName = segments.last;
    if (!RegExp(r'^ledger_backup_.*\.json$').hasMatch(fileName)) {
      return null;
    }
    return fileName;
  }

  String _sanitizeUriLikePath(String value) {
    return value.replaceAllMapped(RegExp(r'%(?![0-9A-Fa-f]{2})'), (_) => '%25');
  }

  static const String _propfindBody = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:displayname />
    <d:getlastmodified />
    <d:resourcetype />
  </d:prop>
</d:propfind>''';
}

class LedgerScope extends InheritedNotifier<LedgerStore> {
  const LedgerScope({
    required LedgerStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static LedgerStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LedgerScope>();
    assert(scope != null, 'LedgerScope is missing');
    return scope!.notifier!;
  }
}
