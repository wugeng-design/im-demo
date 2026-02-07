import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/im_provider.dart';
import '../sdk/models/contact.dart';
import '../theme/im_design_tokens.dart';
import '../widgets/im_avatar.dart';

/// 群聊详情页面
class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  // TODO: 从服务器获取真实群成员列表
  // 目前使用模拟数据
  List<_GroupMember> _members = [];
  bool _isLoading = true;
  bool _isMuted = false;
  bool _isPinned = false;

  // 当前用户是否是群主/管理员
  bool get _isAdmin => true; // TODO: 根据实际权限判断

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    // TODO: 从 XMPP 服务器加载群信息
    // 模拟加载群成员
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _members = [
        _GroupMember(jid: 'owner@localhost', name: '群主', role: _MemberRole.owner),
        _GroupMember(jid: 'admin1@localhost', name: '管理员1', role: _MemberRole.admin),
        _GroupMember(jid: 'user1@localhost', name: '成员1', role: _MemberRole.member),
        _GroupMember(jid: 'user2@localhost', name: '成员2', role: _MemberRole.member),
        _GroupMember(jid: 'user3@localhost', name: '成员3', role: _MemberRole.member),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('群聊设置'),
        backgroundColor: colors.surface,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 群成员网格
                  _buildMemberSection(colors),
                  const SizedBox(height: 12),
                  // 群设置
                  _buildSettingsSection(colors),
                  const SizedBox(height: 12),
                  // 退出群聊按钮
                  _buildLeaveButton(colors),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  /// 构建成员区域
  Widget _buildMemberSection(ImColorScheme colors) {
    // 计算每行显示的成员数
    const itemsPerRow = 5;
    // 最多显示的成员数（不含添加/删除按钮）
    const maxDisplayMembers = 14;

    final displayMembers = _members.take(maxDisplayMembers).toList();
    final hasMoreMembers = _members.length > maxDisplayMembers;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '群成员 (${_members.length})',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                ),
              ),
              if (hasMoreMembers)
                GestureDetector(
                  onTap: _showAllMembers,
                  child: Row(
                    children: [
                      Text(
                        '查看全部',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 成员网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: itemsPerRow,
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: displayMembers.length + (_isAdmin ? 2 : 0), // +添加/删除按钮
            itemBuilder: (context, index) {
              // 添加成员按钮
              if (_isAdmin && index == displayMembers.length) {
                return _buildActionButton(
                  icon: Icons.add,
                  label: '添加',
                  onTap: _addMembers,
                  colors: colors,
                );
              }
              // 删除成员按钮
              if (_isAdmin && index == displayMembers.length + 1) {
                return _buildActionButton(
                  icon: Icons.remove,
                  label: '删除',
                  onTap: _removeMembers,
                  colors: colors,
                );
              }
              // 成员头像
              final member = displayMembers[index];
              return _buildMemberItem(member, colors);
            },
          ),
        ],
      ),
    );
  }

  /// 构建成员头像项
  Widget _buildMemberItem(_GroupMember member, ImColorScheme colors) {
    return GestureDetector(
      onTap: () => _showMemberProfile(member),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              ImAvatar(
                userId: member.jid,
                name: member.name,
                size: 48,
              ),
              // 群主/管理员标识
              if (member.role != _MemberRole.member)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: member.role == _MemberRole.owner
                          ? Colors.orange
                          : Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      member.role == _MemberRole.owner ? '群主' : '管理',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 56,
            child: Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮（添加/删除）
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ImColorScheme colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: colors.divider, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: colors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建设置区域
  Widget _buildSettingsSection(ImColorScheme colors) {
    return Container(
      color: colors.surface,
      child: Column(
        children: [
          // 群名称
          _buildSettingsTile(
            title: '群聊名称',
            trailing: Text(
              widget.groupName,
              style: TextStyle(color: colors.textSecondary),
            ),
            onTap: _isAdmin ? _editGroupName : null,
            colors: colors,
          ),
          _buildDivider(colors),
          // 群公告
          _buildSettingsTile(
            title: '群公告',
            trailing: Icon(
              Icons.chevron_right,
              color: colors.textTertiary,
            ),
            onTap: () => _showGroupAnnouncement(),
            colors: colors,
          ),
          _buildDivider(colors),
          // 消息免打扰
          _buildSettingsTile(
            title: '消息免打扰',
            trailing: Switch(
              value: _isMuted,
              onChanged: (value) {
                setState(() => _isMuted = value);
              },
            ),
            colors: colors,
          ),
          _buildDivider(colors),
          // 置顶聊天
          _buildSettingsTile(
            title: '置顶聊天',
            trailing: Switch(
              value: _isPinned,
              onChanged: (value) {
                setState(() => _isPinned = value);
                ref.read(conversationsProvider.notifier).togglePin(widget.groupId);
              },
            ),
            colors: colors,
          ),
          _buildDivider(colors),
          // 清空聊天记录
          _buildSettingsTile(
            title: '清空聊天记录',
            onTap: _clearChatHistory,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    required ImColorScheme colors,
  }) {
    return ListTile(
      title: Text(title),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildDivider(ImColorScheme colors) {
    return Divider(
      height: 1,
      indent: 16,
      color: colors.divider,
    );
  }

  /// 构建退出群聊按钮
  Widget _buildLeaveButton(ImColorScheme colors) {
    return Container(
      color: colors.surface,
      child: ListTile(
        title: Center(
          child: Text(
            _isAdmin ? '解散群聊' : '退出群聊',
            style: TextStyle(color: colors.error),
          ),
        ),
        onTap: _leaveGroup,
      ),
    );
  }

  // ========== 操作方法 ==========

  void _showAllMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GroupMemberListPage(
          groupId: widget.groupId,
          groupName: widget.groupName,
          members: _members,
          isAdmin: _isAdmin,
          onMemberRemoved: (jid) {
            setState(() {
              _members.removeWhere((m) => m.jid == jid);
            });
          },
        ),
      ),
    );
  }

  void _showMemberProfile(_GroupMember member) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ImAvatar(
              userId: member.jid,
              name: member.name,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(
              member.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              member.jid,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('发消息'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 导航到私聊页面
              },
            ),
            if (_isAdmin && member.role == _MemberRole.member)
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text('移出群聊', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeSingleMember(member);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _addMembers() {
    final contacts = ref.read(contactsProvider);
    final existingJids = _members.map((m) => m.jid).toSet();
    final availableContacts = contacts.where((c) => !existingJids.contains(c.jid)).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AddMemberPage(
          groupId: widget.groupId,
          availableContacts: availableContacts,
          onMembersAdded: (selectedJids) {
            // TODO: 调用 XMPP 邀请成员
            setState(() {
              for (final jid in selectedJids) {
                final contact = contacts.firstWhere((c) => c.jid == jid);
                _members.add(_GroupMember(
                  jid: jid,
                  name: contact.name,
                  role: _MemberRole.member,
                ));
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已邀请 ${selectedJids.length} 人加入群聊')),
            );
          },
        ),
      ),
    );
  }

  void _removeMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RemoveMemberPage(
          groupId: widget.groupId,
          members: _members.where((m) => m.role == _MemberRole.member).toList(),
          onMembersRemoved: (removedJids) {
            // TODO: 调用 XMPP 移除成员
            setState(() {
              _members.removeWhere((m) => removedJids.contains(m.jid));
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已移除 ${removedJids.length} 人')),
            );
          },
        ),
      ),
    );
  }

  void _removeSingleMember(_GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出群聊'),
        content: Text('确定要将「${member.name}」移出群聊吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: 调用 XMPP 移除成员
      setState(() {
        _members.removeWhere((m) => m.jid == member.jid);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将「${member.name}」移出群聊')),
        );
      }
    }
  }

  void _editGroupName() {
    final controller = TextEditingController(text: widget.groupName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改群名称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入群名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 调用 XMPP 修改群名称
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('群名称修改功能开发中')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showGroupAnnouncement() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('群公告功能开发中')),
    );
  }

  void _clearChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空所有聊天记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // TODO: 清空聊天记录
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('聊天记录已清空')),
      );
    }
  }

  void _leaveGroup() async {
    final isOwner = _members.any((m) => m.role == _MemberRole.owner);
    final title = isOwner ? '解散群聊' : '退出群聊';
    final content = isOwner ? '确定要解散这个群聊吗？所有成员将被移出，群聊将被删除。' : '确定要退出这个群聊吗？';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isOwner ? '解散' : '退出', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // TODO: 调用 XMPP 退出/解散群聊
      ref.read(conversationsProvider.notifier).removeConversation(widget.groupId);
      Navigator.of(context)..pop()..pop(); // 返回会话列表
    }
  }
}

// ========== 群成员模型 ==========

enum _MemberRole { owner, admin, member }

class _GroupMember {
  final String jid;
  final String name;
  final _MemberRole role;

  _GroupMember({
    required this.jid,
    required this.name,
    this.role = _MemberRole.member,
  });
}

// ========== 群成员列表页面 ==========

class _GroupMemberListPage extends StatelessWidget {
  final String groupId;
  final String groupName;
  final List<_GroupMember> members;
  final bool isAdmin;
  final void Function(String jid) onMemberRemoved;

  const _GroupMemberListPage({
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.isAdmin,
    required this.onMemberRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('群成员 (${members.length})'),
        backgroundColor: colors.surface,
        elevation: 0.5,
      ),
      body: ListView.builder(
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          return ListTile(
            leading: ImAvatar(
              userId: member.jid,
              name: member.name,
              size: 44,
            ),
            title: Row(
              children: [
                Text(member.name),
                if (member.role != _MemberRole.member) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: member.role == _MemberRole.owner
                          ? Colors.orange.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      member.role == _MemberRole.owner ? '群主' : '管理员',
                      style: TextStyle(
                        fontSize: 11,
                        color: member.role == _MemberRole.owner
                            ? Colors.orange
                            : Colors.blue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              member.jid,
              style: TextStyle(
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ========== 添加成员页面 ==========

class _AddMemberPage extends StatefulWidget {
  final String groupId;
  final List<Contact> availableContacts;
  final void Function(List<String> jids) onMembersAdded;

  const _AddMemberPage({
    required this.groupId,
    required this.availableContacts,
    required this.onMembersAdded,
  });

  @override
  State<_AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<_AddMemberPage> {
  final Set<String> _selectedJids = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final filteredContacts = _searchQuery.isEmpty
        ? widget.availableContacts
        : widget.availableContacts
            .where((c) =>
                c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.jid.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('添加成员'),
        backgroundColor: colors.surface,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _selectedJids.isNotEmpty
                ? () {
                    widget.onMembersAdded(_selectedJids.toList());
                    Navigator.pop(context);
                  }
                : null,
            child: Text(
              '添加 (${_selectedJids.length})',
              style: TextStyle(
                color: _selectedJids.isNotEmpty ? colors.primary : colors.textDisabled,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: '搜索联系人',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          // 联系人列表
          Expanded(
            child: filteredContacts.isEmpty
                ? Center(
                    child: Text(
                      '没有可添加的联系人',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final isSelected = _selectedJids.contains(contact.jid);
                      return ListTile(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedJids.remove(contact.jid);
                            } else {
                              _selectedJids.add(contact.jid);
                            }
                          });
                        },
                        leading: ImAvatar(
                          userId: contact.jid,
                          name: contact.name,
                          avatarUrl: contact.avatar,
                          size: 44,
                        ),
                        title: Text(contact.name),
                        subtitle: Text(
                          contact.jid,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? colors.primary : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? colors.primary : colors.textTertiary,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ========== 移除成员页面 ==========

class _RemoveMemberPage extends StatefulWidget {
  final String groupId;
  final List<_GroupMember> members;
  final void Function(List<String> jids) onMembersRemoved;

  const _RemoveMemberPage({
    required this.groupId,
    required this.members,
    required this.onMembersRemoved,
  });

  @override
  State<_RemoveMemberPage> createState() => _RemoveMemberPageState();
}

class _RemoveMemberPageState extends State<_RemoveMemberPage> {
  final Set<String> _selectedJids = {};

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('移除成员'),
        backgroundColor: colors.surface,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _selectedJids.isNotEmpty
                ? () {
                    widget.onMembersRemoved(_selectedJids.toList());
                    Navigator.pop(context);
                  }
                : null,
            child: Text(
              '移除 (${_selectedJids.length})',
              style: TextStyle(
                color: _selectedJids.isNotEmpty ? colors.error : colors.textDisabled,
              ),
            ),
          ),
        ],
      ),
      body: widget.members.isEmpty
          ? Center(
              child: Text(
                '没有可移除的成员',
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          : ListView.builder(
              itemCount: widget.members.length,
              itemBuilder: (context, index) {
                final member = widget.members[index];
                final isSelected = _selectedJids.contains(member.jid);
                return ListTile(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedJids.remove(member.jid);
                      } else {
                        _selectedJids.add(member.jid);
                      }
                    });
                  },
                  leading: ImAvatar(
                    userId: member.jid,
                    name: member.name,
                    size: 44,
                  ),
                  title: Text(member.name),
                  subtitle: Text(
                    member.jid,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? colors.error : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? colors.error : colors.textTertiary,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
