import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/im_provider.dart';
import 'login_page.dart';

/// 个人中心页面
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(imConnectionServiceProvider);
    final currentJid = service.currentJid;
    final username = currentJid?.split('@').first ?? '未登录';
    final domain = currentJid?.split('@').last ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // 用户信息头部
          SliverToBoxAdapter(
            child: _UserHeader(
              username: username,
              jid: currentJid ?? '',
              domain: domain,
            ),
          ),

          // 设置项
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 账号安全
                  _SettingsSection(
                    title: '账号安全',
                    items: [
                      _SettingItem(
                        icon: Icons.lock_outline,
                        title: '修改密码',
                        onTap: () => _showComingSoon(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 通用设置
                  _SettingsSection(
                    title: '通用设置',
                    items: [
                      _SettingItem(
                        icon: Icons.notifications_outlined,
                        title: '消息通知',
                        onTap: () => _showComingSoon(context),
                      ),
                      _SettingItem(
                        icon: Icons.language,
                        title: '语言设置',
                        subtitle: '简体中文',
                        onTap: () => _showLanguageDialog(context),
                      ),
                      _SettingItem(
                        icon: Icons.cleaning_services_outlined,
                        title: '清除缓存',
                        subtitle: '0 MB',
                        onTap: () => _showClearCacheDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 其他
                  _SettingsSection(
                    title: '其他',
                    items: [
                      _SettingItem(
                        icon: Icons.help_outline,
                        title: '帮助与反馈',
                        onTap: () => _showComingSoon(context),
                      ),
                      _SettingItem(
                        icon: Icons.info_outline,
                        title: '关于',
                        onTap: () => _showAboutDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 退出登录按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _logout(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('退出登录'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 版本信息
                  Center(
                    child: Text(
                      'IM SDK Demo v1.0.0',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('功能开发中')),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('语言设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('简体中文'),
              trailing: const Icon(Icons.check, color: Colors.blue),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('English'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('语言切换功能开发中')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存数据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chat_bubble, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('IM SDK Demo'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: 1.0.0'),
            SizedBox(height: 8),
            Text('基于 XMPP 协议的即时通讯 SDK 演示应用'),
            SizedBox(height: 16),
            Text(
              '功能特性:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('• 单聊和群聊'),
            Text('• 实时消息收发'),
            Text('• 消息通知'),
            Text('• 会话管理'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final service = ref.read(imConnectionServiceProvider);
      await service.disconnect();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }
}

/// 用户信息头部
class _UserHeader extends StatelessWidget {
  final String username;
  final String jid;
  final String domain;

  const _UserHeader({
    required this.username,
    required this.jid,
    required this.domain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Row(
        children: [
          // 头像
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  jid.isNotEmpty ? jid : '点击登录',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // 箭头
          const Icon(
            Icons.chevron_right,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }
}

/// 设置分组
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingItem> items;

  const _SettingsSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _SettingItemTile(item: item),
                  if (index < items.length - 1)
                    Divider(
                      height: 1,
                      indent: 52,
                      color: Colors.grey[200],
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// 设置项数据
class _SettingItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _SettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.onTap,
  });
}

/// 设置项 UI
class _SettingItemTile extends StatelessWidget {
  final _SettingItem item;

  const _SettingItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 22,
              color: item.iconColor ?? Colors.grey[700],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (item.subtitle != null)
              Text(
                item.subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
