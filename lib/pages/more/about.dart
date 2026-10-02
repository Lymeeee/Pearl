import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/utils/app_bar.dart';
import '/utils/haptic.dart';
import '/utils/meta_info.dart';

/// 关于页
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _appName = 'Pearl';
  static const _repoUrl = 'https://github.com/Lymeeee/Pearl';
  static const _upstreamUrl = 'https://github.com/isHarryh/The-Beike';

  static const _noBorderShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(title: '关于'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildTextCard(context, '关于这个 App', [
            '本 APP 为 GitHub 上 isHarryh 的大贝壳的 Fork，以此为底座进行了'
                '强迫症级别的 MD3 界面重构，以及加了一些自己常用的功能。',
            '如果用得开心，求求慷慨解囊点点捐赠喵，哪里用得不舒心或者'
                '有什么新功能建议请使劲提意见喵谢谢喵。',
          ]),
          const SizedBox(height: 16),
          _buildActionCard(
            context,
            icon: Icons.code,
            title: '项目仓库',
            subtitle: 'github.com/Lymeeee/Pearl',
            onTap: () => _openLink(context, _repoUrl),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            context,
            icon: Icons.bug_report_outlined,
            title: '反馈问题',
            subtitle: '在仓库里提 Issue',
            onTap: () => _openLink(context, '$_repoUrl/issues'),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            context,
            icon: Icons.auto_awesome_outlined,
            title: '原作者项目',
            subtitle: 'isHarryh 的「大贝壳」',
            onTap: () => _openLink(context, _upstreamUrl),
          ),
          const SizedBox(height: 16),
          _buildTextCard(context, '隐私', [
            '本 APP 仅仅为第三方前端实现，一切联网更改都会直通到学校后端服务器，'
                '中间不存在任何中间人截获，包括开发者自己。',
          ]),
          const SizedBox(height: 16),
          _buildTextCard(context, '免责', [
            '本 APP 为学生个人业余时间开发，与北京科技大学官方无任何关系，'
                'APP 内并无任何例如抢课等破坏公平性的功能。',
            '受学校服务端安全政策限制，账号在登录一段时间后自动被注销系正常现象。',
          ]),
          const SizedBox(height: 16),
          _buildLicenseCard(context),
          const SizedBox(height: 16),
          _buildTextCard(context, '写在后面', [
            '一开始哪里想过这么多',
            '只是感觉ibeike社团的课表小程序太难用了',
            '获取课表好麻烦，界面也不太好看，而且功能也不多',
            '后来在索思linux群里看到了harry和他的大贝壳',
            '功能的整合程度让年轻的我大受震撼，我去，这简直就是我的dream app',
            '但是凡事都没有完美，大贝壳也是',
            'ohno界面实在太诡异了，如果让我形容的话就是XFCE4',
            '那一天，深受原生安卓审美浸淫的我问了一下gemini',
            'flutter架构的app方便改成md3设计么',
            '它说很简单',
            '于是我就一步一步走到了现在',
            '一开始我给它取的名字叫The Beike MD3',
            '因为就是大贝壳的功能，只改变了外观',
            '直到以后我有了自己的鬼点子',
            '桌面小组件，无课教室等等等等',
            '再叫这个名字不太好了吧，所以就改名叫Beike NEXT',
            '以此体现自己的创新',
            '再后来功能越加越多越加越多',
            '贝壳里面孕育的是珍珠',
            '所以就另起炉灶改名叫了Pearl',
            '当年折磨珍珠蚌的那颗沙子',
            '叫做强迫症',
            '我一直在追求一个能覆盖校园生活常用功能的app',
            '现在回过头来看',
            '所有的努力都值得。',
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Copyright © 2026 Lymeeee · GPLv3',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // app_glyph.png 是从启动图标抠出的透明底点阵主体，跟随主题色
            // （深色模式下才不会糊在卡片上）
            Image.asset(
              'assets/icons/app_glyph.png',
              width: 64,
              height: 64,
              color: theme.colorScheme.primary,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _appName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '一款非官方的北科大校园助手',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildTextCard(
    BuildContext context,
    String title,
    List<String> paragraphs,
  ) {
    final theme = Theme.of(context);

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < paragraphs.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Text(
                paragraphs[i],
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '开源许可',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '本项目开源协议为 GPLv3，欢迎自由使用与修改！',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                Haptics.light();
                showLicensePage(
                  context: context,
                  applicationName: _appName,
                  applicationVersion: MetaInfo.instance.appVersion,
                  applicationIcon: Image.asset(
                    'assets/icons/app_glyph.png',
                    width: 40,
                    height: 40,
                    color: theme.colorScheme.primary,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                );
              },
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('查看第三方开源许可'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    Haptics.light();
    var launched = false;
    try {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
  }
}
