import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/im_provider.dart';
import '../sdk/models/contact.dart';
import '../sdk/models/conversation.dart';
import 'chat_detail_page.dart';

/// 创建群聊页面
class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selectedJids = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 刷新联系人列表，确保获取最新的注册用户
    Future.microtask(() {
      ref.invalidate(contactsProvider);
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String jid) {
    setState(() {
      if (_selectedJids.contains(jid)) {
        _selectedJids.remove(jid);
      } else {
        _selectedJids.add(jid);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_selectedJids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择至少一个成员')),
      );
      return;
    }

    // 如果只选了一个人，直接创建单聊
    if (_selectedJids.length == 1) {
      final jid = _selectedJids.first;
      final name = jid.split('@').first;

      ref.read(conversationsProvider.notifier).upsertConversation(
            Conversation(id: jid, name: name),
          );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            conversationId: jid,
            conversationName: name,
          ),
        ),
      );
      return;
    }

    // 多人群聊需要群名
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入群名称')),
      );
      return;
    }

    // 显示创建中提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在创建群聊...')),
    );

    try {
      final service = ref.read(imConnectionServiceProvider);

      // 在 XMPP 服务器上创建 MUC 房间并邀请成员
      final groupJid = await service.createRoom(
        groupName,
        _selectedJids.toList(),
      );

      // 构建群成员列表（用于群头像显示）
      final contacts = ref.read(contactsProvider).valueOrNull ?? [];
      final currentJid = service.currentJid;
      final members = <ConversationMember>[];

      // 添加自己作为第一个成员
      if (currentJid != null) {
        members.add(ConversationMember(
          id: currentJid,
          name: currentJid.split('@').first,
        ));
      }

      // 添加选中的成员
      for (final jid in _selectedJids) {
        final contact = contacts.firstWhere(
          (c) => c.jid == jid,
          orElse: () => Contact(jid: jid, name: jid.split('@').first),
        );
        members.add(ConversationMember(
          id: jid,
          name: contact.name,
          avatarUrl: contact.avatar,
        ));
      }

      // 添加到本地会话列表（包含成员数据）
      ref.read(conversationsProvider.notifier).upsertConversation(
            Conversation(
              id: groupJid,
              name: groupName,
              isGroup: true,
              members: members.take(9).toList(),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('群聊「$groupName」创建成功，已邀请 ${_selectedJids.length} 人')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              conversationId: groupJid,
              conversationName: groupName,
              isGroup: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建群聊失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final contacts = contactsAsync.valueOrNull ?? [];
    final filteredContacts = _searchQuery.isEmpty
        ? contacts
        : contacts
            .where((c) =>
                c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.jid.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群聊'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _selectedJids.isNotEmpty ? _createGroup : null,
            child: Text(
              _selectedJids.length <= 1 ? '下一步' : '创建',
              style: TextStyle(
                color: _selectedJids.isNotEmpty
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 群名称输入（多选时显示）
          if (_selectedJids.length > 1)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  hintText: '输入群名称',
                  prefixIcon: const Icon(Icons.group),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),

          // 已选择的成员
          if (_selectedJids.isNotEmpty)
            Container(
              height: 88,
              color: Colors.grey[50],
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _selectedJids.length,
                itemBuilder: (context, index) {
                  final jid = _selectedJids.elementAt(index);
                  final contact = contacts.firstWhere(
                    (c) => c.jid == jid,
                    orElse: () => Contact(jid: jid, name: jid.split('@').first),
                  );
                  return _SelectedMemberChip(
                    contact: contact,
                    onRemove: () => _toggleSelection(jid),
                  );
                },
              ),
            ),

          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          '没有找到联系人',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final isSelected = _selectedJids.contains(contact.jid);
                      return _ContactTile(
                        contact: contact,
                        isSelected: isSelected,
                        onTap: () => _toggleSelection(contact.jid),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 已选成员标签
class _SelectedMemberChip extends StatelessWidget {
  final Contact contact;
  final VoidCallback onRemove;

  const _SelectedMemberChip({
    required this.contact,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue[100],
                child: Text(
                  contact.name[0].toUpperCase(),
                  style: TextStyle(color: Colors.blue[700], fontSize: 18),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              contact.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// 联系人列表项
class _ContactTile extends StatelessWidget {
  final Contact contact;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContactTile({
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Colors.blue[100],
        child: Text(
          contact.name[0].toUpperCase(),
          style: TextStyle(color: Colors.blue[700]),
        ),
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
          color: isSelected ? Colors.blue : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
