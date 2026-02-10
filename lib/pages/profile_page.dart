import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/im_provider.dart';
import '../widgets/im_avatar.dart';
import 'im_debug_page.dart';
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
                      _SettingItem(
                        icon: Icons.bug_report,
                        title: 'Debug 工具',
                        iconColor: Colors.purple,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ImDebugPage()),
                        ),
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
                      '畅聊天下 v1.0.0',
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
            const Text('畅聊天下'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: 1.0.0'),
            SizedBox(height: 8),
            Text('畅聊天下 - 互联互动'),
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
class _UserHeader extends ConsumerWidget {
  final String username;
  final String jid;
  final String domain;

  const _UserHeader({
    required this.username,
    required this.jid,
    required this.domain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarAsync = ref.watch(userAvatarProvider);
    final avatarUrl = avatarAsync.valueOrNull;

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
          // 头像 - 可点击编辑
          GestureDetector(
            onTap: () => _showAvatarOptions(context, ref),
            child: Stack(
              children: [
                // 头像
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ImAvatar.large(
                      userId: jid,
                      name: username,
                      avatarUrl: avatarUrl,
                    ),
                  ),
                ),
                // 编辑图标
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
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

  void _showAvatarOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '修改头像',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library, color: Colors.blue[700]),
              ),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar(context, ref, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, color: Colors.green[700]),
              ),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar(context, ref, ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey[200]),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.grey[600]),
              ),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );

    if (pickedFile == null) return;

    if (!context.mounted) return;

    // 显示上传对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AvatarUploadDialog(
        imageFile: File(pickedFile.path),
      ),
    );
  }
}

/// 头像上传对话框
class _AvatarUploadDialog extends ConsumerStatefulWidget {
  final File imageFile;

  const _AvatarUploadDialog({required this.imageFile});

  @override
  ConsumerState<_AvatarUploadDialog> createState() =>
      _AvatarUploadDialogState();
}

class _AvatarUploadDialogState extends ConsumerState<_AvatarUploadDialog> {
  double _progress = 0;
  String? _error;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _uploadAvatar();
  }

  Future<void> _uploadAvatar() async {
    final service = ref.read(avatarUploadServiceProvider);

    if (service == null) {
      if (mounted) {
        setState(() => _error = '上传服务未就绪');
      }
      return;
    }

    final result = await service.uploadUserAvatar(
      imageFile: widget.imageFile,
      onProgress: (p) {
        if (mounted) {
          setState(() => _progress = p);
        }
      },
    );

    if (!mounted) return;

    if (result.success) {
      setState(() => _isCompleted = true);
      // 刷新头像缓存
      ref.invalidate(userAvatarProvider);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _error = result.error ?? '上传失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (_error != null) ...[
              Icon(Icons.error_outline, color: Colors.red[400], size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ] else if (_isCompleted) ...[
              Icon(Icons.check_circle, color: Colors.green[400], size: 48),
              const SizedBox(height: 16),
              const Text(
                '头像更新成功',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ] else ...[
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      strokeWidth: 3,
                    ),
                    if (_progress > 0)
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('正在上传头像...'),
            ],
            const SizedBox(height: 8),
          ],
        ),
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
