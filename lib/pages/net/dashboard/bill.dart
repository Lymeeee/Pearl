import 'package:flutter/material.dart';
import '/types/net.dart';
import '/utils/haptic.dart';

/// 近半年账单：每月一行（GB 流量 + 计费），点开看详细单据
class NetBillHistorySection extends StatelessWidget {
  const NetBillHistorySection({super.key, required this.bills});

  final List<MonthlyBill> bills;

  static const int _monthCount = 6;

  /// 近 [_monthCount] 个月（新→旧），按月归组；跨年由 DateTime 自动归一
  List<({DateTime month, List<MonthlyBill> monthBills})> _months() {
    final now = DateTime.now();
    final months = <({DateTime month, List<MonthlyBill> monthBills})>[];
    for (var i = 0; i < _monthCount; i++) {
      final month = DateTime(now.year, now.month - i);
      months.add((
        month: month,
        monthBills: bills
            .where(
              (bill) =>
                  bill.startDate.year == month.year &&
                  bill.startDate.month == month.month,
            )
            .toList(),
      ));
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = _months();
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text('近半年账单', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (var i = 0; i < months.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    _buildMonthRow(context, theme, months[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthRow(
    BuildContext context,
    ThemeData theme,
    ({DateTime month, List<MonthlyBill> monthBills}) entry,
  ) {
    final monthBills = entry.monthBills;
    final flowMb = monthBills.fold<double>(0, (sum, b) => sum + b.usageFlowMb);
    final fee = monthBills.fold<double>(
      0,
      (sum, b) => sum + b.monthlyFee + b.usageFee,
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${entry.month.year}年${entry.month.month}月',
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (monthBills.isEmpty)
            Text(
              '暂无账单',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Text(
              '${(flowMb / 1024).toStringAsFixed(2)} GB · '
              '¥${fee.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (monthBills.isEmpty) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Haptics.selection();
        showDialog<void>(
          context: context,
          builder: (context) => _MonthBillDetailDialog(
            month: entry.month,
            bills: monthBills,
          ),
        );
      },
      child: row,
    );
  }
}

class _MonthBillDetailDialog extends StatelessWidget {
  const _MonthBillDetailDialog({required this.month, required this.bills});

  final DateTime month;
  final List<MonthlyBill> bills;

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  static String _formatDate(DateTime date) =>
      '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';

  static String _formatDateTime(DateTime dateTime) =>
      '${_formatDate(dateTime)} ${_twoDigits(dateTime.hour)}:'
      '${_twoDigits(dateTime.minute)}:${_twoDigits(dateTime.second)}';

  static String _formatDuration(double minutes) {
    final totalMinutes = minutes.toInt();
    if (totalMinutes >= 60 * 24) {
      return '${totalMinutes ~/ (60 * 24)} 天';
    }
    if (totalMinutes >= 60) {
      return '${totalMinutes ~/ 60} 小时';
    }
    return '$totalMinutes 分钟';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('${month.year}年${month.month}月 账单明细'),
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, bill) in bills.indexed) ...[
                if (i > 0) const Divider(height: 24),
                if (bills.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '单据 ${i + 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                _buildItem(
                  theme,
                  '账期',
                  '${_formatDate(bill.startDate)} ~ '
                      '${_formatDate(bill.endDate)}',
                ),
                _buildItem(
                  theme,
                  '套餐',
                  bill.packageName.isEmpty ? '--' : bill.packageName,
                ),
                _buildItem(
                  theme,
                  '基本月租',
                  '¥${bill.monthlyFee.toStringAsFixed(2)}',
                ),
                _buildItem(
                  theme,
                  '时长/流量计费',
                  '¥${bill.usageFee.toStringAsFixed(2)}',
                ),
                _buildItem(
                  theme,
                  '使用时长',
                  _formatDuration(bill.usageDurationMinutes),
                ),
                _buildItem(
                  theme,
                  '使用流量',
                  '${(bill.usageFlowMb / 1024).toStringAsFixed(2)} GB',
                ),
                _buildItem(theme, '出账时间', _formatDateTime(bill.createTime)),
              ],
            ],
          ),
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
  }

  Widget _buildItem(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
