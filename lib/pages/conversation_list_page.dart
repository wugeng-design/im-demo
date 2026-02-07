import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/im_provider.dart';
import '../sdk/models/conversation.dart';
import '../sdk/services/im_connection_service.dart' show ImConnectionState, ConnectionStateEvent;
import 'chat_detail_page.dart';
import 'create_group_page.dart';
import 'login_page.dart';

/// 会话列表页面 - IM 主页
class ConversationListPage extends ConsumerWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider);
    final conversations = ref.watch(conversationsProvider);
    final connectionState = ref.watch(imConnectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 创建群聊按钮
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (value) {
              if (value == 'group') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateGroupPage(),
                  ),
                );
              } else if (value == 'chat') {
                _showNewChatDialog(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'chat',
                child: Row(
                  children: [
                    Icon(Icons.chat, size: 20),
                    SizedBox(width: 12),
                    Text('发起聊天'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'group',
                child: Row(
                  children: [
                    Icon(Icons.group_add, size: 20),
                    SizedBox(width: 12),
                    Text('创建群聊'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 连接状态栏
          _buildConnectionBanner(context, ref, connectionState, isConnected),
          // 会话列表
          Expanded(
            child: isConnected
                ? _buildConversationList(context, ref, conversations)
                : _buildNotConnectedView(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ConnectionStateEvent> connectionState,
    bool isConnected,
  ) {
    return connectionState.when(
      data: (event) {
        if (event.state == ImConnectionState.authenticated) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _getStateColor(event.state).withOpacity(0.1),
          child: Row(
            children: [
              if (event.state == ImConnectionState.connecting ||
                  event.state == ImConnectionState.authenticating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (event.state == ImConnectionState.connecting ||
                  event.state == ImConnectionState.authenticating)
                const SizedBox(width: 8),
              Text(
                _getStateText(event.state),
                style: TextStyle(color: _getStateColor(event.state)),
              ),
              if (event.error != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.error!,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    WidgetRef ref,
    List<Conversation> conversations,
  ) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无会话',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角 + 开始聊天',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _ConversationTile(
          conversation: conversation,
          onTap: () {
            ref
                .read(conversationsProvider.notifier)
                .clearUnread(conversation.id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailPage(
                  conversationId: conversation.id,
                  conversationName: conversation.name,
                  isGroup: conversation.isGroup,
                ),
              ),
            );
          },
          onLongPress: () => _showConversationActions(context, ref, conversation),
        );
      },
    );
  }

  Widget _buildNotConnectedView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '未连接到服务器',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final contacts = ref.read(contactsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '输入 JID (如 user1@localhost)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    Navigator.pop(context);
                    _startChat(context, ref, value);
                  }
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '联系人',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        contact.name[0].toUpperCase(),
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                    title: Text(contact.name),
                    subtitle: Text(contact.jid, style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      _startChat(context, ref, contact.jid);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startChat(BuildContext context, WidgetRef ref, String jid) {
    final name = jid.split('@').first;
    ref.read(conversationsProvider.notifier).upsertConversation(
          Conversation(id: jid, name: name),
        );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          conversationId: jid,
          conversationName: name,
        ),
      ),
    );
  }

  void _showConversationActions(
    BuildContext context,
    WidgetRef ref,
    Conversation conversation,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(conversation.isPinned ? '取消置顶' : '置顶'),
              onTap: () {
                ref
                    .read(conversationsProvider.notifier)
                    .togglePin(conversation.id);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除会话', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref
                    .read(conversationsProvider.notifier)
                    .removeConversation(conversation.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStateColor(ImConnectionState state) {
    switch (state) {
      case ImConnectionState.disconnected:
        return Colors.grey;
      case ImConnectionState.connecting:
      case ImConnectionState.authenticating:
        return Colors.orange;
      case ImConnectionState.connected:
        return Colors.blue;
      case ImConnectionState.authenticated:
        return Colors.green;
      case ImConnectionState.reconnecting:
        return Colors.amber;
      case ImConnectionState.failed:
        return Colors.red;
    }
  }

  String _getStateText(ImConnectionState state) {
    switch (state) {
      case ImConnectionState.disconnected:
        return '已断开';
      case ImConnectionState.connecting:
        return '连接中...';
      case ImConnectionState.authenticating:
        return '认证中...';
      case ImConnectionState.connected:
        return '已连接';
      case ImConnectionState.authenticated:
        return '已登录';
      case ImConnectionState.reconnecting:
        return '重连中...';
      case ImConnectionState.failed:
        return '连接失败';
    }
  }
}

/// 会话列表项
class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      tileColor: conversation.isPinned ? Colors.grey[100] : null,
      leading: CircleAvatar(
        backgroundColor:
            conversation.isGroup ? Colors.green[100] : Colors.blue[100],
        child: Icon(
          conversation.isGroup ? Icons.group : Icons.person,
          color: conversation.isGroup ? Colors.green[700] : Colors.blue[700],
        ),
      ),
      title: Text(
        conversation.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: conversation.lastMessage != null
          ? Text(
              conversation.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (conversation.lastMessageTime != null)
            Text(
              _formatTime(conversation.lastMessageTime!),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          if (conversation.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : '${conversation.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
