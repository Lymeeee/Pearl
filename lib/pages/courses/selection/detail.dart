import 'package:flutter/material.dart';
import '/types/courses.dart';
import '/services/provider.dart';
import '/services/courses/exceptions.dart';
import '/utils/haptic.dart';
import 'common.dart';

class CourseDetailCard extends StatefulWidget {
  final CourseInfo course;
  final TermInfo termInfo;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onSelectionChanged;
  final VoidCallback onRefreshRequired;
  final CooldownHandler cooldownHandler;
  final Set<String> selectedCourseKeys;

  const CourseDetailCard({
    super.key,
    required this.course,
    required this.termInfo,
    required this.isExpanded,
    required this.onToggle,
    required this.onSelectionChanged,
    required this.onRefreshRequired,
    required this.cooldownHandler,
    required this.selectedCourseKeys,
  });

  @override
  State<CourseDetailCard> createState() => _CourseDetailCardState();
}

class _CourseDetailCardState extends State<CourseDetailCard>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  late AnimationController _expansionController;
  late AnimationController _titleController;
  late Animation<double> _expansionAnimation;
  late Animation<double> _titleOpacityAnimation;
  late Animation<Offset> _titleSlideAnimation;

  @override
  bool get wantKeepAlive => widget.isExpanded;

  List<CourseInfo> _courseDetails = [];
  bool _isLoadingDetails = false;
  String? _detailsErrorMessage;
  // 正在提交选课请求的讲台（classId），同一时刻只允许一个
  String? _submittingClassId;

  // Expand/collapse states
  bool _isScheduleExpanded = false;
  bool _isTargetExpanded = false;

  // To locate the details widget in the list context
  final GlobalKey _detailsKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _titleController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOut,
    );

    _titleOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutQuint),
      ),
    );

    _titleSlideAnimation =
        Tween<Offset>(
          begin: const Offset(0.15, 0.05),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _titleController, curve: Curves.easeOutQuint),
        );
  }

  @override
  void didUpdateWidget(CourseDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      updateKeepAlive();
      if (widget.isExpanded) {
        _expansionController.forward();
        _titleController.forward();
        _expansionController.addStatusListener(_onExpansionStatusChanged);
        _loadCourseDetails();
      } else {
        _expansionController.reverse();
        _titleController.reset();
      }
    }
  }

  Future<void> _handleCourseSubmission(
    CourseInfo courseDetail,
    CourseDetail detail,
  ) async {
    // 同一课程已有已选讲台时先警告
    final courseKeyPrefix = '${courseDetail.courseId}#';
    if (widget.selectedCourseKeys.any(
      (key) => key.startsWith(courseKeyPrefix),
    )) {
      if (await alertClassDuplicatedWarning(context) != true) {
        return;
      }
      if (!mounted) return;
    }

    if (detail.isAllFull) {
      if (await alertClassFullWarning(context) != true) {
        return;
      }
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认选课'),
        content: Text('确认提交课程“${courseDetail.courseName}”的选课申请吗？'),
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
            child: const Text('提交'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _submittingClassId = detail.classId;
    });

    var success = false;
    String? errorMessage;
    try {
      success = await _serviceProvider.coursesService
          .sendCourseSelection(widget.termInfo, courseDetail);
      if (!success) {
        errorMessage = '选课失败';
      }
    } on CourseServiceException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      errorMessage = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _submittingClassId = null;
    });

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(success ? '选课成功' : '选课失败'),
          ],
        ),
        content: success
            ? Text('已提交课程“${courseDetail.courseName}”的选课申请。', style: const TextStyle(fontSize: 16))
            : errorMessage == null
            ? null
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '错误原因：$errorMessage',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ),
        actions: [
          FilledButton(
            onPressed: () {
              Haptics.light();
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (success) {
      await _loadCourseDetails();
      widget.onSelectionChanged.call();
      widget.onRefreshRequired();
    }
  }

  Future<void> _handleCourseDeselection(
    CourseInfo courseDetail,
    CourseDetail detail,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CourseDeselectionDialog(
        termInfo: widget.termInfo,
        course: courseDetail,
        onDeselectionComplete: (_) => widget.onRefreshRequired(),
      ),
    );

    if (result == true) {
      if (mounted) {
        // Refresh details and notify parent
        await _loadCourseDetails();
        widget.onSelectionChanged.call();
      }
    }
  }

  Future<void> _loadCourseDetails() async {
    if (!mounted) return;
    widget.cooldownHandler.start(isMounted: () => mounted);

    setState(() {
      _isLoadingDetails = true;
      _detailsErrorMessage = null;
    });

    if (widget.course.classDetail != null) {
      setState(() {
        _courseDetails = [widget.course];
        _isLoadingDetails = false;
      });
      if (mounted) {
        widget.cooldownHandler.finish(isMounted: () => mounted);
      }
      return;
    }

    try {
      final details = await _serviceProvider.coursesService.getCourseDetail(
        widget.termInfo,
        widget.course,
      );
      if (!mounted) return;

      setState(() {
        _courseDetails = details;
        _isLoadingDetails = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _detailsErrorMessage = e.toString();
        _isLoadingDetails = false;
      });
    } finally {
      if (mounted) {
        widget.cooldownHandler.finish(isMounted: () => mounted);
      }
    }
  }

  void _onExpansionStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.isExpanded) {
      _expansionController.removeStatusListener(_onExpansionStatusChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Scroll the list to the details widget
        final context = _detailsKey.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.25,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _expansionController.dispose();
    _titleController.dispose();
    _expansionController.removeStatusListener(_onExpansionStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ClipRect(
      child: AnimatedBuilder(
        animation: _expansionAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _expansionAnimation,
            child: SizeTransition(
              sizeFactor: _expansionAnimation,
              child: _buildExpandedContent(context),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCourseTitle(),
            const SizedBox(height: 20),
            _buildInfoGrid(),
            const SizedBox(height: 20),
            _buildCourseDetailsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseTitle() {
    return SlideTransition(
      position: _titleSlideAnimation,
      child: FadeTransition(
        opacity: _titleOpacityAnimation,
        child: Row(
          key: _detailsKey,
          children: [
            Icon(
              Icons.school,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.combinedName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (widget.course.combinedNameAlt.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.course.combinedNameAlt,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _CourseInfoChip(
          label: '课程性质',
          value: widget.course.courseType,
          icon: Icons.category,
          valueAlt: widget.course.courseTypeAlt,
        ),
        _CourseInfoChip(
          label: '课程类别',
          value: widget.course.courseCategory,
          icon: Icons.class_,
          valueAlt: widget.course.courseCategoryAlt,
        ),
        _CourseInfoChip(
          label: '开课院系',
          value: widget.course.schoolName,
          icon: Icons.domain,
          valueAlt: widget.course.schoolNameAlt,
        ),
        _CourseInfoChip(
          label: '校区',
          value: widget.course.districtName,
          icon: Icons.location_on,
          valueAlt: widget.course.districtNameAlt,
        ),
        _CourseInfoChip(
          label: '语言',
          value: widget.course.teachingLanguage,
          icon: Icons.language,
          valueAlt: widget.course.teachingLanguageAlt,
        ),
      ],
    );
  }

  Widget _buildCourseDetailsList() {
    // Check if this course is already selected
    final isAlreadySelected = widget.selectedCourseKeys.contains(
      widget.course.uniqueKey,
    );

    if (isAlreadySelected) {
      if (widget.course.classDetail != null) {
        return _buildSelectedCourseDetail(widget.course);
      } else {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                '此课程已选',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
              ),
            ],
          ),
        );
      }
    }

    // For non-selected courses
    if (_isLoadingDetails) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              '正在加载课程详情...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_detailsErrorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '加载失败',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _detailsErrorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_courseDetails.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.tertiary, size: 20),
            const SizedBox(width: 12),
            Text(
              '暂无课程详情',
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.list_alt,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '可选讲台列表 (共 ${_courseDetails.length} 个)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._courseDetails.map(
          (courseDetail) => _buildCourseDetailItem(courseDetail),
        ),
      ],
    );
  }

  Widget _buildCourseDetailItem(CourseInfo courseDetail) {
    final detail = courseDetail.classDetail!;
    final isSubmitting = _submittingClassId == detail.classId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: Selection Button (Fixed Width)
            SizedBox(
              width: 60,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: isSubmitting
                      ? null
                      : () async {
                          Haptics.selection();
                          await _handleCourseSubmission(courseDetail, detail);
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSubmitting)
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        else
                          Icon(
                            Icons.add,
                            size: 22,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          isSubmitting ? '提交中' : '选课',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Pre-selection Button (Fixed Width)
            SizedBox(
              width: 60,
              child: _PreSelectButton(
                courseDetail: courseDetail,
                fullWidth: false,
              ),
            ),

            const SizedBox(width: 12),

            // Middle: Basic Info (Flexible)
            Expanded(
              flex: 3,
              child: _buildBasicInfoSection(courseDetail, detail),
            ),

            const SizedBox(width: 12),

            // Right: Capacity Info (Flexible)
            Expanded(flex: 2, child: _buildCapacitySection(detail)),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(CourseInfo courseDetail, CourseDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.extraName?.trim().isNotEmpty == true) ...[
          Row(
            children: [
              Icon(
                Icons.book,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                detail.extraName!.trim(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],

        if (detail.detailTeacherName?.isNotEmpty == true)
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '教师：',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Text(
                  detail.detailTeacherName!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

        if (detail.detailTeacherName?.isNotEmpty == true)
          const SizedBox(height: 8),

        if (detail.detailSchedule?.isNotEmpty == true) ...[
          _buildExpandableList(
            label: '排课：',
            icon: Icons.schedule,
            items: detail.detailSchedule!,
            isExpanded: _isScheduleExpanded,
            onToggle: () {
              setState(() {
                _isScheduleExpanded = !_isScheduleExpanded;
              });
            },
            baseColor: Theme.of(context).colorScheme.tertiary,
          ),
        ],

        if (detail.detailSchedule?.isNotEmpty == true)
          const SizedBox(height: 8),

        if (detail.detailClasses?.isNotEmpty == true)
          Row(
            children: [
              Icon(Icons.class_, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '班级：',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Text(
                  detail.detailClasses!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

        if (detail.detailClasses?.isNotEmpty == true) const SizedBox(height: 8),

        if (detail.detailTarget?.isNotEmpty == true) ...[
          _buildExpandableList(
            label: '面向对象：',
            icon: Icons.group,
            items: detail.detailTarget!,
            isExpanded: _isTargetExpanded,
            onToggle: () {
              setState(() {
                _isTargetExpanded = !_isTargetExpanded;
              });
            },
            baseColor: Theme.of(context).colorScheme.secondary,
          ),
        ],

        if (detail.detailExtra?.isNotEmpty == true &&
            detail.detailExtra != detail.detailClasses)
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '说明：',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Text(
                  detail.detailExtra!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildExpandableList({
    required String label,
    required IconData icon,
    required List<String> items,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Color baseColor,
  }) {
    const maxVisibleItems = 5;
    final visibleItems = isExpanded
        ? items
        : items.take(maxVisibleItems).toList();
    final hasMore = items.length > maxVisibleItems;
    final remainingCount = items.length - maxVisibleItems;

    final chipColor = baseColor.withValues(alpha: 0.1);
    final chipBorderColor = baseColor.withValues(alpha: 0.4);
    final chipTextColor = baseColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: visibleItems
              .map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: chipBorderColor, width: 1),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: chipTextColor,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (hasMore) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              Haptics.selection();
              onToggle();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isExpanded ? '收起' : '展开更多 $remainingCount 个',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCapacitySection(CourseDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '容量信息',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _buildCapacityBars(detail),
      ],
    );
  }

  Widget _buildCapacityBars(CourseDetail detail) {
    List<Widget> bars = [];

    if (detail.hasUg) {
      bars.add(
        _buildCapacityBar(
          label: '本科生',
          current: detail.ugReserved,
          total: detail.ugTotal,
        ),
      );
    }

    if (detail.hasPg) {
      bars.add(
        _buildCapacityBar(
          label: '研究生',
          current: detail.pgReserved,
          total: detail.pgTotal,
        ),
      );
    }

    if (detail.hasMale) {
      bars.add(
        _buildCapacityBar(
          label: '男生',
          current: detail.maleReserved ?? 0,
          total: detail.maleTotal ?? 0,
        ),
      );
    }

    if (detail.hasFemale) {
      bars.add(
        _buildCapacityBar(
          label: '女生',
          current: detail.femaleReserved ?? 0,
          total: detail.femaleTotal ?? 0,
        ),
      );
    }

    if (bars.isEmpty) {
      return Text(
        '暂无容量信息',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      children: bars
          .map(
            (bar) =>
                Padding(padding: const EdgeInsets.only(bottom: 12), child: bar),
          )
          .toList(),
    );
  }

  Widget _buildCapacityBar({
    required String label,
    required int current,
    required int total,
  }) {
    final double progress = total > 0 ? current / total : 0.0;
    final bool isFull = current >= total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            Text(
              '$current/$total',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Bar
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                isFull ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedCourseDetail(CourseInfo courseDetail) {
    final detail = courseDetail.classDetail!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              '已选讲台详情',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Deselection Button (Fixed Width)
                SizedBox(
                  width: 60,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        Haptics.heavy();
                        await _handleCourseDeselection(courseDetail, detail);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              size: 22,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '退课',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Right: Basic Info (Flexible)
                Expanded(child: _buildBasicInfoSection(courseDetail, detail)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? valueAlt;

  const _CourseInfoChip({
    required this.label,
    required this.value,
    required this.icon,
    this.valueAlt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (valueAlt?.isNotEmpty == true)
                Text(
                  valueAlt!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 课程详情弹窗：点击课程行后弹出
class CourseDetailDialog extends StatefulWidget {
  final CourseInfo course;
  final TermInfo termInfo;
  final VoidCallback onSelectionChanged;
  final VoidCallback onRefreshRequired;
  final CooldownHandler cooldownHandler;
  final Set<String> selectedCourseKeys;

  const CourseDetailDialog({
    super.key,
    required this.course,
    required this.termInfo,
    required this.onSelectionChanged,
    required this.onRefreshRequired,
    required this.cooldownHandler,
    required this.selectedCourseKeys,
  });

  @override
  State<CourseDetailDialog> createState() => _CourseDetailDialogState();
}

class _CourseDetailDialogState extends State<CourseDetailDialog> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  // 弹窗内维护一份已选状态，选课成功后就地更新
  late final Set<String> _selectedKeys = Set.of(widget.selectedCourseKeys);

  List<CourseInfo> _courseDetails = [];
  bool _isLoadingDetails = false;
  String? _detailsErrorMessage;
  // 正在提交选课请求的讲台（classId），同一时刻只允许一个
  String? _submittingClassId;

  bool _isScheduleExpanded = false;
  bool _isTargetExpanded = false;

  String get _courseIdPrefix => '${widget.course.courseId}#';

  bool get _hasAnySelection =>
      _selectedKeys.any((key) => key.startsWith(_courseIdPrefix));

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  Future<void> _handleCourseSubmission(
    CourseInfo courseDetail,
    CourseDetail detail,
  ) async {
    // 同一课程已有已选讲台时先警告
    if (_selectedKeys.any((key) => key.startsWith(_courseIdPrefix))) {
      if (await alertClassDuplicatedWarning(context) != true) {
        return;
      }
      if (!mounted) return;
    }

    if (detail.isAllFull) {
      if (await alertClassFullWarning(context) != true) {
        return;
      }
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认选课'),
        content: Text('确认提交课程“${courseDetail.courseName}”的选课申请吗？'),
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
            child: const Text('提交'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _submittingClassId = detail.classId;
    });

    var success = false;
    String? errorMessage;
    try {
      success = await _serviceProvider.coursesService
          .sendCourseSelection(widget.termInfo, courseDetail);
      if (!success) {
        errorMessage = '选课失败';
      }
    } on CourseServiceException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      errorMessage = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _submittingClassId = null;
    });

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(success ? '选课成功' : '选课失败'),
          ],
        ),
        content: success
            ? Text('已提交课程“${courseDetail.courseName}”的选课申请。', style: const TextStyle(fontSize: 16))
            : errorMessage == null
            ? null
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '错误原因：$errorMessage',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ),
        actions: [
          FilledButton(
            onPressed: () {
              Haptics.light();
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (success) {
      setState(() {
        _selectedKeys.add(courseDetail.uniqueKey);
      });
      await _loadCourseDetails();
      widget.onSelectionChanged.call();
      widget.onRefreshRequired();
    }
  }

  Future<void> _handleCourseDeselection(CourseInfo courseDetail) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CourseDeselectionDialog(
        termInfo: widget.termInfo,
        course: courseDetail,
        onDeselectionComplete: (_) => widget.onRefreshRequired(),
      ),
    );

    // 退课成功后关闭弹窗，列表已由 onRefreshRequired 刷新
    if (result == true && mounted) {
      widget.onSelectionChanged.call();
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadCourseDetails() async {
    if (!mounted) return;
    widget.cooldownHandler.start(isMounted: () => mounted);

    setState(() {
      _isLoadingDetails = true;
      _detailsErrorMessage = null;
    });

    if (widget.course.classDetail != null) {
      setState(() {
        _courseDetails = [widget.course];
        _isLoadingDetails = false;
      });
      if (mounted) {
        widget.cooldownHandler.finish(isMounted: () => mounted);
      }
      return;
    }

    try {
      final details = await _serviceProvider.coursesService.getCourseDetail(
        widget.termInfo,
        widget.course,
      );
      if (!mounted) return;

      setState(() {
        _courseDetails = details;
        _isLoadingDetails = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _detailsErrorMessage = e.toString();
        _isLoadingDetails = false;
      });
    } finally {
      if (mounted) {
        widget.cooldownHandler.finish(isMounted: () => mounted);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        clipBehavior: Clip.hardEdge,
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.school,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.course.combinedName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.course.combinedNameAlt.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.course.combinedNameAlt,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Haptics.light();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoGrid(),
                    const SizedBox(height: 20),
                    _buildCourseDetailsList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _CourseInfoChip(
          label: '课程性质',
          value: widget.course.courseType,
          icon: Icons.category,
          valueAlt: widget.course.courseTypeAlt,
        ),
        _CourseInfoChip(
          label: '课程类别',
          value: widget.course.courseCategory,
          icon: Icons.class_,
          valueAlt: widget.course.courseCategoryAlt,
        ),
        _CourseInfoChip(
          label: '开课院系',
          value: widget.course.schoolName,
          icon: Icons.domain,
          valueAlt: widget.course.schoolNameAlt,
        ),
        _CourseInfoChip(
          label: '校区',
          value: widget.course.districtName,
          icon: Icons.location_on,
          valueAlt: widget.course.districtNameAlt,
        ),
        _CourseInfoChip(
          label: '语言',
          value: widget.course.teachingLanguage,
          icon: Icons.language,
          valueAlt: widget.course.teachingLanguageAlt,
        ),
      ],
    );
  }

  Widget _buildCourseDetailsList() {
    // 从已选课程行进入时，直接展示已选讲台详情（含退课）
    if (widget.course.classDetail != null && _hasAnySelection) {
      return _buildSelectedCourseDetail(widget.course);
    }

    // For non-selected courses
    if (_isLoadingDetails) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              '正在加载课程详情...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_detailsErrorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '加载失败',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _detailsErrorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_courseDetails.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.tertiary, size: 20),
            const SizedBox(width: 12),
            Text(
              '暂无课程详情',
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.list_alt,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '可选讲台列表 (共 ${_courseDetails.length} 个)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._courseDetails.map(
          (courseDetail) => _buildCourseDetailItem(courseDetail),
        ),
      ],
    );
  }

  Widget _buildCourseDetailItem(CourseInfo courseDetail) {
    final detail = courseDetail.classDetail!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final infoSection = _buildBasicInfoSection(courseDetail, detail);
          final capacitySection = _buildCapacitySection(detail);
          final isSelectedClass = _selectedKeys.contains(
            courseDetail.uniqueKey,
          );

          // 窄弹窗（手机）改用纵向排布与通栏按钮
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoSection,
                const SizedBox(height: 12),
                capacitySection,
                const SizedBox(height: 12),
                if (isSelectedClass)
                  _buildClassActionButton(
                    courseDetail,
                    detail,
                    fullWidth: true,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildClassActionButton(
                          courseDetail,
                          detail,
                          fullWidth: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PreSelectButton(
                          courseDetail: courseDetail,
                          fullWidth: true,
                        ),
                      ),
                    ],
                  ),
              ],
            );
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Selection Button (Fixed Width)
                SizedBox(
                  width: 60,
                  child: _buildClassActionButton(
                    courseDetail,
                    detail,
                    fullWidth: false,
                  ),
                ),

                if (!isSelectedClass) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: _PreSelectButton(
                      courseDetail: courseDetail,
                      fullWidth: false,
                    ),
                  ),
                ],

                const SizedBox(width: 12),

                // Middle: Basic Info (Flexible)
                Expanded(flex: 3, child: infoSection),

                const SizedBox(width: 12),

                // Right: Capacity Info (Flexible)
                Expanded(flex: 2, child: capacitySection),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 讲台的选课按钮；已选的讲台显示为静态“已选”标记
  Widget _buildClassActionButton(
    CourseInfo courseDetail,
    CourseDetail detail, {
    required bool fullWidth,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isSelectedClass = _selectedKeys.contains(courseDetail.uniqueKey);
    final isSubmitting = _submittingClassId == detail.classId;

    final Widget icon;
    if (isSelectedClass) {
      icon = Icon(Icons.check_circle, size: 22, color: scheme.primary);
    } else if (isSubmitting) {
      icon = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
      );
    } else {
      icon = Icon(Icons.add, size: 22, color: scheme.primary);
    }

    final Widget label = Text(
      isSelectedClass ? '已选' : (isSubmitting ? '提交中' : '选课'),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: scheme.primary,
      ),
      maxLines: 2,
    );

    final Widget decorated = Container(
      height: fullWidth ? 44 : null,
      decoration: BoxDecoration(
        color: isSelectedClass
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: fullWidth
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [icon, const SizedBox(width: 8), label],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [icon, const SizedBox(height: 8), label],
            ),
    );

    if (isSelectedClass) {
      return decorated;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isSubmitting
            ? null
            : () async {
                Haptics.selection();
                await _handleCourseSubmission(courseDetail, detail);
              },
        child: decorated,
      ),
    );
  }

  Widget _buildBasicInfoSection(CourseInfo courseDetail, CourseDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.extraName?.trim().isNotEmpty == true) ...[
          Row(
            children: [
              Icon(
                Icons.book,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                detail.extraName!.trim(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],

        if (detail.detailTeacherName?.isNotEmpty == true)
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '教师：',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Text(
                  detail.detailTeacherName!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

        if (detail.detailTeacherName?.isNotEmpty == true)
          const SizedBox(height: 8),

        if (detail.detailSchedule?.isNotEmpty == true) ...[
          _buildExpandableList(
            label: '排课：',
            icon: Icons.schedule,
            items: detail.detailSchedule!,
            isExpanded: _isScheduleExpanded,
            onToggle: () {
              setState(() {
                _isScheduleExpanded = !_isScheduleExpanded;
              });
            },
            baseColor: Theme.of(context).colorScheme.tertiary,
          ),
        ],

        if (detail.detailSchedule?.isNotEmpty == true)
          const SizedBox(height: 8),

        if (detail.detailClasses?.isNotEmpty == true)
          Row(
            children: [
              Icon(Icons.class_, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '班级：',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Text(
                  detail.detailClasses!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

        if (detail.detailClasses?.isNotEmpty == true) const SizedBox(height: 8),

        if (detail.detailTarget?.isNotEmpty == true) ...[
          _buildExpandableList(
            label: '面向对象：',
            icon: Icons.group,
            items: detail.detailTarget!,
            isExpanded: _isTargetExpanded,
            onToggle: () {
              setState(() {
                _isTargetExpanded = !_isTargetExpanded;
              });
            },
            baseColor: Theme.of(context).colorScheme.secondary,
          ),
        ],

        if (detail.detailExtra?.isNotEmpty == true &&
            detail.detailExtra != detail.detailClasses)
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '说明：',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Text(
                  detail.detailExtra!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildExpandableList({
    required String label,
    required IconData icon,
    required List<String> items,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Color baseColor,
  }) {
    const maxVisibleItems = 5;
    final visibleItems = isExpanded
        ? items
        : items.take(maxVisibleItems).toList();
    final hasMore = items.length > maxVisibleItems;
    final remainingCount = items.length - maxVisibleItems;

    final chipColor = baseColor.withValues(alpha: 0.1);
    final chipBorderColor = baseColor.withValues(alpha: 0.4);
    final chipTextColor = baseColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: visibleItems
              .map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: chipBorderColor, width: 1),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: chipTextColor,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (hasMore) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              Haptics.selection();
              onToggle();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isExpanded ? '收起' : '展开更多 $remainingCount 个',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCapacitySection(CourseDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '容量信息',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _buildCapacityBars(detail),
      ],
    );
  }

  Widget _buildCapacityBars(CourseDetail detail) {
    List<Widget> bars = [];

    if (detail.hasUg) {
      bars.add(
        _buildCapacityBar(
          label: '本科生',
          current: detail.ugReserved,
          total: detail.ugTotal,
        ),
      );
    }

    if (detail.hasPg) {
      bars.add(
        _buildCapacityBar(
          label: '研究生',
          current: detail.pgReserved,
          total: detail.pgTotal,
        ),
      );
    }

    if (detail.hasMale) {
      bars.add(
        _buildCapacityBar(
          label: '男生',
          current: detail.maleReserved ?? 0,
          total: detail.maleTotal ?? 0,
        ),
      );
    }

    if (detail.hasFemale) {
      bars.add(
        _buildCapacityBar(
          label: '女生',
          current: detail.femaleReserved ?? 0,
          total: detail.femaleTotal ?? 0,
        ),
      );
    }

    if (bars.isEmpty) {
      return Text(
        '暂无容量信息',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      children: bars
          .map(
            (bar) =>
                Padding(padding: const EdgeInsets.only(bottom: 12), child: bar),
          )
          .toList(),
    );
  }

  Widget _buildCapacityBar({
    required String label,
    required int current,
    required int total,
  }) {
    final double progress = total > 0 ? current / total : 0.0;
    final bool isFull = current >= total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            Text(
              '$current/$total',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Bar
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                isFull ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedCourseDetail(CourseInfo courseDetail) {
    final detail = courseDetail.classDetail!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              '已选讲台详情',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final infoSection = _buildBasicInfoSection(courseDetail, detail);

              // 窄弹窗（手机）改用纵向排布与通栏退课按钮
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoSection,
                    const SizedBox(height: 12),
                    _buildDeselectButton(courseDetail, fullWidth: true),
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: Deselection Button (Fixed Width)
                    SizedBox(
                      width: 60,
                      child: _buildDeselectButton(
                        courseDetail,
                        fullWidth: false,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Right: Basic Info (Flexible)
                    Expanded(child: infoSection),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 退课按钮：沿用旧的选课/退课按钮配色
  Widget _buildDeselectButton(
    CourseInfo courseDetail, {
    required bool fullWidth,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final Widget icon = Icon(
      Icons.delete_rounded,
      size: 22,
      color: scheme.primary,
    );
    final Widget label = Text(
      '退课',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: scheme.primary,
      ),
      maxLines: 2,
    );

    final Widget decorated = Container(
      height: fullWidth ? 44 : null,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: fullWidth
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [icon, const SizedBox(width: 8), label],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [icon, const SizedBox(height: 8), label],
            ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          Haptics.heavy();
          await _handleCourseDeselection(courseDetail);
        },
        child: decorated,
      ),
    );
  }
}

/// 预填按钮（讲台级）：点击加入/移出预填单，两套详情 UI 共用
class _PreSelectButton extends StatelessWidget {
  final CourseInfo courseDetail;
  final bool fullWidth;

  const _PreSelectButton({
    required this.courseDetail,
    required this.fullWidth,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: PreSelectionStore.instance,
      builder: (context, _) {
        final isPreSelected = PreSelectionStore.instance.contains(
          courseDetail.uniqueKey,
        );

        final Widget icon = Icon(
          isPreSelected ? Icons.playlist_add_check : Icons.playlist_add,
          size: 22,
          color: scheme.tertiary,
        );
        final Widget label = Text(
          isPreSelected ? '已预填' : '预填',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: scheme.tertiary,
          ),
          maxLines: 2,
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Haptics.selection();
              PreSelectionStore.instance.toggle(courseDetail);
            },
            child: Container(
              height: fullWidth ? 44 : null,
              decoration: BoxDecoration(
                color: isPreSelected
                    ? scheme.tertiaryContainer.withValues(alpha: 0.4)
                    : scheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: scheme.tertiary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: fullWidth
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [icon, const SizedBox(width: 8), label],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [icon, const SizedBox(height: 8), label],
                    ),
            ),
          ),
        );
      },
    );
  }
}

