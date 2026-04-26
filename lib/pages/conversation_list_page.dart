import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/im_provider.dart';
import '../sdk/models/conversation.dart';
import '../sdk/services/im_connection_service.dart' show ImConnectionState, ConnectionStateEvent;
import '../theme/im_design_tokens.dart';
import '../widgets/group_avatar.dart';
import '../widgets/im_avatar.dart';
import 'chat_detail_page.dart';
import 'create_group_page.dart';
import 'login_page.dart';
import 'message_search_page.dart';

/// 会话列表页面 - IM 主页
class ConversationListPage extends ConsumerWidget {
  const ConversationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider);
    final conversations = ref.watch(conversationsProvider);
    final connectionState = ref.watch(imConnectionStateProvider);
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        backgroundColor: colors.surface,
        elevation: 0.5,
        actions: [
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MessageSearchPage(),
                ),
              );
            },
          ),
          // 创建群聊按钮 - 使用自定义深色弹出菜单
          Builder(
            builder: (buttonContext) => IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '添加',
              onPressed: () => _showAddMenuPopup(buttonContext, context, ref),
            ),
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
          color: _getStateColor(event.state).withValues(alpha: 0.1),
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
      error: (_, _) => const SizedBox.shrink(),
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
    // 直接显示会话列表，即使未连接到服务器
    final conversations = ref.watch(conversationsProvider);
    return _buildConversationList(context, ref, conversations);
  }

  void _showNewChatDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final contacts = ref.read(contactsProvider).valueOrNull ?? [];

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
              leading: Icon(
                conversation.isMuted ? Icons.notifications : Icons.notifications_off,
              ),
              title: Text(conversation.isMuted ? '取消免打扰' : '消息免打扰'),
              onTap: () {
                ref
                    .read(conversationsProvider.notifier)
                    .toggleMute(conversation.id);
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

  /// 显示添加菜单弹窗
  void _showAddMenuPopup(BuildContext buttonContext, BuildContext context, WidgetRef ref) {
    // 获取按钮位置
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero);
    final buttonSize = button.size;

    // 计算菜单位置（右对齐，在按钮下方）
    const popupWidth = 140.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final rightPadding = screenWidth - buttonPosition.dx - buttonSize.width;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: '关闭菜单',
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Stack(
          children: [
            // 点击外部关闭
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            // 菜单
            Positioned(
              top: buttonPosition.dy + buttonSize.height + 4,
              right: rightPadding + 8,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  alignment: Alignment.topRight,
                  child: _AddMenuPopup(
                    width: popupWidth,
                    onChatTap: () {
                      Navigator.of(dialogContext).pop();
                      _showNewChatDialog(context, ref);
                    },
                    onGroupTap: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateGroupPage(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
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

  Widget? _buildSubtitle() {
    // 优先显示草稿
    if (conversation.hasDraft) {
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: '[草稿] ',
              style: TextStyle(color: Colors.red[400], fontSize: 13),
            ),
            TextSpan(
              text: conversation.draft,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }
    // 显示最后一条消息
    if (conversation.lastMessage != null) {
      return Text(
        conversation.lastMessage!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      );
    }
    return null;
  }

  /// 构建头像
  Widget _buildAvatar() {
    // 群聊：使用九宫格群头像
    if (conversation.isGroup) {
      // 有成员数据时显示九宫格
      if (conversation.members != null && conversation.members!.isNotEmpty) {
        return GroupAvatar(
          members: conversation.members!
              .map((m) => GroupMemberAvatar(
                    memberId: m.id,
                    avatarUrl: m.avatarUrl,
                    name: m.name,
                  ))
              .toList(),
          size: 48,
        );
      }
      // 无成员数据时显示默认群图标
      return GroupAvatar(
        members: const [],
        size: 48,
      );
    }

    // 单聊：使用 ImAvatar
    return ImAvatar(
      userId: conversation.id,
      name: conversation.name,
      avatarUrl: conversation.avatar,
      size: 48,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      tileColor: conversation.isPinned ? Colors.grey[100] : null,
      leading: _buildAvatar(),
      title: Text(
        conversation.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: _buildSubtitle(),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (conversation.lastMessageTime != null)
                Text(
                  _formatTime(conversation.lastMessageTime!),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              if (conversation.isMuted) ...[
                const SizedBox(width: 4),
                Icon(Icons.notifications_off, size: 14, color: Colors.grey[400]),
              ],
            ],
          ),
          if (conversation.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                // 免打扰时使用灰色角标
                color: conversation.isMuted ? Colors.grey : Colors.red,
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

/// 添加菜单弹窗
class _AddMenuPopup extends StatelessWidget {
  final double width;
  final VoidCallback onChatTap;
  final VoidCallback onGroupTap;

  const _AddMenuPopup({
    required this.width,
    required this.onChatTap,
    required this.onGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    const menuColor = Color(0xFF2C2C2C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 小三角箭头
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: CustomPaint(
            size: const Size(12, 6),
            painter: _TrianglePainter(color: menuColor),
          ),
        ),
        // 菜单主体
        Container(
          width: width,
          decoration: BoxDecoration(
            color: menuColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddMenuItem(
                icon: Icons.chat_bubble_outline,
                label: '发起聊天',
                onTap: onChatTap,
              ),
              Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withValues(alpha: 0.1),
              ),
              _AddMenuItem(
                icon: Icons.group_add_outlined,
                label: '创建群聊',
                onTap: onGroupTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 菜单项
class _AddMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 三角形绘制器
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
