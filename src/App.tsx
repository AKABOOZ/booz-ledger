import React, { useState } from 'react';
import {
  Mic,
  Cloud,
  Database,
  Shield,
  Info,
  Save,
  TestTube,
  Download,
  Upload,
  Table,
  CloudDownload,
  AlertCircle,
  CheckCircle2,
  ChevronRight,
  ArrowLeft
} from 'lucide-react';

// 模拟设置状态
interface SettingsState {
  apiKey: string;
  secretKey: string;
  webdavUrl: string;
  webdavUsername: string;
  webdavPassword: string;
  isSalaryIncomeMasked: boolean;
  lastSyncTime: string;
  lastSyncSuccess: boolean;
  isExporting: boolean;
  isImporting: boolean;
  isTestingConnection: boolean;
  isRestoringFromWebdav: boolean;
}

// 页面类型
type Page = 'main' | 'voice' | 'sync' | 'data' | 'privacy' | 'about';

const App: React.FC = () => {
  const [currentPage, setCurrentPage] = useState<Page>('main');
  const [settings, setSettings] = useState<SettingsState>({
    apiKey: '',
    secretKey: '',
    webdavUrl: '',
    webdavUsername: '',
    webdavPassword: '',
    isSalaryIncomeMasked: true,
    lastSyncTime: '2小时前',
    lastSyncSuccess: true,
    isExporting: false,
    isImporting: false,
    isTestingConnection: false,
    isRestoringFromWebdav: false,
  });

  const handleInputChange = (field: keyof SettingsState, value: string | boolean) => {
    setSettings(prev => ({
      ...prev,
      [field]: value,
    }));
  };

  const handleSaveApiConfig = () => {
    setTimeout(() => {
      alert('配置已保存');
    }, 500);
  };

  const handleSaveWebdavConfig = () => {
    setTimeout(() => {
      alert('配置已保存');
    }, 500);
  };

  const handleTestConnection = () => {
    setSettings(prev => ({ ...prev, isTestingConnection: true }));
    setTimeout(() => {
      setSettings(prev => ({ ...prev, isTestingConnection: false }));
      alert('连接成功');
    }, 1500);
  };

  const handleExportBackup = () => {
    setSettings(prev => ({ ...prev, isExporting: true }));
    setTimeout(() => {
      setSettings(prev => ({ ...prev, isExporting: false }));
      alert('导出成功，备份文件已生成');
    }, 1500);
  };

  const handleImportBackup = () => {
    setSettings(prev => ({ ...prev, isImporting: true }));
    setTimeout(() => {
      setSettings(prev => ({ ...prev, isImporting: false }));
      alert('导入成功');
    }, 1500);
  };

  const handleImportSuiShouJi = () => {
    setSettings(prev => ({ ...prev, isImporting: true }));
    setTimeout(() => {
      setSettings(prev => ({ ...prev, isImporting: false }));
      alert('导入成功');
    }, 1500);
  };

  const handleRestoreFromWebdav = () => {
    setSettings(prev => ({ ...prev, isRestoringFromWebdav: true }));
    setTimeout(() => {
      setSettings(prev => ({ ...prev, isRestoringFromWebdav: false }));
      alert('恢复成功');
    }, 1500);
  };

  // 主设置页面
  const MainSettingsPage = () => (
    <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="space-y-4">
        <SettingCard
          icon={<Mic className="w-6 h-6" />}
          title="语音识别"
          description="百度智能云API配置"
          onClick={() => setCurrentPage('voice')}
        />
        <SettingCard
          icon={<Cloud className="w-6 h-6" />}
          title="数据同步"
          description="WebDAV同步和备份"
          onClick={() => setCurrentPage('sync')}
        />
        <SettingCard
          icon={<Database className="w-6 h-6" />}
          title="数据管理"
          description="导入导出备份数据"
          onClick={() => setCurrentPage('data')}
        />
        <SettingCard
          icon={<Shield className="w-6 h-6" />}
          title="隐私安全"
          description="工资收入打码设置"
          onClick={() => setCurrentPage('privacy')}
        />
        <SettingCard
          icon={<Info className="w-6 h-6" />}
          title="关于应用"
          description="版本信息和使用说明"
          onClick={() => setCurrentPage('about')}
        />
      </div>
    </main>
  );

  // 设置卡片组件
  const SettingCard = ({
    icon,
    title,
    description,
    onClick
  }: {
    icon: React.ReactNode;
    title: string;
    description: string;
    onClick: () => void;
  }) => (
    <div
      onClick={onClick}
      className="bg-white rounded-2xl shadow-md p-6 cursor-pointer hover:shadow-lg transition-shadow"
    >
      <div className="flex items-center">
        <div className="text-[#167C80] mr-4">
          {icon}
        </div>
        <div className="flex-1">
          <h3 className="text-lg font-bold text-[#16211F] mb-1">{title}</h3>
          <p className="text-sm text-[#65736F]">{description}</p>
        </div>
        <ChevronRight className="w-5 h-5 text-[#65736F]" />
      </div>
    </div>
  );

  // 页面头部组件
  const PageHeader = ({ title, onBack }: { title: string; onBack: () => void }) => (
    <header className="bg-white shadow-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <div className="flex items-center">
          <button
            onClick={onBack}
            className="mr-4 p-2 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <ArrowLeft className="w-6 h-6 text-[#16211F]" />
          </button>
          <h1 className="text-2xl font-bold text-[#16211F]">{title}</h1>
        </div>
      </div>
    </header>
  );

  // 语音识别页面
  const VoiceSettingsPage = () => (
    <>
      <PageHeader title="语音识别" onBack={() => setCurrentPage('main')} />
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-white rounded-2xl shadow-md p-6">
          <h3 className="text-base font-medium text-[#65736F] mb-4">百度智能云API配置</h3>
          <div className="space-y-4">
            <div>
              <label htmlFor="apiKey" className="block text-sm font-medium text-[#65736F] mb-1">
                API Key
              </label>
              <input
                type="text"
                id="apiKey"
                value={settings.apiKey}
                onChange={(e) => handleInputChange('apiKey', e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#167C80] focus:border-transparent"
                placeholder="请输入API Key"
              />
            </div>
            <div>
              <label htmlFor="secretKey" className="block text-sm font-medium text-[#65736F] mb-1">
                Secret Key
              </label>
              <input
                type="password"
                id="secretKey"
                value={settings.secretKey}
                onChange={(e) => handleInputChange('secretKey', e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#167C80] focus:border-transparent"
                placeholder="请输入Secret Key"
              />
            </div>
            <button
              onClick={handleSaveApiConfig}
              className="w-full bg-[#167C80] text-white py-2 px-4 rounded-xl hover:bg-[#136a6d] transition-colors flex items-center justify-center"
            >
              <Save className="w-4 h-4 mr-2" />
              保存配置
            </button>
          </div>
        </div>
      </main>
    </>
  );

  // 数据同步页面
  const SyncSettingsPage = () => (
    <>
      <PageHeader title="数据同步" onBack={() => setCurrentPage('main')} />
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-white rounded-2xl shadow-md p-6">
          <h3 className="text-base font-medium text-[#65736F] mb-4">WebDAV 同步设置</h3>
          <div className="space-y-4">
            <div>
              <label htmlFor="webdavUrl" className="block text-sm font-medium text-[#65736F] mb-1">
                服务器地址
              </label>
              <input
                type="text"
                id="webdavUrl"
                value={settings.webdavUrl}
                onChange={(e) => handleInputChange('webdavUrl', e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#167C80] focus:border-transparent"
                placeholder="https://xxx.zspace.cn/dav/"
              />
            </div>
            <div>
              <label htmlFor="webdavUsername" className="block text-sm font-medium text-[#65736F] mb-1">
                用户名
              </label>
              <input
                type="text"
                id="webdavUsername"
                value={settings.webdavUsername}
                onChange={(e) => handleInputChange('webdavUsername', e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#167C80] focus:border-transparent"
                placeholder="admin"
              />
            </div>
            <div>
              <label htmlFor="webdavPassword" className="block text-sm font-medium text-[#65736F] mb-1">
                密码
              </label>
              <input
                type="password"
                id="webdavPassword"
                value={settings.webdavPassword}
                onChange={(e) => handleInputChange('webdavPassword', e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#167C80] focus:border-transparent"
                placeholder="••••••"
              />
            </div>
            <div className="flex space-x-3">
              <button
                onClick={handleTestConnection}
                disabled={settings.isTestingConnection}
                className="flex-1 bg-[#167C80] text-white py-2 px-4 rounded-xl hover:bg-[#136a6d] transition-colors flex items-center justify-center disabled:bg-gray-400"
              >
                {settings.isTestingConnection ? (
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin mr-2" />
                ) : (
                  <TestTube className="w-4 h-4 mr-2" />
                )}
                {settings.isTestingConnection ? '测试中...' : '测试连接'}
              </button>
              <button
                onClick={handleSaveWebdavConfig}
                className="flex-1 bg-[#167C80] text-white py-2 px-4 rounded-xl hover:bg-[#136a6d] transition-colors flex items-center justify-center"
              >
                <Save className="w-4 h-4 mr-2" />
                保存配置
              </button>
            </div>
            <div className="flex items-center mt-2">
              <span className="text-sm text-[#65736F] mr-2">同步状态：</span>
              <span className={`text-sm ${settings.lastSyncSuccess ? 'text-green-600' : 'text-red-600'}`}>
                上次同步 {settings.lastSyncTime} {settings.lastSyncSuccess ? <CheckCircle2 className="inline w-4 h-4" /> : <AlertCircle className="inline w-4 h-4" />}
              </span>
            </div>
            <button
              onClick={handleRestoreFromWebdav}
              disabled={settings.isRestoringFromWebdav}
              className="w-full border border-[#167C80] text-[#167C80] py-2 px-4 rounded-xl hover:bg-[#f0f9f7] transition-colors flex items-center justify-center disabled:border-gray-400 disabled:text-gray-400"
            >
              {settings.isRestoringFromWebdav ? (
                <div className="w-4 h-4 border-2 border-[#167C80] border-t-transparent rounded-full animate-spin mr-2" />
              ) : (
                <CloudDownload className="w-4 h-4 mr-2" />
              )}
              {settings.isRestoringFromWebdav ? '恢复中...' : '从 NAS 恢复数据'}
            </button>
          </div>
        </div>
      </main>
    </>
  );

  // 数据管理页面
  const DataSettingsPage = () => (
    <>
      <PageHeader title="数据管理" onBack={() => setCurrentPage('main')} />
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-white rounded-2xl shadow-md p-6">
          <div className="space-y-3">
            <button
              onClick={handleExportBackup}
              disabled={settings.isExporting}
              className="w-full bg-[#167C80] text-white py-3 px-4 rounded-xl hover:bg-[#136a6d] transition-colors flex items-center justify-center disabled:bg-gray-400"
            >
              {settings.isExporting ? (
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin mr-2" />
              ) : (
                <Download className="w-5 h-5 mr-2" />
              )}
              {settings.isExporting ? '导出中...' : '导出备份数据'}
            </button>
            <button
              onClick={handleImportBackup}
              disabled={settings.isImporting}
              className="w-full border border-[#167C80] text-[#167C80] py-3 px-4 rounded-xl hover:bg-[#f0f9f7] transition-colors flex items-center justify-center disabled:border-gray-400 disabled:text-gray-400"
            >
              {settings.isImporting ? (
                <div className="w-4 h-4 border-2 border-[#167C80] border-t-transparent rounded-full animate-spin mr-2" />
              ) : (
                <Upload className="w-5 h-5 mr-2" />
              )}
              {settings.isImporting ? '导入中...' : '导入备份数据'}
            </button>
            <button
              onClick={handleImportSuiShouJi}
              disabled={settings.isImporting}
              className="w-full border border-[#167C80] text-[#167C80] py-3 px-4 rounded-xl hover:bg-[#f0f9f7] transition-colors flex items-center justify-center disabled:border-gray-400 disabled:text-gray-400"
            >
              {settings.isImporting ? (
                <div className="w-4 h-4 border-2 border-[#167C80] border-t-transparent rounded-full animate-spin mr-2" />
              ) : (
                <Table className="w-5 h-5 mr-2" />
              )}
              {settings.isImporting ? '导入中...' : '导入随手记数据'}
            </button>
          </div>
        </div>
      </main>
    </>
  );

  // 隐私安全页面
  const PrivacySettingsPage = () => (
    <>
      <PageHeader title="隐私安全" onBack={() => setCurrentPage('main')} />
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-white rounded-2xl shadow-md p-6">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-base font-medium text-[#16211F]">工资收入打码</h3>
                <p className="text-sm text-[#65736F]">开启后，工资收入流水金额显示为 ****</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={settings.isSalaryIncomeMasked}
                  onChange={(e) => handleInputChange('isSalaryIncomeMasked', e.target.checked)}
                  className="sr-only peer"
                />
                <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-[#167C80]"></div>
              </label>
            </div>
          </div>
        </div>
      </main>
    </>
  );

  // 关于应用页面
  const AboutSettingsPage = () => (
    <>
      <PageHeader title="关于应用" onBack={() => setCurrentPage('main')} />
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-white rounded-2xl shadow-md p-6">
          <div className="space-y-3">
            <div className="flex justify-between items-center">
              <span className="text-base text-[#65736F]">版本</span>
              <span className="text-base font-medium text-[#16211F]">1.0.0</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-base text-[#65736F]">应用名称</span>
              <span className="text-base font-medium text-[#16211F]">波哥记账APP</span>
            </div>
          </div>
        </div>
      </main>
    </>
  );

  // 渲染当前页面
  const renderCurrentPage = () => {
    switch (currentPage) {
      case 'voice':
        return <VoiceSettingsPage />;
      case 'sync':
        return <SyncSettingsPage />;
      case 'data':
        return <DataSettingsPage />;
      case 'privacy':
        return <PrivacySettingsPage />;
      case 'about':
        return <AboutSettingsPage />;
      default:
        return <MainSettingsPage />;
    }
  };

  return (
    <div className="min-h-screen bg-[#F8FAF6] font-sans">
      {/* 主设置页面的头部 */}
      {currentPage === 'main' && (
        <header className="bg-white shadow-sm">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <h1 className="text-2xl font-bold text-[#16211F]">设置</h1>
          </div>
        </header>
      )}
      
      {renderCurrentPage()}
    </div>
  );
};

export default App;