import 'package:flutter/material.dart';

/// No-op replacement for the removed sync wrapper.
/// Simply renders the child without any sync logic.
class SyncPowered extends StatelessWidget {
  final WidgetBuilder childBuilder;
  final VoidCallback? onSyncStart;
  final VoidCallback? onSyncEnd;

  const SyncPowered({
    super.key,
    required this.childBuilder,
    this.onSyncStart,
    this.onSyncEnd,
  });

  @override
  Widget build(BuildContext context) {
    return childBuilder(context);
  }
}
