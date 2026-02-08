import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/im_provider.dart';
import '../sdk/models/message.dart';
import '../theme/im_design_tokens.dart';
import 'chat_detail_page.dart';

/// 消息搜索页面
class MessageSearchPage extends ConsumerStatefulWidget {
  const MessageSearchPage({
    super.key,
    this.conversationId,
    this.conversationName,
  });

  /// 限定搜索的会话 ID（null 表示全局搜索）
  final String? conversationId;

  /// 会话名称（用于显示）
  final String? conversationName;

  @override
  ConsumerState<MessageSearchPage> createState() => _MessageSearchPageState();
}

class _MessageSearchPageState extends ConsumerState<MessageSearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<_SearchResult> _results = [];
  bool _isSearching = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _lastQuery = '';
      });
      return;
    }

    if (query == _lastQuery) return;

    setState(() {
      _isSearching = true;
      _lastQuery = query;
    });

    final repository = ref.read(repositoryProvider);
    final conversations = ref.read(conversationsProvider);

    try {
      final messages = await repository.searchMessages(
        query.trim(),
        conversationId: widget.conversationId,
        limit: 100,
      );

      // 将消息转换为搜索结果
      final results = messages.map((message) {
        // 找到消息所属的会话名称
        final conversation = conversations.firstWhere(
          (c) => c.id == message.conversationId,
          orElse: () => throw StateError('Conversation not found'),
        );

        return _SearchResult(
          message: message,
          conversationName: conversation.name,
          highlightRanges: _findHighlightRanges(message.body, query.trim()),
        );
      }).toList();

      if (mounted && query == _lastQuery) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
    }
  }

  List<_HighlightRange> _findHighlightRanges(String text, String keyword) {
    final ranges = <_HighlightRange>[];
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();

    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerKeyword, start);
      if (index == -1) break;
      ranges.add(_HighlightRange(index, index + keyword.length));
      start = index + 1;
    }

    return ranges;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0.5,
        titleSpacing: 0,
        title: _buildSearchField(colors),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: colors.primary),
            ),
          ),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildSearchField(ImColorScheme colors) {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.conversationId != null
              ? '在当前会话中搜索'
              : '搜索聊天记录',
          hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: colors.textSecondary, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: colors.textSecondary, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _search('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        style: TextStyle(color: colors.textPrimary, fontSize: 14),
        onChanged: _search,
      ),
    );
  }

  Widget _buildBody(ImColorScheme colors) {
    if (_searchController.text.isEmpty) {
      return _buildEmptyState(colors, '输入关键词搜索消息');
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return _buildEmptyState(colors, '没有找到相关消息');
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 72,
        color: colors.divider,
      ),
      itemBuilder: (context, index) {
        final result = _results[index];
        return _buildResultItem(colors, result);
      },
    );
  }

  Widget _buildEmptyState(ImColorScheme colors, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: colors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(ImColorScheme colors, _SearchResult result) {
    final message = result.message;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colors.primary.withValues(alpha: 0.1),
        child: Text(
          result.conversationName.isNotEmpty
              ? result.conversationName[0].toUpperCase()
              : '?',
          style: TextStyle(color: colors.primary),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              result.conversationName,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
      subtitle: _buildHighlightedText(
        message.body,
        result.highlightRanges,
        colors,
      ),
      onTap: () => _navigateToMessage(result),
    );
  }

  Widget _buildHighlightedText(
    String text,
    List<_HighlightRange> ranges,
    ImColorScheme colors,
  ) {
    if (ranges.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.textSecondary),
      );
    }

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final range in ranges) {
      // 添加高亮前的普通文本
      if (currentIndex < range.start) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, range.start),
          style: TextStyle(color: colors.textSecondary),
        ));
      }
      // 添加高亮文本
      spans.add(TextSpan(
        text: text.substring(range.start, range.end),
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w500,
        ),
      ));
      currentIndex = range.end;
    }

    // 添加最后的普通文本
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: TextStyle(color: colors.textSecondary),
      ));
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return '昨天';
    } else if (time.year == now.year) {
      return '${time.month}/${time.day}';
    } else {
      return '${time.year}/${time.month}/${time.day}';
    }
  }

  void _navigateToMessage(_SearchResult result) {
    final conversations = ref.read(conversationsProvider);
    final conversation = conversations.firstWhere(
      (c) => c.id == result.message.conversationId,
      orElse: () => throw StateError('Conversation not found'),
    );

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
  }
}

/// 搜索结果
class _SearchResult {
  final Message message;
  final String conversationName;
  final List<_HighlightRange> highlightRanges;

  _SearchResult({
    required this.message,
    required this.conversationName,
    required this.highlightRanges,
  });
}

/// 高亮范围
class _HighlightRange {
  final int start;
  final int end;

  _HighlightRange(this.start, this.end);
}
