import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '/services/courses/exceptions.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/utils/app_bar.dart';
import '/utils/haptic.dart';
import '/utils/ntp_time.dart';
import 'common.dart';

enum _RequestStatus { pending, sending, success, failed }

/// 预填单：NTP 毫秒时钟 + 发起选课请求 + 预填课程列表
class PreselectionListPage extends StatefulWidget {
  final TermInfo termInfo;

  const PreselectionListPage({super.key, required this.termInfo});

  @override
  State<PreselectionListPage> createState() => _PreselectionListPageState();
}

class _PreselectionListPageState extends State<PreselectionListPage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  final PreSelectionStore _store = PreSelectionStore.instance;
  final math.Random _random = math.Random();

  Timer? _cooldownTicker;
  DateTime _cooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);
  int _cooldownTotalSeconds = 0;
  bool _isSending = false;

  final Map<String, _RequestStatus> _statuses = {};
  final Map<String, String> _errorMessages = {};

  @override
  void initState() {
    super.initState();
    _syncTime();
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  Future<void> _syncTime() async {
    await NtpTime.sync();
    if (mounted) setState(() {});
  }

  bool get _isCoolingDown => DateTime.now().isBefore(_cooldownUntil);

  int get _cooldownRemainingSeconds =>
      _cooldownUntil.difference(DateTime.now()).inSeconds + 1;

  Future<void> _startRequests() async {
    // 3~10 秒随机冷却，避免手快连点
    final cooldownSeconds = 3 + _random.nextInt(8);
    setState(() {
      _isSending = true;
      _cooldownTotalSeconds = cooldownSeconds;
      _cooldownUntil = DateTime.now().add(Duration(seconds: cooldownSeconds));
    });

    // 冷却倒计时/进度条刷新；冷却结束后自行停止
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (!_isCoolingDown) timer.cancel();
    });

    // 串行逐门发起：不给服务器压力，顺序与列表一致
    final courses = List.of(_store.courses);
    for (final course in courses) {
      if (!mounted) return;
      setState(() {
        _statuses[course.uniqueKey] = _RequestStatus.sending;
        _errorMessages.remove(course.uniqueKey);
      });

      try {
        final success = await _serviceProvider.coursesService
            .sendCourseSelection(widget.termInfo, course);
        if (!mounted) return;
        setState(() {
          _statuses[course.uniqueKey] = success
              ? _RequestStatus.success
              : _RequestStatus.failed;
          if (!success) {
            _errorMessages[course.uniqueKey] = '服务器未接受该选课请求';
          }
        });
      } on CourseServiceException catch (e) {
        if (!mounted) return;
        setState(() {
          _statuses[course.uniqueKey] = _RequestStatus.failed;
          _errorMessages[course.uniqueKey] = e.message;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _statuses[course.uniqueKey] = _RequestStatus.failed;
          _errorMessages[course.uniqueKey] = '$e';
        });
      }
    }

    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '预填单'),
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          final courses = _store.courses;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _NtpClockCard(onRetry: _syncTime),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildLaunchPanel(courses),
              ),
              Expanded(child: _buildCourseList(courses)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  '越靠前的课程越先发起请求，推荐把重要的课程置前～',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLaunchPanel(List<CourseInfo> courses) {
    final scheme = Theme.of(context).colorScheme;
    final canLaunch = courses.isNotEmpty && !_isSending && !_isCoolingDown;

    final String label;
    if (_isSending) {
      label = '正在逐个发起...';
    } else if (_isCoolingDown) {
      label = '冷却中 ${_cooldownRemainingSeconds}s';
    } else {
      label = '按预填单快速选课';
    }

    final double? progress;
    if (_cooldownTotalSeconds > 0 && _isCoolingDown) {
      progress = (1 - _cooldownRemainingSeconds / _cooldownTotalSeconds).clamp(
        0.0,
        1.0,
      );
    } else {
      progress = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: canLaunch
                ? () {
                    Haptics.heavy();
                    _startRequests();
                  }
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: progress, minHeight: 4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseList(List<CourseInfo> courses) {
    if (courses.isEmpty) {
      return Center(
        child: Text(
          '预填单为空',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // 发送过程中顺序即请求顺序，禁止拖动
    if (_isSending) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: courses.length,
        itemBuilder: (context, index) =>
            _buildCourseTile(courses[index], index),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: courses.length,
      // 关掉系统默认拖拽把手（桌面端会叠在自绘把手/删除键上）
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final value = Curves.easeInOut.transform(animation.value);
            return Material(
              color: Colors.transparent,
              elevation: 6 * value,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: child,
            );
          },
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        Haptics.selection();
        _store.reorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) => _buildCourseTile(courses[index], index),
    );
  }

  Widget _buildCourseTile(CourseInfo course, int index) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = _statuses[course.uniqueKey] ?? _RequestStatus.pending;
    final error = _errorMessages[course.uniqueKey];

    final teacher = course.classDetail?.detailTeacherName ?? '';
    final subtitle = teacher.isEmpty
        ? course.courseId
        : '${course.courseId} $teacher';

    // 整卡长按可拖拽（保留移动端习惯），把手为即时拖拽
    return ReorderableDelayedDragStartListener(
      key: ValueKey(course.uniqueKey),
      index: index,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.combinedName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '失败原因：$error',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusIndicator(status),
              IconButton(
                onPressed: _isSending
                    ? null
                    : () {
                        Haptics.light();
                        setState(() {
                          _statuses.remove(course.uniqueKey);
                          _errorMessages.remove(course.uniqueKey);
                        });
                        _store.remove(course.uniqueKey);
                      },
                icon: const Icon(Icons.delete_outline),
                tooltip: '移出预填单',
              ),
              if (!_isSending)
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(_RequestStatus status) {
    final scheme = Theme.of(context).colorScheme;

    if (status == _RequestStatus.sending) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final (String text, Color color) = switch (status) {
      _RequestStatus.pending => ('待发起', scheme.onSurfaceVariant),
      _RequestStatus.success => ('成功', scheme.primary),
      _RequestStatus.failed => ('失败', scheme.error),
      _RequestStatus.sending => ('发送中', scheme.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// NTP 毫秒时钟卡片：跟随屏幕帧同步刷新（60/120Hz），毫秒位平滑滚动
class _NtpClockCard extends StatefulWidget {
  final VoidCallback onRetry;

  const _NtpClockCard({required this.onRetry});

  @override
  State<_NtpClockCard> createState() => _NtpClockCardState();
}

class _NtpClockCardState extends State<_NtpClockCard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = NtpTime.now();

    String two(int value) => value.toString().padLeft(2, '0');
    final main = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    final millis = now.millisecond.toString().padLeft(3, '0');

    final statusText = NtpTime.isSyncing
        ? '校准中...'
        : NtpTime.isSynced
        ? '${NtpTime.sourceType}时间已校准\n${NtpTime.sourceHost}'
        : '联网校准失败\n您的设备时间或许有偏差\n点击尝试再次刷新';
    final statusColor = NtpTime.isSyncing
        ? scheme.onSurfaceVariant
        : NtpTime.isSynced
        ? scheme.primary
        : scheme.error;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'NTP 时间',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: (!NtpTime.isSynced && !NtpTime.isSyncing)
                      ? () {
                          Haptics.light();
                          widget.onRetry();
                        }
                      : null,
                  child: Text(
                    statusText,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: main,
                    style: TextStyle(
                      fontSize: 44,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: '.$millis',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: scheme.tertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
