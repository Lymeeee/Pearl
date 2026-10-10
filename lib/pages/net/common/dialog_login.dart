import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/types/net.dart';
import '/utils/haptic.dart';
import '/utils/login_dialog.dart';

class NetLoginDialog extends StatefulWidget {
  const NetLoginDialog({super.key});

  @override
  State<NetLoginDialog> createState() => _NetLoginDialogState();
}

class _NetLoginDialogState extends State<NetLoginDialog>
    with SingleTickerProviderStateMixin {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  late TabController _tabController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _loadCachedCredentials();
  }

  Future<void> _loadCachedCredentials() async {
    try {
      final cachedNetData = _serviceProvider.storeService
          .getConfig<NetUserIntegratedData>(
            "net_account_data",
            NetUserIntegratedData.fromJson,
          );

      if (cachedNetData != null) {
        final data = cachedNetData;
        if (mounted) {
          setState(() {
            _usernameController.text = data.account;
            _passwordController.text = data.password;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load cached credentials: $e');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isLoginAllowed() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    return username.isNotEmpty && password.isNotEmpty;
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 拉登录页解析 checkcode 并建立会话，login() 依赖该状态；
      // 失败重试时也重新获取，避免复用已失效的 checkcode
      await _serviceProvider.netService.getSessionState();

      await _serviceProvider.netService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        final loginData = NetUserIntegratedData(
          account: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        _serviceProvider.storeService.putConfig<NetUserIntegratedData>(
          "net_account_data",
          loginData,
        );
        Navigator.of(context).pop(loginData);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoginDialog(
      title: '统一身份认证',
      description: '校园网自服务系统',
      icon: Icons.wifi,
      iconColor: theme.colorScheme.primary,
      headerColor: theme.colorScheme.primaryContainer,
      onHeaderColor: theme.colorScheme.onPrimaryContainer,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [Tab(text: '账号密码登录')],
              indicatorSize: TabBarIndicatorSize.tab,
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useHorizontalLayout = constraints.maxWidth > 600;
                  if (useHorizontalLayout) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Center(child: _buildLoginForm(theme)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Center(child: _buildStatusArea(theme)),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildLoginForm(theme),
                      const SizedBox(height: 16),
                      _buildStatusArea(theme),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'zifuwu.ustb.edu.cn',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: '用户名',
              hintText: '学工号',
              prefixIcon: const Icon(Icons.person_outline),
              suffixIcon: _usernameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        Haptics.light();
                        setState(() {
                          _usernameController.clear();
                        });
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: _passwordController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        Haptics.light();
                        setState(() {
                          _passwordController.clear();
                        });
                      },
                    )
                  : null,
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (!_isLoading && _isLoginAllowed()) {
                Haptics.medium();
                _handleLogin();
              }
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_isLoading || !_isLoginAllowed())
                ? null
                : () {
                    Haptics.medium();
                    _handleLogin();
                  },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 52),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login, size: 18),
                      SizedBox(width: 8),
                      Text(
                        '登录',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusArea(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isError = _errorMessage != null;
    final statusColor = isError ? scheme.error : scheme.primary;
    final message = isError
        ? '登录失败'
        : _isLoading
        ? '正在登录'
        : '等待登录';
    final progress = isError
        ? 0.0
        : _isLoading
        ? 1.0
        : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isError ? Icons.error_outline : Icons.hourglass_bottom,
          color: statusColor,
          size: 48,
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isError ? scheme.error : null,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: progress == 0.0 ? 0.0 : 1.0,
          child: Container(
            width: 120,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.error, fontSize: 14),
          ),
        ],
      ],
    );
  }
}
