import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/types/donate_prompt.dart';
import '/utils/haptic.dart';

/// 捐赠提醒：第一次打开时弹一次，之后只在每学期初（3 月、9 月当月首次打开）
/// 再弹一次，勾过"不再提醒"就永久静音
class DonatePrompt {
  static const _prefKey = 'donate_prompt_state';

  /// 同一次启动只判定一次，避免首页重建时反复弹
  static bool _checkedThisLaunch = false;

  static DonatePromptState _readState() =>
      ServiceProvider.instance.storeService.getPref<DonatePromptState>(
        _prefKey,
        DonatePromptState.fromJson,
      ) ??
      DonatePromptState();

  static void _writeState(DonatePromptState state) {
    ServiceProvider.instance.storeService.putPref<DonatePromptState>(
      _prefKey,
      state,
    );
  }

  /// 在首页渲染出来之后再调用：该弹就弹，然后记下这次展示
  static Future<void> maybeShow(BuildContext context) async {
    if (_checkedThisLaunch) return;
    _checkedThisLaunch = true;

    final state = _readState();
    if (!_shouldShow(DateTime.now(), state)) return;

    final muted = await showDonateDialog(context, prompt: true);
    // 勾了"不再提醒"就不再补那一句挽留
    if (!muted && context.mounted) {
      await showDonateFollowUp(context);
    }
    _writeState(
      DonatePromptState(
        lastShownAt: DateTime.now().millisecondsSinceEpoch,
        muted: muted || state.muted,
      ),
    );
  }

  static bool _shouldShow(DateTime now, DonatePromptState state) {
    if (state.muted) return false;
    final lastShownAt = state.lastShownAt;
    // 没弹过 = 第一次打开这个 App
    if (lastShownAt == null) return true;
    final windowStart = _semesterWindowStart(now);
    if (windowStart == null) return false;
    return lastShownAt < windowStart.millisecondsSinceEpoch;
  }

  /// 3/1-3/31、9/1-9/30 是学期初窗口，其余时间不打扰
  static DateTime? _semesterWindowStart(DateTime now) {
    if (now.month == 3) return DateTime(now.year, 3, 1);
    if (now.month == 9) return DateTime(now.year, 9, 1);
    return null;
  }
}

/// 捐赠弹窗：切换展示微信 / 支付宝收款码。
///
/// [prompt] 为 true 时是自动弹出的提醒，带建议金额和"不再提醒"，返回是否勾选；
/// 为 false 时是设置页主动点进来的感谢弹窗
Future<bool> showDonateDialog(BuildContext context, {bool prompt = false}) async {
  final theme = Theme.of(context);
  var isWechat = true;
  var muted = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        return AlertDialog(
          title: Text(
            prompt ? '用得还顺手吗？' : '感谢支持！',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prompt) ...[
                  Text(
                    '这个 App 免费、没广告，也没有经费。\n'
                    '如果它帮你省下过找教室、抢座位的时间——',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '¥9.9 请我喝杯奶茶',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '金额随你改，付不付都不影响任何功能',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Center(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('微信支付')),
                      ButtonSegment(value: false, label: Text('支付宝支付')),
                    ],
                    selected: {isWechat},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      Haptics.selection();
                      setDialogState(() => isWechat = selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 收款码是竖版图，用 contain 完整显示，裁掉就扫不出来了
                        SizedBox(
                          width: double.infinity,
                          height: prompt ? 280 : 340,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              isWechat
                                  ? 'assets/donate/wechat.png'
                                  : 'assets/donate/alipay.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isWechat ? '微信扫一扫' : '支付宝扫一扫',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                if (prompt) ...[
                  Checkbox(
                    value: muted,
                    onChanged: (value) {
                      Haptics.selection();
                      setDialogState(() => muted = value ?? false);
                    },
                  ),
                  Text(
                    '不再提醒',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Haptics.light();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('关闭'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  return muted;
}

/// 轻挽留：关掉提醒弹窗之后再问一句
Future<void> showDonateFollowUp(BuildContext context) {
  final theme = Theme.of(context);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        '那我先去写代码啦～',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 260,
        child: Text(
          '要是有帮你省过事，就够啦',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Haptics.light();
            Navigator.of(dialogContext).pop();
          },
          child: const Text('好'),
        ),
      ],
    ),
  );
}
