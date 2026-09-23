import 'package:flutter/material.dart';
import '/utils/haptic.dart';

/// 捐赠弹窗：切换展示微信 / 支付宝收款码
Future<void> showDonateDialog(BuildContext context) {
  final theme = Theme.of(context);
  var isWechat = true;

  return showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(
            '感谢支持！',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
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
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 收款码是竖版图，用 contain 完整显示，裁掉就扫不出来了
                        SizedBox(
                          height: 340,
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
            TextButton(
              onPressed: () {
                Haptics.light();
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    ),
  );
}
