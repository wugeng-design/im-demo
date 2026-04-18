import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/im_provider.dart';
import '../theme/im_design_tokens.dart';

/// 群公告页面
class GroupAnnouncementPage extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final bool isAdmin;

  const GroupAnnouncementPage({
    super.key,
    required this.groupId,
    required this.groupName,
    this.isAdmin = false,
  });

  @override
  ConsumerState<GroupAnnouncementPage> createState() =>
      _GroupAnnouncementPageState();
}

class _GroupAnnouncementPageState extends ConsumerState<GroupAnnouncementPage> {
  String? _announcement;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(imConnectionServiceProvider);
      final announcement = await service.getRoomAnnouncement(widget.groupId);
      if (mounted) {
        setState(() {
          _announcement = announcement;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editAnnouncement() async {
    final controller = TextEditingController(text: _announcement ?? '');

    final newAnnouncement = await showDialog<String>(
      context: context,
      builder: (context) => _EditAnnouncementDialog(
        controller: controller,
        currentAnnouncement: _announcement,
      ),
    );

    if (newAnnouncement == null) return;
    if (!mounted) return;

    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在保存...'),
          ],
        ),
      ),
    );

    try {
      final service = ref.read(imConnectionServiceProvider);
      await service.setRoomAnnouncement(widget.groupId, newAnnouncement);
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        setState(() {
          _announcement = newAnnouncement.isEmpty ? null : newAnnouncement;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('群公告已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('群公告'),
        backgroundColor: colors.surface,
        elevation: 0.5,
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editAnnouncement,
              tooltip: '编辑公告',
            ),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(ImColorScheme colors) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 16),
            Text('加载失败', style: TextStyle(color: colors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadAnnouncement,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_announcement == null || _announcement!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 64,
              color: colors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无群公告',
              style: TextStyle(
                fontSize: 16,
                color: colors.textSecondary,
              ),
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _editAnnouncement,
                icon: const Icon(Icons.add),
                label: const Text('发布公告'),
              ),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.campaign,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '群公告',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: colors.divider, height: 1),
            const SizedBox(height: 12),
            SelectableText(
              _announcement!,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 编辑公告对话框
class _EditAnnouncementDialog extends StatelessWidget {
  final TextEditingController controller;
  final String? currentAnnouncement;

  const _EditAnnouncementDialog({
    required this.controller,
    this.currentAnnouncement,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(currentAnnouncement == null ? '发布公告' : '编辑公告'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: controller,
          maxLines: 8,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: '请输入群公告内容...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        if (currentAnnouncement != null && currentAnnouncement!.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('清空公告', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
