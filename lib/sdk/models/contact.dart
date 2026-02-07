/// 联系人模型
class Contact {
  final String jid;
  final String name;
  final String? avatar;
  final bool isOnline;
  final String? status;

  const Contact({
    required this.jid,
    required this.name,
    this.avatar,
    this.isOnline = false,
    this.status,
  });

  /// 从 JID 中提取用户名
  String get username => jid.split('@').first;

  /// 获取域名
  String get domain => jid.contains('@') ? jid.split('@').last : '';
}
