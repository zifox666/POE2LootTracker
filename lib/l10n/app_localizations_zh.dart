// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'POE2 掉落追踪';

  @override
  String get lootStats => '掉落统计';

  @override
  String get mapLog => '地图日志';

  @override
  String get cost => '成本';

  @override
  String get costSettings => '成本设置';

  @override
  String get costSettingsHint => '每个成本可关联多张地图。匹配时会同时查询简中、繁中和英文名称；未匹配的地图使用默认成本。';

  @override
  String get addCostPreset => '添加成本';

  @override
  String get editCostPreset => '编辑成本';

  @override
  String get deleteCostPreset => '删除成本';

  @override
  String deleteCostPresetBody(String name) {
    return '确定删除“$name”吗？历史地图成本不会改变。';
  }

  @override
  String get noCostPresets => '暂无成本设置';

  @override
  String get costName => '成本名称';

  @override
  String get costPrice => '成本价格';

  @override
  String get optionalMapName => '地图名称（可选）';

  @override
  String get optionalMapNameHint => '填写完整地图名称以便进图时自动匹配';

  @override
  String get mapNames => '关联地图';

  @override
  String get mapNamesHint => '每张已选地图都会同时按简中、繁中和英文区域名称匹配。';

  @override
  String get chooseMaps => '选择地图';

  @override
  String get searchMaps => '搜索简中、繁中或英文地图名';

  @override
  String get noMapsSelected => '暂未选择地图';

  @override
  String get defaultCost => '默认成本';

  @override
  String get defaultCostHint => '进图时没有匹配到其他成本时使用。';

  @override
  String get manualOnly => '未关联地图 · 仅供手动切换';

  @override
  String get invalidCostPreset => '请输入成本名称和大于 0 的价格。';

  @override
  String get activeCost => '当前成本';

  @override
  String get noCostPreset => '不扣成本';

  @override
  String get manualCostFallback => '未匹配地图时手动使用';

  @override
  String mapMatch(String name) {
    return '自动匹配：$name';
  }

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get profit => '收益';

  @override
  String get duration => '时长';

  @override
  String get noMaps => '暂无地图记录';

  @override
  String get previous => '上一页';

  @override
  String get next => '下一页';

  @override
  String pageOf(int current, int total) {
    return '第 $current / $total 页';
  }

  @override
  String get marketPrices => '市场价格';

  @override
  String get settings => '设置';

  @override
  String get currentSession => '当前会话';

  @override
  String get selectSession => '会话';

  @override
  String get selectMap => '地图记录';

  @override
  String get allMaps => '全部地图';

  @override
  String get currentMap => '当前地图';

  @override
  String get sessionRevenue => '会话收益';

  @override
  String get revenuePerHour => '每小时收益';

  @override
  String get mapCount => '地图数';

  @override
  String get sessionTime => '会话时长';

  @override
  String get mapTime => '图内计时';

  @override
  String get averageMapTime => '平均每图时长';

  @override
  String get averageRevenue => '平均每图收益';

  @override
  String get normal => '普通';

  @override
  String get magic => '魔法';

  @override
  String get rare => '稀有';

  @override
  String get unique => '传奇';

  @override
  String get kills => '怪物击杀';

  @override
  String get lootDetails => '掉落明细';

  @override
  String get item => '物品';

  @override
  String get quantity => '数量';

  @override
  String get unitPrice => '单价';

  @override
  String get total => '总价';

  @override
  String get noLoot => '当前选择暂无掉落记录';

  @override
  String get pickups => '拾取';

  @override
  String get costs => '消耗';

  @override
  String get noCosts => '暂无消耗';

  @override
  String get waitingForPickups => '等待拾取物品';

  @override
  String get noPrices => '没有符合当前筛选条件的市场价格';

  @override
  String get allCategories => '全部分类';

  @override
  String get searchPrices => '搜索物品';

  @override
  String get league => '联赛';

  @override
  String get syncStatus => '同步状态';

  @override
  String get syncIdle => '空闲';

  @override
  String get syncing => '同步中';

  @override
  String get syncReady => '已同步';

  @override
  String get syncError => '同步失败';

  @override
  String get divineRate => '神圣石汇率';

  @override
  String get lastUpdated => '更新时间';

  @override
  String get refresh => '刷新';

  @override
  String get manualPrice => '手动价格';

  @override
  String get clear => '清除';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get dark => '暗色';

  @override
  String get light => '亮色';

  @override
  String get systemDefault => '跟随系统';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get overlayMode => '小窗模式';

  @override
  String get floating => '悬浮小窗';

  @override
  String get minimal => '极简小窗';

  @override
  String get alwaysOnTop => '窗口置顶';

  @override
  String get clickThrough => '点击穿透';

  @override
  String get textOpacity => '文字透明度';

  @override
  String get backgroundOpacity => '背景透明度';

  @override
  String get priceRefresh => '价格刷新间隔';

  @override
  String get minutes => '分钟';

  @override
  String get tracking => '追踪控制';

  @override
  String get pause => '暂停';

  @override
  String get resume => '继续';

  @override
  String get newSession => '新建会话';

  @override
  String get confirmNewSessionBody => '当前会话将结束并开始新的会话，确定吗？';

  @override
  String get closeWindowTitle => '关闭主窗口';

  @override
  String get closeWindowBody => '要退出程序，还是保留小窗继续统计？';

  @override
  String get minimizeToOverlay => '最小化到小窗';

  @override
  String get closeBehavior => '关闭主窗口时';

  @override
  String get askEveryTime => '每次询问';

  @override
  String get rememberChoice => '记住我的选择';

  @override
  String get confirmNewSession => '新建会话前确认';

  @override
  String get resumeSessionTitle => '继续上一次会话？';

  @override
  String resumeSessionBody(String time, int count, String profit) {
    return '上次会话开始于 $time，已记录 $count 张地图、收益 $profit。要继续累计，还是重新开一个会话？';
  }

  @override
  String get continueSession => '继续上次会话';

  @override
  String get showOverlay => '显示小窗';

  @override
  String get showMain => '显示主界面';

  @override
  String get exitApp => '退出';

  @override
  String get offsetSettings => '内存偏移';

  @override
  String get testOffsets => '测试偏移';

  @override
  String get apply => '应用';

  @override
  String get restoreDefaults => '恢复默认';

  @override
  String get copy => '复制';

  @override
  String get playerInventory => '玩家与背包';

  @override
  String get entity => '实体';

  @override
  String get components => '组件';

  @override
  String get itemOffsets => '物品';

  @override
  String get serverDataOffset => '服务器数据玩家向量';

  @override
  String get playerInventoriesOffset => '玩家背包向量';

  @override
  String get inventoryStride => '背包数组步长';

  @override
  String get inventoryIdOffset => '背包数组 ID';

  @override
  String get inventoryPointerOffset => '背包数组指针';

  @override
  String get inventorySizeOffset => '背包尺寸';

  @override
  String get inventoryItemsOffset => '背包物品列表';

  @override
  String get inventoryItemPointerOffset => '背包物品指针';

  @override
  String get mainInventoryId => '主背包 ID';

  @override
  String get entityDetailsPointerOffset => '实体详情指针';

  @override
  String get entityNameOffset => '实体名称';

  @override
  String get entityComponentListOffset => '实体组件列表';

  @override
  String get entityComponentLookupOffset => '实体组件查找';

  @override
  String get componentBucketOffset => '组件查找桶';

  @override
  String get componentNameStride => '组件名称步长';

  @override
  String get stackCountOffset => '堆叠数量';

  @override
  String get modsRarityOffset => '物品稀有度';

  @override
  String get renderArtOffset => '渲染图标';

  @override
  String get baseNameRowOffset => '显示名称行';

  @override
  String get baseNameOffset => '显示名称';

  @override
  String get pendingValidation => '等待验证';

  @override
  String get validationPassed => '验证通过';

  @override
  String get validationFailed => '验证失败';

  @override
  String get connected => '已连接';

  @override
  String get waitingForGame => '等待游戏';

  @override
  String get safeZone => '安全区';

  @override
  String get trackingActive => '追踪中';

  @override
  String get loading => '正在加载';

  @override
  String get retry => '重试';

  @override
  String get startupWarningTitle => '使用前注意须知';

  @override
  String get startupWarningBody =>
      '本软件使用内存读取技术获取游戏数据，与外挂采用相同技术，所以有包括但不限于封号等风险，仅供学习交流使用。\n使用本软件即表示您已知晓并同意承担风险。';

  @override
  String get acknowledge => '继续';

  @override
  String acknowledgeIn(int seconds) {
    return '$seconds 秒后可关闭';
  }

  @override
  String mapLevel(int level) {
    return '区域等级 $level';
  }

  @override
  String itemsCount(int count) {
    return '$count 项';
  }
}
