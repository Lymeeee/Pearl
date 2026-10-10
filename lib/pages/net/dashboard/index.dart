import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '/pages/net/common/dialog_login.dart';
import '/types/net.dart';
import '/utils/app_bar.dart';
import '/utils/page_mixins.dart';
import 'dialog_change_pswd.dart';
import 'dialog_device_show.dart';
import 'dialog_device_add.dart';
import 'dialog_online_device_show.dart';
import 'dialog_plan_show.dart';
import 'dialog_change_max_consume.dart';
import 'bill.dart';
import '/utils/haptic.dart';

class NetDashboardPage extends StatefulWidget {
  const NetDashboardPage({super.key});

  @override
  State<NetDashboardPage> createState() => _NetDashboardPageState();
}

class _NetDashboardPageState extends State<NetDashboardPage>
    with PageStateMixin, LoadingStateMixin {
  NetUserInfo? _userInfo;
  List<MacDevice>? _macDevices;
  List<NetOnlineSession> _onlineSessions = const [];
  final ValueNotifier<List<NetOnlineSession>> _onlineSessionsNotifier =
      ValueNotifier<List<NetOnlineSession>>(const []);
  Timer? _sessionPollTimer;
  bool _isRefreshingSessions = false;
  static const Duration _sessionPollInterval = Duration(seconds: 10);

  List<MonthlyBill> _monthlyBills = const [];

  bool _isLoggingOut = false;
  bool _isLoadingLogin = false;

  bool get _isOnline => serviceProvider.netService.isOnline;

  @override
  void onServiceInit() {
    _refreshData();
    if (_isOnline) {
      _startSessionPolling();
    }
  }

  @override
  void onServiceStatusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      if (_isOnline) {
        _startSessionPolling();
        _refreshData();
      } else {
        _stopSessionPolling();
        setState(() {
          _userInfo = null;
          _macDevices = null;
          _onlineSessions = const [];
          _monthlyBills = const [];
        });
        _onlineSessionsNotifier.value = const [];
      }
    });
  }

  @override
  void dispose() {
    _stopSessionPolling();
    _onlineSessionsNotifier.dispose();
    super.dispose();
  }

  void _startSessionPolling() {
    _sessionPollTimer?.cancel();
    _sessionPollTimer = Timer.periodic(
      _sessionPollInterval,
      (_) => _refreshOnlineSessionsSilently(),
    );
  }

  void _stopSessionPolling() {
    _sessionPollTimer?.cancel();
    _sessionPollTimer = null;
  }

  Future<void> _refreshOnlineSessionsSilently() async {
    if (!_isOnline || _isRefreshingSessions) return;
    _isRefreshingSessions = true;
    try {
      final sessions = await serviceProvider.netService.getOnlineSessionList();
      if (!mounted) return;
      setState(() => _onlineSessions = sessions);
      _onlineSessionsNotifier.value = sessions;
    } catch (_) {
      // 静默刷新失败时保留旧数据
    } finally {
      _isRefreshingSessions = false;
    }
  }

  Future<void> _refreshData() async {
    if (!_isOnline) {
      setState(() {
        _userInfo = null;
        _macDevices = null;
        _onlineSessions = const [];
        _monthlyBills = const [];
      });
      _onlineSessionsNotifier.value = const [];
      return;
    }

    setLoading(true);
    try {
      final results = await Future.wait([
        serviceProvider.netService.getUser(),
        serviceProvider.netService.getDeviceList(),
        serviceProvider.netService.getOnlineSessionList(),
        for (final year in _recentBillYears())
          serviceProvider.netService.getMonthPay(year: year),
      ]);
      final info = results[0] as NetUserInfo;
      final macDevices = results[1] as List<MacDevice>;
      final sessions = results[2] as List<NetOnlineSession>;
      final bills = results
          .sublist(3)
          .expand((result) => result as List<MonthlyBill>)
          .toList();
      if (!mounted) return;
      setState(() {
        _userInfo = info;
        _macDevices = macDevices;
        _onlineSessions = sessions;
        _monthlyBills = bills;
      });
      _onlineSessionsNotifier.value = sessions;
    } catch (e) {
      if (!mounted) return;
      setError(e.toString());
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _userInfo = null;
          _macDevices = null;
          _onlineSessions = const [];
          _monthlyBills = const [];
        });
        _onlineSessionsNotifier.value = const [];
      }
    } finally {
      if (mounted) {
        setLoading(false);
      }
    }
  }

  /// 近六个月账单窗口涉及到的年份（跨年时为两个）
  static Set<int> _recentBillYears() {
    final now = DateTime.now();
    return {now.year, DateTime(now.year, now.month - 5).year};
  }

  Future<void> _refreshUserInfo() async {
    if (!_isOnline) return;
    try {
      final info = await serviceProvider.netService.getUser();
      if (!mounted) return;
      setState(() => _userInfo = info);
    } catch (e) {
      if (!mounted) return;
      setError('刷新账户信息失败：$e');
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _userInfo = null;
          _macDevices = null;
        });
      }
    }
  }

  Future<void> _refreshDevices() async {
    if (!_isOnline) return;
    setState(() => _macDevices = null);
    try {
      final results = await Future.wait([
        serviceProvider.netService.getDeviceList(),
        serviceProvider.netService.getOnlineSessionList(),
      ]);
      final macDevices = results[0] as List<MacDevice>;
      final sessions = results[1] as List<NetOnlineSession>;
      if (!mounted) return;
      setState(() {
        _macDevices = macDevices;
        _onlineSessions = sessions;
      });
      _onlineSessionsNotifier.value = sessions;
    } catch (e) {
      if (!mounted) return;
      setError('刷新设备列表失败：$e');
      if (!serviceProvider.netService.isOnline) {
        setState(() {
          _userInfo = null;
          _macDevices = null;
          _onlineSessions = const [];
        });
        _onlineSessionsNotifier.value = const [];
      }
    }
  }

  Future<void> _showLoginDialog() async {
    setState(() => _isLoadingLogin = true);
    try {
      final result = await showDialog<NetUserIntegratedData>(
        context: context,
        builder: (context) => NetLoginDialog(),
      );

      if (result != null) {
        await _refreshData();
      }
    } finally {
      if (mounted) setState(() => _isLoadingLogin = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => NetChangePasswordDialog(),
      );

      if (result == true) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('更改校园网密码成功')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更改校园网密码失败：$e')));
        _refreshUserInfo();
      }
    }
  }

  Future<void> _showPlanDialog() async {
    if (_userInfo?.plan == null) return;
    await showDialog(
      context: context,
      builder: (context) => NetPlanShowDialog(userInfo: _userInfo!),
    );
  }

  Future<void> _showChangeMaxConsumeDialog() async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) =>
            NetChangeMaxConsumeDialog(currentMaxConsume: _userInfo?.maxConsume),
      );

      if (result == true) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('更改限额成功')));
        }
        await _refreshUserInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更改限额失败：$e')));
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    setState(() => _isLoggingOut = true);
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认登出'),
          content: const Text(
            '确定要退出校园网自助服务账号吗？'
            '\n\n'
            '这不会影响本机的校园网连接。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Haptics.light();
                Navigator.of(context).pop(false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Haptics.medium();
                Navigator.of(context).pop(true);
              },
              child: const Text('确认'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await serviceProvider.netService.logout();
          // Clear cached login data
          serviceProvider.storeService.delConfig("net_account_data");
          if (mounted) {
            setState(() {
              _userInfo = null;
              _macDevices = null;
            });
          }
        } catch (e) {
          if (mounted) setError('登出发生错误：$e');
          if (!serviceProvider.netService.isOnline) {
            setState(() {
              _userInfo = null;
              _macDevices = null;
            });
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _handleUnbindMac(MacDevice device) async {
    final normalizedMac = device.mac.toLowerCase();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解绑设备'),
        content: Text(
          '确定要解绑物理地址（MAC 地址）为 ${device.mac.toUpperCase()} 的设备吗？'
          '\n\n'
          '解绑后，该设备需要重新登录校园网。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Haptics.light();
              Navigator.of(context).pop(false);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Haptics.medium();
              Navigator.of(context).pop(true);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await serviceProvider.netService.setMacUnbounded(normalizedMac);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('解绑设备成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('解绑设备失败：$e')));
      }
    } finally {
      await _refreshDevices();
    }
  }

  Future<void> _showAddDeviceDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const NetAddDeviceDialog(),
    );

    if (result != null) {
      await _handleAddDevice(result['mac']!, result['name'] ?? '');
    }
  }

  Future<void> _handleAddDevice(String mac, String name) async {
    final macRegex = RegExp(
      r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$|^[0-9A-Fa-f]{12}$',
    );
    if (!macRegex.hasMatch(mac)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MAC 地址格式不正确')));
      }
      return;
    }

    try {
      await serviceProvider.netService.setMacBounded(mac, terminalName: name);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('添加设备成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加设备失败：$e')));
      }
    } finally {
      await _refreshDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: '网络服务',
        actions: _isOnline ? [_buildRefreshButton()] : null,
      ),
      body: _buildBody(context),
    );
  }

  /// 右上角统一刷新键：刷新期间置灰不可点并转圈
  Widget _buildRefreshButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: '刷新',
        child: FilledButton(
          onPressed: isLoading
              ? null
              : () {
                  Haptics.light();
                  _refreshData();
                },
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasError)
                  Card.filled(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              errorMessage ?? '未知错误',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Haptics.light();
                              clearError();
                            },
                            icon: Icon(
                              Icons.close,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                if (_isOnline && _userInfo != null) ...[
                  _buildUserInfoCard(
                    theme,
                    _userInfo!,
                    onLogout: _showLogoutDialog,
                  ),
                  const SizedBox(height: 16),
                  _buildMacListCard(theme),
                  const SizedBox(height: 16),
                  NetBillHistorySection(bills: _monthlyBills),
                ],

                if (_userInfo == null && (!_isOnline || hasError))
                  _buildLoginView(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 未登录视图：样式对齐图书馆/教务账户页
  Widget _buildLoginView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本机登录状态', style: theme.textTheme.bodySmall),
                      Text(
                        '未登录',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text('登录方式', style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: ListTile(
            leading: Icon(
              Icons.security,
              color: theme.colorScheme.primary,
              size: 32,
            ),
            title: const Text('统一身份认证登录'),
            subtitle: const Text('使用北京科技大学SSO系统'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _isLoadingLogin
                ? null
                : () {
                    Haptics.medium();
                    _showLoginDialog();
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard(
    ThemeData theme,
    NetUserInfo info, {
    required VoidCallback onLogout,
  }) {
    return Card(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_circle,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('校园网账户', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                info.realName,
                                style: theme.textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                info.accountName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton.icon(
                          label: const Text('登出'),
                          icon: _isLoggingOut
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.logout),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                          ),
                          onPressed: _isLoggingOut
                              ? null
                              : () {
                                  Haptics.heavy();
                                  _showLogoutDialog();
                                },
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Divider(height: 4),
                  // Flow progress bar section
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_buildFlowProgressBarContent(theme, info)],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                          size: 12, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('余额',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(width: 6),
                      Text('¥${info.moneyLeft.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrowScreen = constraints.maxWidth < 300;
                final items = [
                  if (info.plan != null)
                    (
                      Icons.wifi,
                      '套餐',
                      info.plan!.planName,
                      _showPlanDialog as VoidCallback?,
                    ),
                  (
                    Icons.security,
                    '限额',
                    info.maxConsume == null || info.maxConsume! >= 999999
                        ? '未设置'
                        : '¥${info.maxConsume}',
                    _showChangeMaxConsumeDialog as VoidCallback?,
                  ),
                  (
                    Icons.lock,
                    '密码',
                    '修改密码',
                    (_isLoggingOut ? null : _showChangePasswordDialog)
                        as VoidCallback?,
                  ),
                ];

                if (isNarrowScreen) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(
                      items.length,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index < items.length - 1 ? 8 : 0,
                        ),
                        child: _buildActionChip(
                          theme,
                          icon: items[index].$1,
                          label: items[index].$2,
                          value: items[index].$3,
                          onPressed: items[index].$4,
                          isFullWidth: true,
                        ),
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: items
                      .map(
                        (item) => _buildActionChip(
                          theme,
                          icon: item.$1,
                          label: item.$2,
                          value: item.$3,
                          onPressed: item.$4,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onPressed,
    bool isFullWidth = false,
  }) {
    final content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        if (isFullWidth)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
      ],
    );

    final container = Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: content,
    );

    if (onPressed != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            onPressed();
          },
          borderRadius: BorderRadius.circular(8),
          child: container,
        ),
      );
    }

    return container;
  }

  Widget _buildFlowProgressBarContent(ThemeData theme, NetUserInfo info) {
    final freeFlow = info.plan?.freeFlow ?? 0.0;
    final flowUsed = info.flowUsed;
    final flowLeft = freeFlow > 0
        ? math.min(info.flowLeft, freeFlow - flowUsed)
        : info.flowLeft;

    final hasPackage = freeFlow > 0;
    final freeGB = freeFlow / 1024;
    final usedGB = flowUsed / 1024;
    final leftGB = flowLeft / 1024;
    final isOverLimit = hasPackage && flowLeft <= 0;
    final exceededGB = isOverLimit ? -leftGB : 0.0;

    // Determine ratios and colors for the cool progress bar
    Color backgroundColor;
    double ratio;

    if (hasPackage) {
      if (isOverLimit) {
        backgroundColor = theme.colorScheme.error;
        ratio = freeFlow / (flowUsed > 0 ? flowUsed : 1.0);
      } else {
        backgroundColor = theme.colorScheme.secondaryContainer;
        ratio = flowUsed / (freeFlow > 0 ? freeFlow : 1.0);
      }
    } else {
      // No package, pure blue bar representing current usage
      backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.1);
      ratio = 1.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 16, // Fixed height for the progress bar
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Right side color (Remaining or Exceeded)
                    Container(color: backgroundColor),
                    // Left side color (Used or Limit)
                    if (ratio > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * ratio,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Labels
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            if (!isOverLimit) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '已用 ${usedGB.toStringAsFixed(2)} GB',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (hasPackage && leftGB > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '剩余 ${leftGB.toStringAsFixed(2)} GB',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
            if (isOverLimit) ...[
              if (freeFlow > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '配额 ${freeGB.toStringAsFixed(2)} GB',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '超出 ${exceededGB.toStringAsFixed(2)} GB',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _macKey(String mac) =>
      mac.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');

  static String _formatMac(String rawMac) {
    var displayMac = rawMac.toUpperCase();
    if (RegExp(r'^[0-9A-F]{12}$').hasMatch(displayMac)) {
      displayMac = displayMac.replaceAllMapped(
        RegExp(r'.{2}'),
        (match) => '${match.group(0)}:',
      );
      displayMac = displayMac.substring(0, displayMac.length - 1);
    }
    return displayMac;
  }

  /// 已绑定设备与当前在线会话按 MAC 合并为一张列表
  List<({MacDevice? bound, NetOnlineSession? session})> _mergedDevices() {
    final merged = <String, ({MacDevice? bound, NetOnlineSession? session})>{};
    for (final device in _macDevices ?? const <MacDevice>[]) {
      final existing = merged[_macKey(device.mac)];
      merged[_macKey(device.mac)] = (bound: device, session: existing?.session);
    }
    for (final session in _onlineSessions) {
      final existing = merged[_macKey(session.mac)];
      merged[_macKey(session.mac)] = (bound: existing?.bound, session: session);
    }
    return merged.values.toList();
  }

  Widget _buildMacListCard(ThemeData theme) {
    final devices = _macDevices == null ? null : _mergedDevices();
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.devices_other,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('我的设备', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            if (devices == null)
              SizedBox(
                height: 80,
                child: Center(
                  child: Text('正在载入设备列表', style: theme.textTheme.bodyMedium),
                ),
              )
            else if (devices.isEmpty)
              SizedBox(
                height: 80,
                child: Center(
                  child: Text('暂无设备', style: theme.textTheme.bodyMedium),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final merged = devices[index];
                  return _buildDeviceTile(
                    theme,
                    context,
                    bound: merged.bound,
                    session: merged.session,
                  );
                },
              ),
            const SizedBox(height: 16),
            if (_macDevices != null && _macDevices!.length < 5)
              FilledButton.icon(
                onPressed: () {
                  Haptics.medium();
                  _showAddDeviceDialog();
                },
                icon: const Icon(Icons.add),
                label: const Text('手动添加新设备'),
              ),
          ],
        ),
      ),
    );
  }

  /// 详情入口：已绑定设备优先（支持重命名），仅在线未绑定的看连接详情
  void _showDeviceDetail({MacDevice? bound, NetOnlineSession? session}) {
    if (bound != null) {
      showDialog(
        context: context,
        builder: (context) => NetDeviceShowDialog(
          device: bound,
          onRename: (newName) async {
            try {
              await serviceProvider.netService.renameMac(
                bound.mac,
                terminalName: newName,
              );
            } catch (_) {
              return false;
            }
            await _refreshDevices();
            return true;
          },
        ),
      );
    } else if (session != null) {
      showDialog(
        context: context,
        builder: (context) => NetOnlineDeviceShowDialog(
          session: session,
          sessionsListenable: _onlineSessionsNotifier,
        ),
      );
    }
  }

  Widget _buildDeviceTile(
    ThemeData theme,
    BuildContext context, {
    required MacDevice? bound,
    required NetOnlineSession? session,
  }) {
    final isOnline = session != null || (bound?.isOnline ?? false);
    final displayMac = _formatMac(bound?.mac ?? session?.mac ?? '');
    final boundName = bound?.name.trim() ?? '';
    final sessionName = session?.deviceName.trim() ?? '';
    final deviceName = boundName.isNotEmpty
        ? boundName
        : (sessionName.isNotEmpty ? sessionName : '未命名设备');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              size: 22,
              isOnline ? Icons.link : Icons.link_off,
              color: isOnline
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayMac,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  deviceName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            iconSize: 20,
            color: theme.colorScheme.primary,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Haptics.selection();
              _showDeviceDetail(bound: bound, session: session);
            },
            icon: const Icon(Icons.info_outline),
            tooltip: '详情',
          ),
          if (bound != null)
            IconButton(
              iconSize: 20,
              color: theme.colorScheme.error,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Haptics.heavy();
                _handleUnbindMac(bound);
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: '解绑设备',
            ),
        ],
      ),
    );
  }
}
