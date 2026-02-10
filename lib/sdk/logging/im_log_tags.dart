/// IM 模块日志 Tag 常量
///
/// 用于分类和过滤 IM 相关日志
///
/// 使用方式:
/// ```dart
/// imLog('连接成功', tag: ImLogTags.connection);
/// imLog('收到消息', tag: ImLogTags.message);
/// ```
library;

/// IM 日志 Tag 常量
abstract class ImLogTags {
  ImLogTags._();

  // ============================================
  // 连接层
  // ============================================

  /// XMPP 协议层
  static const String xmpp = 'XMPP';

  /// 连接管理
  static const String connection = 'Connection';

  /// 心跳检测
  static const String heartbeat = 'Heartbeat';

  /// 认证
  static const String auth = 'Auth';

  // ============================================
  // 消息层
  // ============================================

  /// 消息处理
  static const String message = 'Message';

  /// 消息解析
  static const String parser = 'Parser';

  /// MAM (消息归档管理)
  static const String mam = 'MAM';

  /// Carbons (消息复制)
  static const String carbons = 'Carbons';

  /// 消息状态 (已读/已送达)
  static const String messageStatus = 'MsgStatus';

  // ============================================
  // 会话层
  // ============================================

  /// 会话管理
  static const String conversation = 'Conv';

  /// 联系人/花名册
  static const String roster = 'Roster';

  /// 在线状态
  static const String presence = 'Presence';

  /// 订阅管理
  static const String subscription = 'Subscription';

  // ============================================
  // 群组层
  // ============================================

  /// MUC (多用户聊天/群组)
  static const String muc = 'MUC';

  /// 群组房间
  static const String room = 'Room';

  /// 群成员
  static const String member = 'Member';

  // ============================================
  // 基础设施
  // ============================================

  /// 数据库操作
  static const String db = 'DB';

  /// 生命周期
  static const String lifecycle = 'Lifecycle';

  /// 性能
  static const String perf = 'Perf';

  /// 数据流
  static const String stream = 'Stream';

  /// 媒体处理
  static const String media = 'Media';

  /// 通用 IM 标签
  static const String im = 'IM';

  // ============================================
  // 调试专用
  // ============================================

  /// 调试信息
  static const String debug = 'Debug';

  /// 追踪 (MessageJourney)
  static const String journey = 'Journey';

  /// 操作记录
  static const String action = 'Action';

  /// 所有 Tag 列表 (用于 UI 过滤)
  static const List<String> allTags = [
    xmpp,
    connection,
    heartbeat,
    auth,
    message,
    parser,
    mam,
    carbons,
    messageStatus,
    conversation,
    roster,
    presence,
    subscription,
    muc,
    room,
    member,
    db,
    lifecycle,
    perf,
    stream,
    media,
    im,
    debug,
    journey,
    action,
  ];

  /// 常用 Tag (用于 UI 快捷过滤)
  static const List<String> commonTags = [
    connection,
    message,
    mam,
    conversation,
    muc,
  ];
}
