import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/im_sdk_config.dart';

/// XMPP 连接状态
enum ImConnectionState {
  /// 未连接
  disconnected,

  /// 连接中
  connecting,

  /// 已连接
  connected,

  /// 认证中
  authenticating,

  /// 已认证（可收发消息）
  authenticated,

  /// 重连中
  reconnecting,

  /// 连接失败
  failed,
}

/// 连接状态变化事件
class ConnectionStateEvent {
  final ImConnectionState state;
  final String? error;
  final DateTime timestamp;

  ConnectionStateEvent({
    required this.state,
    this.error,
  }) : timestamp = DateTime.now();

  bool get isConnected => state == ImConnectionState.authenticated;
  bool get isDisconnected => state == ImConnectionState.disconnected;
  bool get isFailed => state == ImConnectionState.failed;

  @override
  String toString() => 'ConnectionStateEvent($state${error != null ? ", error: $error" : ""})';
}

/// IM SDK 连接服务接口
///
/// 定义连接管理的核心接口，可以有不同实现：
/// - [ImConnectionServiceImpl]: 使用现有 EdX 基础设施
/// - 未来可添加独立实现
abstract class ImConnectionService {
  /// 当前连接状态
  ImConnectionState get currentState;

  /// 连接状态流
  Stream<ConnectionStateEvent> get connectionState;

  /// 当前用户 JID
  String? get currentJid;

  /// 是否已连接
  bool get isConnected;

  /// 连接到 XMPP 服务器
  Future<bool> connect(ImSdkConfig config, ImCredentials credentials);

  /// 断开连接
  Future<void> disconnect();

  /// 发送消息
  Future<void> sendMessage(String toJid, String body, {bool isGroupChat = false});

  /// 发送在线状态
  Future<void> sendPresence({String? show, String? status});

  /// 加入群聊（MUC）
  Future<void> joinRoom(String roomJid, String nickname);

  /// 离开群聊
  Future<void> leaveRoom(String roomJid, String nickname);

  /// 获取群公告
  Future<String?> getRoomAnnouncement(String roomJid);

  /// 设置群公告
  Future<void> setRoomAnnouncement(String roomJid, String announcement);

  /// 获取群成员列表
  Future<List<MucMember>> getRoomMembers(String roomJid);

  /// 标记消息已读
  ///
  /// 向对方发送已读回执，标记该会话的消息为已读
  Future<void> markAsRead(String peerJid);

  /// 释放资源
  void dispose();
}

/// MUC 群成员信息
class MucMember {
  /// 成员 JID（bare JID）
  final String jid;

  /// 群内昵称
  final String? nickname;

  /// 角色 (owner/admin/member/outcast/none)
  final String affiliation;

  /// 当前状态 (moderator/participant/visitor/none)
  final String role;

  MucMember({
    required this.jid,
    this.nickname,
    this.affiliation = 'member',
    this.role = 'participant',
  });

  bool get isOwner => affiliation == 'owner';
  bool get isAdmin => affiliation == 'admin' || affiliation == 'owner';
}

/// SDK 消息模型（简化版）
class SdkMessage {
  final String id;
  final String from;
  final String? to;
  final String? body;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic>? extra;

  SdkMessage({
    required this.id,
    required this.from,
    this.to,
    this.body,
    required this.type,
    required this.timestamp,
    this.extra,
  });

  bool get isGroupChat => type == 'groupchat';
  bool get isChat => type == 'chat';

  @override
  String toString() => 'SdkMessage(from: $from, body: ${body?.substring(0, (body?.length ?? 0).clamp(0, 20))}...)';
}

/// SDK 在线状态模型（简化版）
class SdkPresence {
  final String from;
  final String? type;
  final String? show;
  final String? status;

  SdkPresence({
    required this.from,
    this.type,
    this.show,
    this.status,
  });

  bool get isOnline => type == null || type == 'available';
  bool get isOffline => type == 'unavailable';
  bool get isAway => show == 'away';
  bool get isBusy => show == 'dnd';

  @override
  String toString() => 'SdkPresence(from: $from, ${isOnline ? "online" : "offline"})';
}

/// 占位实现 - 使用现有 EdX 基础设施时
///
/// 实际连接由 ImSession 管理，这里只是状态适配
class ImConnectionServicePlaceholder implements ImConnectionService {
  final _stateController = StreamController<ConnectionStateEvent>.broadcast();
  ImConnectionState _currentState = ImConnectionState.disconnected;
  String? _currentJid;

  @override
  ImConnectionState get currentState => _currentState;

  @override
  Stream<ConnectionStateEvent> get connectionState => _stateController.stream;

  @override
  String? get currentJid => _currentJid;

  @override
  bool get isConnected => _currentState == ImConnectionState.authenticated;

  @override
  Future<bool> connect(ImSdkConfig config, ImCredentials credentials) async {
    // 在 EdX 环境中，连接由 ImSession 管理
    // 这里只更新状态
    _currentJid = credentials.withDomain(config.domain).jid;
    _updateState(ImConnectionState.connecting);

    // 实际连接应通过 ImSession
    // 这里模拟成功
    await Future.delayed(const Duration(milliseconds: 100));
    _updateState(ImConnectionState.authenticated);
    return true;
  }

  @override
  Future<void> disconnect() async {
    _updateState(ImConnectionState.disconnected);
    _currentJid = null;
  }

  @override
  Future<void> sendMessage(String toJid, String body, {bool isGroupChat = false}) async {
    if (!isConnected) {
      throw StateError('Not connected. Use ImSession for actual message sending.');
    }
    // 实际发送应通过 SendCoordinator
    throw UnimplementedError('Use SendCoordinator for actual message sending');
  }

  @override
  Future<void> sendPresence({String? show, String? status}) async {
    if (!isConnected) {
      throw StateError('Not connected');
    }
    // 实际发送应通过 SendCoordinator
  }

  @override
  Future<void> joinRoom(String roomJid, String nickname) async {
    if (!isConnected) {
      throw StateError('Not connected');
    }
    // 实际操作应通过 GroupRepository
  }

  @override
  Future<void> leaveRoom(String roomJid, String nickname) async {
    // 实际操作应通过 GroupRepository
  }

  @override
  Future<String?> getRoomAnnouncement(String roomJid) async {
    // 实际操作应通过 GroupRepository
    return null;
  }

  @override
  Future<void> setRoomAnnouncement(String roomJid, String announcement) async {
    // 实际操作应通过 GroupRepository
  }

  @override
  Future<List<MucMember>> getRoomMembers(String roomJid) async {
    // 实际操作应通过 GroupRepository
    return [];
  }

  @override
  Future<void> markAsRead(String peerJid) async {
    // 实际操作应通过 IM Session
  }

  void _updateState(ImConnectionState state, {String? error}) {
    _currentState = state;
    _stateController.add(ConnectionStateEvent(state: state, error: error));
  }

  /// 外部更新连接状态（由 ImSession 调用）
  void updateFromImSession({
    required bool isConnected,
    String? jid,
    String? error,
  }) {
    _currentJid = jid;
    if (isConnected) {
      _updateState(ImConnectionState.authenticated);
    } else if (error != null) {
      _updateState(ImConnectionState.failed, error: error);
    } else {
      _updateState(ImConnectionState.disconnected);
    }
  }

  @override
  void dispose() {
    _stateController.close();
  }
}

/// IM 连接服务（可覆盖）
///
/// 默认使用 Placeholder 实现（EdX 模式）
/// 独立模式下可以通过 ProviderScope overrides 替换为 StandaloneConnectionService
final imConnectionServiceProvider = Provider<ImConnectionService>((ref) {
  final service = ImConnectionServicePlaceholder();
  ref.onDispose(() => service.dispose());
  return service;
});

/// 独立连接服务 Provider
///
/// 用于 Demo 页面和独立部署场景
/// 直接使用 whixp 连接 XMPP 服务器
final standaloneConnectionServiceProvider = Provider<ImConnectionService>((ref) {
  // 延迟导入，避免在 EdX 模式下引入不必要的依赖
  // ignore: depend_on_referenced_packages
  final service = _createStandaloneService();
  ref.onDispose(() => service.dispose());
  return service;
});

ImConnectionService _createStandaloneService() {
  // 动态创建 StandaloneConnectionService
  // 需要在使用时导入 impl/standalone_connection_service.dart
  return ImConnectionServicePlaceholder(); // 默认返回 placeholder，实际使用需 override
}

/// 连接状态 Provider
final imConnectionStateProvider = StreamProvider<ConnectionStateEvent>((ref) {
  final service = ref.watch(imConnectionServiceProvider);
  return service.connectionState;
});

/// 是否已连接 Provider
final isImConnectedProvider = Provider<bool>((ref) {
  final stateAsync = ref.watch(imConnectionStateProvider);
  return stateAsync.whenOrNull(data: (state) => state.isConnected) ?? false;
});
