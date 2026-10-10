import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/utils/app_bar.dart';
import '/utils/haptic.dart';
import '/utils/navigation.dart';
import 'common.dart';
import 'list.dart';

class CourseSelectionPage extends StatefulWidget {
  const CourseSelectionPage({super.key});

  @override
  State<CourseSelectionPage> createState() => _CourseSelectionPageState();
}

class _CourseSelectionPageState extends State<CourseSelectionPage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  List<TermInfo> _terms = [];
  TermInfo? _selectedTerm;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _serviceProvider.addListener(_onServiceStatusChanged);
    _loadTerms();
  }

  @override
  void dispose() {
    _serviceProvider.removeListener(_onServiceStatusChanged);
    // 退出选课流程（回首页）时清空预填单
    PreSelectionStore.instance.clear();
    super.dispose();
  }

  void _onServiceStatusChanged() {
    if (mounted && _serviceProvider.coursesService.isOnline) {
      setState(() {
        _loadTerms();
      });
    }
  }

  Future<void> _loadTerms() async {
    if (!mounted || !_serviceProvider.coursesService.isOnline) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final terms = await _serviceProvider.coursesService.getTerms();
      if (!mounted) return;

      setState(() {
        _terms = terms;
        if (terms.isNotEmpty) {
          final currentTerm = TermInfo.autoDetect();
          TermInfo? selectedTerm;
          for (final term in terms) {
            if (term.year == currentTerm.year &&
                term.season == currentTerm.season) {
              selectedTerm = term;
              break;
            }
          }
          _selectedTerm = selectedTerm ?? terms.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCourseTabs() async {
    if (_selectedTerm == null || !mounted) return;

    if (!_serviceProvider.coursesService.isOnline) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CourseListPage(termInfo: _selectedTerm!),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(title: '选课'),
      body: _buildTermSelectionView(),
    );
  }

  Widget _buildTermSelectionView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Card.filled(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '加载失败',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Haptics.light();
                            _loadTerms();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  if (!_serviceProvider.coursesService.isOnline)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Container(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(
                                  Icons.login,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              onPressed: () {
                                Haptics.selection();
                                pushPathGuarded(context, '/courses/account');
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '请先登录',
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    const Spacer(),
                    Card.filled(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today),
                                const SizedBox(width: 12),
                                Text(
                                  '学期选择',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<TermInfo>(
                              initialValue: _selectedTerm,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: _terms.map((term) {
                                return DropdownMenuItem(
                                  value: term,
                                  child: Text(
                                    '${term.year}学年 第${term.season}学期',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (TermInfo? newTerm) {
                                Haptics.selection();
                                if (mounted) {
                                  setState(() {
                                    _selectedTerm = newTerm;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 与卡片内下拉框等宽：左右缩进等于卡片内边距
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _buildDisclaimer(),
                    ),
                    const Spacer(),
                  ],

                  if (_serviceProvider.coursesService.isOnline) ...[
                    FilledButton.icon(
                      onPressed: _selectedTerm != null && !_isLoading
                          ? () {
                              Haptics.medium();
                              _loadCourseTabs();
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('开始选课'),
                    ),

                    const SizedBox(height: 16),

                    if (_selectedTerm == null)
                      Text(
                        '请先选择学期才能开始选课',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '为保障公平，本软件不设自动抢课功能，因此不对选课成功率作保证。选课事关重要，请及时登录本研一体查看课程选择是否正确，有无漏选错选。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
