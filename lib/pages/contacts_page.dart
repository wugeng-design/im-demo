import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/im_provider.dart';
import '../sdk/services/impl/ejabberd_api_client.dart';
import '../widgets/im_avatar.dart';
import 'chat_detail_page.dart';

/// 好友列表页面
class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  List<RosterItem> _friends = [];
  Map<String, UserPresence> _presenceMap = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(imConnectionServiceProvider);
      final roster = await service.getRoster();
      final friends = roster.where((r) => r.isFriend).toList();

      setState(() {
        _friends = friends;
        _isLoading = false;
      });

      // 异步加载在线状态
      if (friends.isNotEmpty) {
        _loadPresence(friends.map((f) => f.jid).toList());
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPresence(List<String> jids) async {
    try {
      final service = ref.read(imConnectionServiceProvider);
      final presences = await service.getUsersPresence(jids);
      if (mounted) {
        setState(() {
          _presenceMap = {for (var p in presences) p.jid: p};
        });
      }
    } catch (e) {
      // 静默失败，在线状态不是必须的
      print('[Contacts] 加载在线状态失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: '搜索用户',
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddFriendDialog,
            tooltip: '添加好友',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('加载失败', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadFriends,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '暂无好友',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showSearchDialog,
              icon: const Icon(Icons.search),
              label: const Text('搜索添加'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.builder(
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final name = friend.nick ?? friend.jid.split('@').first;
          final presence = _presenceMap[friend.jid];

          return ListTile(
            leading: Stack(
              children: [
                ImAvatar(
                  userId: friend.jid,
                  name: name,
                  size: 44,
                ),
                // 在线状态指示器
                if (presence != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: presence.online ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(name),
            subtitle: Text(
              presence?.statusText ?? friend.jid,
              style: TextStyle(
                fontSize: 12,
                color: presence?.online == true ? Colors.green : Colors.grey[500],
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              onSelected: (value) {
                if (value == 'chat') {
                  _startChat(friend);
                } else if (value == 'delete') {
                  _confirmDeleteFriend(friend);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'chat',
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 20),
                      SizedBox(width: 12),
                      Text('发消息'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('删除好友', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _startChat(friend),
          );
        },
      ),
    );
  }

  void _startChat(RosterItem friend) {
    final name = friend.nick ?? friend.jid.split('@').first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          conversationId: friend.jid,
          conversationName: name,
          isGroup: false,
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _UserSearchSheet(
        onUserSelected: (user) {
          Navigator.pop(context);
          _showAddConfirmDialog(user);
        },
      ),
    );
  }

  void _showAddConfirmDialog(SearchUserResult user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加好友'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImAvatar(
              userId: user.jid,
              name: user.displayName,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(
              user.displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              user.jid,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final service = ref.read(imConnectionServiceProvider);
                await service.addFriend(user.jid, user.displayName);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('好友添加成功')),
                  );
                  _loadFriends();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('添加失败: $e')),
                  );
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog() {
    final jidController = TextEditingController();
    final nickController = TextEditingController();

    // 获取当前用户的域名，用于自动补全
    final service = ref.read(imConnectionServiceProvider);
    final currentJid = service.currentJid;
    final domain = currentJid?.split('@').last ?? 'localhost';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加好友'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: jidController,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '请输入用户名',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nickController,
              decoration: const InputDecoration(
                labelText: '备注名 (可选)',
                prefixIcon: Icon(Icons.edit),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              var input = jidController.text.trim();
              if (input.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入用户名')),
                );
                return;
              }

              // 如果没有 @，自动补全域名
              final jid = input.contains('@') ? input : '$input@$domain';
              final username = jid.split('@').first;

              Navigator.pop(context);

              try {
                final nick = nickController.text.trim().isEmpty
                    ? username
                    : nickController.text.trim();
                await service.addFriend(jid, nick);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('好友添加成功')),
                  );
                  _loadFriends();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('添加失败: $e')),
                  );
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFriend(RosterItem friend) {
    final name = friend.nick ?? friend.jid.split('@').first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定要删除好友「$name」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final service = ref.read(imConnectionServiceProvider);
                await service.removeFriend(friend.jid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除好友')),
                  );
                  _loadFriends();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 用户搜索面板
class _UserSearchSheet extends ConsumerStatefulWidget {
  final Function(SearchUserResult) onUserSelected;

  const _UserSearchSheet({required this.onUserSelected});

  @override
  ConsumerState<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends ConsumerState<_UserSearchSheet> {
  final _searchController = TextEditingController();
  List<SearchUserResult> _results = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final service = ref.read(imConnectionServiceProvider);
      final results = await service.searchUsers(keyword);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
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
              '搜索用户',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '输入用户名或昵称',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _search,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('搜索失败', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? '输入关键词搜索' : '未找到用户',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        return ListTile(
          leading: ImAvatar(
            userId: user.jid,
            name: user.displayName,
            avatarUrl: user.avatar,
            size: 44,
          ),
          title: Text(user.displayName),
          subtitle: Text(
            user.jid,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          trailing: TextButton(
            onPressed: () => widget.onUserSelected(user),
            child: const Text('添加'),
          ),
        );
      },
    );
  }
}
