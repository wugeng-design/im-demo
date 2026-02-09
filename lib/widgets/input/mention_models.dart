/// @提及相关数据模型
library;

/// 可提及的成员
class MentionableMember {
  const MentionableMember({
    required this.userBareJid,
    required this.nickname,
    this.avatarUrl,
  });

  /// 用户 bareJid（不含 resource 部分）
  /// 例如: `user@server.com`
  final String userBareJid;

  /// 昵称 (显示名 + 插入到消息中)
  final String nickname;

  /// 头像 URL
  final String? avatarUrl;
}

/// @提及检测结果
///
/// 表示当前输入框中 @提及的状态
class MentionDetectionResult {
  const MentionDetectionResult({
    required this.isActive,
    required this.query,
    required this.startIndex,
  });

  /// 是否正在输入 @提及
  final bool isActive;

  /// @ 后面的查询文本
  final String query;

  /// @ 符号的位置索引
  final int startIndex;

  /// 空结果 (没有检测到 @)
  static const empty = MentionDetectionResult(
    isActive: false,
    query: '',
    startIndex: -1,
  );
}
