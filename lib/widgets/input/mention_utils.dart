/// @提及检测和替换工具函数
library;

import 'mention_models.dart';

/// @提及格式正则表达式
///
/// 匹配格式: @[nickname](userId)
/// - Group 1: nickname (显示名)
/// - Group 2: userId (JID)
final RegExp _mentionPattern = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');

/// 提取消息中所有 @提及的 userId 列表
List<String> extractMentionUserIds(String text) {
  final matches = _mentionPattern.allMatches(text);
  return matches.map((m) => m.group(2)!).toList();
}

/// 格式化消息中的 @提及为显示格式
///
/// [text] 原始消息文本，包含 @[nickname](userId) 格式
/// [nicknameResolver] 根据 userId 查找昵称的函数，返回 null 则使用消息中的 nickname
///
/// 返回格式化后的文本，@[张三](123@server) → @张三
String formatMentionsForDisplay(
  String text,
  String? Function(String userId) nicknameResolver,
) {
  return text.replaceAllMapped(_mentionPattern, (match) {
    final fallbackNickname = match.group(1)!;
    final userId = match.group(2)!;

    // 优先使用 resolver 查到的昵称，查不到用消息里的
    final displayName = nicknameResolver(userId) ?? fallbackNickname;
    return '@$displayName';
  });
}

/// 简单格式化：直接使用消息中的 nickname
///
/// 不查询联系人表，用于不需要实时昵称的场景
String formatMentionsSimple(String text) {
  return text.replaceAllMapped(_mentionPattern, (match) {
    final nickname = match.group(1)!;
    return '@$nickname';
  });
}

/// 检测文本中的 @提及
///
/// 返回当前光标位置的 @提及状态
///
/// 规则:
/// - 检测光标前最近的 @ 符号
/// - @ 后面的字符作为查询 (直到空格或光标)
/// - 支持中文、英文、数字
MentionDetectionResult detectMention(String text, int cursorPosition) {
  if (text.isEmpty || cursorPosition <= 0) {
    return MentionDetectionResult.empty;
  }

  // 从光标位置向前查找 @
  final textBeforeCursor = text.substring(0, cursorPosition);
  final lastAtIndex = textBeforeCursor.lastIndexOf('@');

  if (lastAtIndex == -1) {
    return MentionDetectionResult.empty;
  }

  // 检查 @ 前面是否是空格或文本开头 (确保是独立的 @)
  if (lastAtIndex > 0) {
    final charBefore = textBeforeCursor[lastAtIndex - 1];
    // @ 前面必须是空格或换行
    if (charBefore != ' ' && charBefore != '\n') {
      return MentionDetectionResult.empty;
    }
  }

  // 提取 @ 后面的查询文本 (直到光标位置)
  final queryText = textBeforeCursor.substring(lastAtIndex + 1);

  // 如果查询中包含空格，说明已经输入完成，不显示选择器
  if (queryText.contains(' ')) {
    return MentionDetectionResult.empty;
  }

  return MentionDetectionResult(
    isActive: true,
    query: queryText,
    startIndex: lastAtIndex,
  );
}

/// 替换 @提及文本
///
/// 将 `@query` 替换为 `@[nickname](userBareJid) `
/// 存储格式支持解析和点击跳转
String replaceMention(
  String text,
  int startIndex,
  int cursorPosition,
  MentionableMember member,
) {
  final before = text.substring(0, startIndex);
  final after = text.substring(cursorPosition);
  // 使用格式：@[显示名](userBareJid) - 便于解析和跳转
  return '$before@[${member.nickname}](${member.userBareJid}) $after';
}
