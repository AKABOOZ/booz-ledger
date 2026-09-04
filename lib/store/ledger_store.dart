import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ledger_app/models/account.dart';
import 'package:ledger_app/models/category.dart';
import 'package:ledger_app/models/enums.dart';
import 'package:ledger_app/models/ledger_entry.dart';
import 'package:ledger_app/models/webdav_sync_models.dart';
import 'package:ledger_app/services/ledger_sync_merge.dart';
import 'package:ledger_app/services/webdav_client.dart';
import 'package:ledger_app/services/webdav_config_store.dart';

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
  static const _lastWebdavEndpointKey = 'last_webdav_endpoint_v2';
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
  final WebDavConfigStore _webDavConfigStore;
  final WebDavClient _webDavClient;
  WebDavConfig _webdavConfig = const WebDavConfig();
  bool _syncInProgress = false;
  SyncPhase _syncPhase = SyncPhase.idle;
  WebDavEndpoint? _lastSyncEndpoint;
  DateTime? _lastSyncTime;
  bool? _lastSyncSuccess;
  String? _lastWebdavError;

  LedgerStore({
    WebDavConfigStore? webDavConfigStore,
    WebDavClient? webDavClient,
  }) : _webDavConfigStore = webDavConfigStore ?? WebDavConfigStore(),
       _webDavClient = webDavClient ?? WebDavClient();

  bool get isLoading => _isLoading;
  bool get isAmountHidden => _isAmountHidden;
  bool get isSalaryIncomeMasked => _isSalaryIncomeMasked;
  bool get isWebdavAutoSyncEnabled => _isWebdavAutoSyncEnabled;
  int get themeMode => _themeMode;
  bool get isVoiceAiEnabled => _isVoiceAiEnabled;
  List<Account> get accounts => List.unmodifiable(
    _accounts.where((account) => account.deletedAt == null),
  );
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
  String? get webdavUrl => _webdavConfig.urlFor(WebDavEndpoint.local);
  String? get webdavExternalUrl =>
      _webdavConfig.urlFor(WebDavEndpoint.external);
  String? get webdavUsername =>
      _webdavConfig.username.isEmpty ? null : _webdavConfig.username;
  String? get webdavPassword =>
      _webdavConfig.password.isEmpty ? null : _webdavConfig.password;
  bool get webdavAutoSelectEndpoint => _webdavConfig.autoSelectEndpoint;
  SyncPhase get syncPhase => _syncPhase;
  bool get isSyncInProgress => _syncInProgress;
  WebDavEndpoint? get lastSyncEndpoint => _lastSyncEndpoint;
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

  Future<void> saveWebdavConfig(WebDavConfig config) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await _webDavConfigStore.save(prefs, config);
    _webdavConfig = config;
    notifyListeners();
  }

  /// Backwards-compatible bridge for the old one-address settings page.
  Future<void> setWebdavConfig(
    String? url,
    String? username,
    String? password,
  ) {
    return saveWebdavConfig(
      _webdavConfig.copyWith(
        localUrl: url ?? '',
        username: username ?? '',
        password: password ?? '',
      ),
    );
  }

  Future<void> setSyncStatus(DateTime time, bool success) async {
    _lastSyncTime = time;
    _lastSyncSuccess = success;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', time.toIso8601String());
    await prefs.setBool('last_sync_success', success);
    if (success && _lastSyncEndpoint != null) {
      await prefs.setString(_lastWebdavEndpointKey, _lastSyncEndpoint!.name);
    }
    notifyListeners();
  }

  List<ExpenseCategoryGroup> get expenseCategoryGroups {
    return defaultExpenseCategoryGroups.map((group) {
      return ExpenseCategoryGroup(group.name, [
        ...group.children,
        ..._customCategories
            .where((item) {
              return item.deletedAt == null &&
                  item.type == LedgerEntryType.expense &&
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
              return item.deletedAt == null &&
                  item.type == LedgerEntryType.income &&
                  item.groupName == group.name;
            })
            .map((item) => ExpenseCategoryItem(item.name, item.iconKey)),
      ]);
    }).toList();
  }

  List<LedgerEntry> get entries {
    final sorted = _entries.where((entry) => entry.deletedAt == null).toList()
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
      if (accounts.any(
        (item) => !(item as Map).containsKey('openingBalanceInCents'),
      )) {
        _deriveLegacyOpeningBalances();
      }
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
    _webdavConfig = await _webDavConfigStore.load(prefs);
    final lastSyncTimeStr = prefs.getString('last_sync_time');
    if (lastSyncTimeStr != null) {
      _lastSyncTime = DateTime.parse(lastSyncTimeStr);
    }
    _lastSyncSuccess = prefs.getBool('last_sync_success');
    final endpointName = prefs.getString(_lastWebdavEndpointKey);
    if (endpointName != null) {
      for (final endpoint in WebDavEndpoint.values) {
        if (endpoint.name == endpointName) {
          _lastSyncEndpoint = endpoint;
          break;
        }
      }
    }
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
    if (index == -1) return;
    final relatedEffect = _entryEffectForAccount(account.id);
    _accounts[index] = account.copyWith(
      createdAt: _accounts[index].createdAt,
      openingBalanceInCents: account.balanceInCents - relatedEffect,
      updatedAt: DateTime.now().toUtc(),
      deletedAt: null,
    );
    await _save(waitForDisk: false);
  }

  Future<void> deleteAccount(String accountId) async {
    final now = DateTime.now().toUtc();
    final relatedIndexes = <int>[];
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (entry.deletedAt == null &&
          (entry.fromAccountId == accountId ||
              entry.toAccountId == accountId)) {
        relatedIndexes.add(index);
      }
    }
    for (final index in relatedIndexes) {
      final entry = _entries[index];
      _applyEntryEffect(entry, reverse: true);
      _entries[index] = entry.copyWith(updatedAt: now, deletedAt: now);
    }
    final accountIndex = _accounts.indexWhere(
      (account) => account.id == accountId,
    );
    if (accountIndex != -1) {
      _accounts[accountIndex] = _accounts[accountIndex].copyWith(
        updatedAt: now,
        deletedAt: now,
      );
    }
    await _save(waitForDisk: false);
  }

  Future<void> addEntry(LedgerEntry entry) async {
    _entries.add(entry);
    _applyEntryEffect(entry);
    await _save(waitForDisk: false);
  }

  Future<void> updateEntry(LedgerEntry entry) async {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) return;
    _applyEntryEffect(_entries[index], reverse: true);
    final updated = entry.copyWith(
      createdAt: _entries[index].createdAt,
      updatedAt: DateTime.now().toUtc(),
      deletedAt: null,
    );
    _entries[index] = updated;
    _applyEntryEffect(updated);
    await _save(waitForDisk: false);
  }

  Future<void> deleteEntry(String entryId) async {
    final index = _entries.indexWhere((entry) => entry.id == entryId);
    if (index == -1 || _entries[index].deletedAt != null) return;
    final entry = _entries[index];
    _applyEntryEffect(entry, reverse: true);
    final now = DateTime.now().toUtc();
    _entries[index] = entry.copyWith(updatedAt: now, deletedAt: now);
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

  Future<List<ConnectionTestResult>> testWebdavConnections() async {
    final config = _webdavConfig;
    final auth = _webdavAuthorization(config);
    final results = <ConnectionTestResult>[];
    for (final endpoint in WebDavEndpoint.values) {
      final url = config.urlFor(endpoint);
      if (url == null) {
        results.add(
          ConnectionTestResult(
            endpoint: endpoint,
            configured: false,
            success: false,
            message: '未填写地址',
          ),
        );
        continue;
      }
      if (config.username.trim().isEmpty || config.password.isEmpty) {
        results.add(
          ConnectionTestResult(
            endpoint: endpoint,
            configured: true,
            success: false,
            message: '请先填写用户名和密码',
          ),
        );
        continue;
      }
      try {
        final directory = _webdavDirectoryUri(url);
        await _webDavClient.verifyDirectory(directory, auth);
        await _webDavClient.writeAndDeleteProbe(directory, auth);
        results.add(
          ConnectionTestResult(
            endpoint: endpoint,
            configured: true,
            success: true,
            message: '可正常读写备份目录',
          ),
        );
      } on WebDavException catch (error) {
        results.add(
          ConnectionTestResult(
            endpoint: endpoint,
            configured: true,
            success: false,
            message: error.message,
          ),
        );
      }
    }
    _lastWebdavError = results
        .where((item) => item.configured && !item.success)
        .map((item) => '${item.endpoint.label}：${item.message}')
        .join('；');
    notifyListeners();
    return results;
  }

  Future<bool> testWebdavConnection() async {
    final results = await testWebdavConnections();
    return results.any((item) => item.configured && item.success);
  }

  Future<bool> syncToWebdav() async {
    if (_syncInProgress) {
      _lastWebdavError = '已有同步任务正在进行，请稍后再试';
      notifyListeners();
      return false;
    }
    _syncInProgress = true;
    try {
      return await _performSync();
    } finally {
      _syncInProgress = false;
      _syncPhase = SyncPhase.idle;
      notifyListeners();
    }
  }

  Future<bool> _performSync() async {
    if (!_webdavConfig.isComplete) {
      return _finishSync(false, '请先配置 WebDAV 地址、用户名和密码');
    }
    try {
      _syncPhase = SyncPhase.selectingEndpoint;
      notifyListeners();
      final selected = await _selectEndpoint();
      final directory = _webdavDirectoryUri(_webdavConfig.urlFor(selected)!);
      final authorization = _webdavAuthorization(_webdavConfig);

      _syncPhase = SyncPhase.downloading;
      notifyListeners();
      final files = await _webDavClient.list(directory, authorization);
      final backups = files.where((file) => _isBackupFile(file.name)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      LedgerSyncPayload merged = _currentSyncPayload();
      if (backups.isNotEmpty) {
        final remoteRaw = await _webDavClient.download(
          directory.resolve(Uri.encodeComponent(backups.last.name)),
          authorization,
        );
        final remote = LedgerSyncPayload.fromJson(remoteRaw);
        _syncPhase = SyncPhase.merging;
        notifyListeners();
        merged = LedgerSyncMerger.merge(merged, remote);
      }

      _applySyncPayload(merged);
      await _save(waitForDisk: true);
      _syncPhase = SyncPhase.uploading;
      notifyListeners();
      final fileName = 'app-backup-${_backupTimestamp()}.json';
      await _webDavClient.upload(
        directory.resolve(Uri.encodeComponent(fileName)),
        authorization,
        _currentSyncPayload().encode(),
      );
      final verified = await _webDavClient.list(directory, authorization);
      if (!verified.any((file) => file.name == fileName)) {
        throw const WebDavException('上传校验失败，请稍后重试');
      }
      await _cleanupRemoteBackups(directory, authorization, verified);
      _lastSyncEndpoint = selected;
      return _finishSync(true, '已通过${selected.label}同步：$fileName，远端保留 9 份备份');
    } on WebDavException catch (error) {
      return _finishSync(false, error.message);
    } catch (_) {
      return _finishSync(false, '同步失败，请检查配置和网络连接');
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

  Future<bool> restoreFromWebdav() async {
    if (_syncInProgress) {
      _lastWebdavError = '已有同步任务正在进行，请稍后再试';
      notifyListeners();
      return false;
    }
    if (!_webdavConfig.isComplete) {
      _lastWebdavError = '请先配置 WebDAV 地址、用户名和密码';
      notifyListeners();
      return false;
    }
    _syncInProgress = true;
    _syncPhase = SyncPhase.restoring;
    notifyListeners();
    try {
      final endpoint = await _selectEndpoint();
      final directory = _webdavDirectoryUri(_webdavConfig.urlFor(endpoint)!);
      final authorization = _webdavAuthorization(_webdavConfig);
      final files = await _webDavClient.list(directory, authorization);
      final backups = files.where((file) => _isBackupFile(file.name)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (backups.isEmpty) {
        throw const WebDavException('NAS 目录里没有可恢复的备份文件');
      }
      final payload = LedgerSyncPayload.fromJson(
        await _webDavClient.download(
          directory.resolve(Uri.encodeComponent(backups.last.name)),
          authorization,
        ),
      );
      _applySyncPayload(payload);
      await _save(waitForDisk: true);
      _lastSyncEndpoint = endpoint;
      _lastWebdavError = null;
      return true;
    } on WebDavException catch (error) {
      _lastWebdavError = error.message;
      return false;
    } catch (_) {
      _lastWebdavError = '恢复失败，请检查配置和网络连接';
      return false;
    } finally {
      _syncInProgress = false;
      _syncPhase = SyncPhase.idle;
      notifyListeners();
    }
  }

  Future<WebDavEndpoint> _selectEndpoint() async {
    final errors = <String>[];
    final auth = _webdavAuthorization(_webdavConfig);
    for (final endpoint in _webdavConfig.candidates) {
      final url = _webdavConfig.urlFor(endpoint)!;
      try {
        await _webDavClient.verifyDirectory(_webdavDirectoryUri(url), auth);
        return endpoint;
      } on WebDavException catch (error) {
        errors.add('${endpoint.label}：${error.message}');
      }
    }
    throw WebDavException(
      errors.isEmpty ? '没有可用的 WebDAV 地址' : errors.join('；'),
    );
  }

  bool _finishSync(bool success, String message) {
    _lastSyncTime = DateTime.now();
    _lastSyncSuccess = success;
    _lastWebdavError = success ? null : message;
    unawaited(setSyncStatus(_lastSyncTime!, success));
    return success;
  }

  LedgerSyncPayload _currentSyncPayload() => LedgerSyncPayload(
    accounts: List.unmodifiable(_accounts),
    entries: List.unmodifiable(_entries),
    customCategories: List.unmodifiable(_customCategories),
    exportedAt: DateTime.now().toUtc(),
  );

  void _applySyncPayload(LedgerSyncPayload payload) {
    _accounts
      ..clear()
      ..addAll(payload.accounts);
    _entries
      ..clear()
      ..addAll(payload.entries);
    _customCategories
      ..clear()
      ..addAll(payload.customCategories);
    _rebuildAccountBalances();
  }

  void _deriveLegacyOpeningBalances() {
    for (var index = 0; index < _accounts.length; index++) {
      final account = _accounts[index];
      _accounts[index] = account.copyWith(
        openingBalanceInCents:
            account.balanceInCents - _entryEffectForAccount(account.id),
      );
    }
  }

  int _entryEffectForAccount(String accountId) {
    var effect = 0;
    for (final entry in _entries.where((item) => item.deletedAt == null)) {
      if (entry.type == LedgerEntryType.expense &&
          entry.fromAccountId == accountId) {
        effect -= entry.amountInCents;
      } else if (entry.type == LedgerEntryType.income &&
          entry.toAccountId == accountId) {
        effect += entry.amountInCents;
      } else if (entry.type == LedgerEntryType.transfer) {
        if (entry.fromAccountId == accountId) effect -= entry.amountInCents;
        if (entry.toAccountId == accountId) effect += entry.amountInCents;
      }
    }
    return effect;
  }

  void _rebuildAccountBalances() {
    for (var index = 0; index < _accounts.length; index++) {
      final account = _accounts[index];
      _accounts[index] = account.copyWith(
        balanceInCents: account.openingBalanceInCents,
      );
    }
    for (final entry in _entries.where((item) => item.deletedAt == null)) {
      _applyEntryEffect(entry);
    }
  }

  Future<void> _cleanupRemoteBackups(
    Uri directory,
    String authorization,
    List<WebDavFileInfo> files,
  ) async {
    final backups = files.where((file) => _isBackupFile(file.name)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final file in backups.take(
      (backups.length - 9).clamp(0, backups.length),
    )) {
      try {
        await _webDavClient.delete(
          directory.resolve(Uri.encodeComponent(file.name)),
          authorization,
        );
      } on WebDavException {
        // Retention cleanup is non-critical; the uploaded, verified backup wins.
      }
    }
  }

  bool _isBackupFile(String name) => RegExp(
    r'^(app-backup-\d{8}-\d{6}|ledger_backup_.*)\.json$',
  ).hasMatch(name);

  String _backupTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  Uri _webdavDirectoryUri(String value) {
    final normalized = value.endsWith('/') ? value : '$value/';
    return Uri.parse(_sanitizeUriLikePath(normalized));
  }

  String _webdavAuthorization(WebDavConfig config) {
    return 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
  }

  String _sanitizeUriLikePath(String value) {
    return value.replaceAllMapped(RegExp(r'%(?![0-9A-Fa-f]{2})'), (_) => '%25');
  }
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
