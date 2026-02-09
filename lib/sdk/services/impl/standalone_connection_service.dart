import 'dart:async';
import 'dart:io';

import 'package:whixp/whixp.dart';

import '../../config/im_sdk_config.dart';
import '../im_connection_service.dart';
import '../reconnect_manager.dart';
import '../app_lifecycle_service.dart';
import 'ejabberd_api_client.dart';

/// 接收到的消息
class ReceivedMessage {
  final String from;
  final String? to;
  final String? body;
  final String type;
  final DateTime timestamp;

  ReceivedMessage({
    required this.from,
    this.to,
    this.body,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'ReceivedMessage(from: $from, body: $body)';
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

  @override
  String toString() => 'MucMember(jid: $jid, affiliation: $affiliation)';
}

/// 独立 XMPP 连接服务
///
/// 直接使用 whixp 连接 XMPP 服务器，不依赖 EdX 基础设施
///
/// 适用场景：
/// - 测试连接 ejabberd
/// - 独立部署 IM SDK
/// - Demo 演示
class StandaloneConnectionService implements ImConnectionService {
  Whixp? _whixp;
  final _stateController = StreamController<ConnectionStateEvent>.broadcast();
  final _messageController = StreamController<ReceivedMessage>.broadcast();
  ImConnectionState _currentState = ImConnectionState.disconnected;
  String? _currentJid;
  String? _dbPath;

  /// 保存的配置（用于重连）
  ImSdkConfig? _savedConfig;
  ImCredentials? _savedCredentials;

  /// ejabberd REST API 客户端
  EjabberdApiClient? _ejabberdApi;

  /// 重连管理器
  late final ReconnectManager _reconnectManager;

  /// 生命周期服务
  final AppLifecycleService _lifecycleService = AppLifecycleService();
  StreamSubscription<AppLifecycleEvent>? _lifecycleSubscription;

  /// 已加入的群聊房间（用于自动重新加入）
  final Set<String> _joinedRooms = {};

  /// App 后台时长阈值（超过此时长需要验证连接）
  static const Duration _backgroundThreshold = Duration(seconds: 30);

  StandaloneConnectionService() {
    _reconnectManager = ReconnectManager(
      onReconnect: _doReconnect,
      onStateChange: _onReconnectStateChange,
      onMaxAttemptsReached: _onMaxReconnectAttemptsReached,
    );
    _initLifecycleService();
  }

  void _initLifecycleService() {
    _lifecycleService.start();
    _lifecycleSubscription = _lifecycleService.events.listen(_onLifecycleEvent);
  }

  void _onLifecycleEvent(AppLifecycleEvent event) {
    if (event is AppResumedEvent) {
      _onAppResumed(event.backgroundDuration);
    } else if (event is NetworkRestoredEvent) {
      _onNetworkRestored();
    } else if (event is NetworkLostEvent) {
      _onNetworkLost();
    }
  }

  /// App 从后台恢复
  void _onAppResumed(Duration backgroundDuration) {
    print('[Connection] App 从后台恢复，后台时长: ${backgroundDuration.inSeconds}s');

    if (!isConnected && _savedConfig != null && _savedCredentials != null) {
      // 未连接状态，触发重连
      print('[Connection] 未连接，触发重连');
      _reconnectManager.scheduleReconnect(reason: DisconnectReason.appResumed);
      return;
    }

    // 后台时间超过阈值，验证连接
    if (backgroundDuration > _backgroundThreshold) {
      print('[Connection] 后台时间超过阈值，验证连接状态');
      _verifyConnection();
    }
  }

  /// 网络恢复
  void _onNetworkRestored() {
    print('[Connection] 网络已恢复');

    if (!isConnected && _savedConfig != null && _savedCredentials != null) {
      print('[Connection] 网络恢复但未连接，触发重连');
      _reconnectManager.scheduleReconnect(reason: DisconnectReason.networkError);
    }
  }

  /// 网络断开
  void _onNetworkLost() {
    print('[Connection] 网络已断开');
    // 网络断开时不立即触发重连，等待网络恢复
  }

  /// 验证连接状态（发送 ping 或 presence）
  void _verifyConnection() {
    if (!isConnected || _whixp == null) return;

    try {
      // 发送 presence 来验证连接
      _whixp!.sendPresence();
      print('[Connection] 已发送 presence 验证连接');
    } catch (e) {
      print('[Connection] 验证连接失败: $e');
      // 触发重连
      _reconnectManager.scheduleReconnect(reason: DisconnectReason.networkError);
    }
  }

  /// 执行重连
  Future<bool> _doReconnect() async {
    if (_savedConfig == null || _savedCredentials == null) {
      print('[Connection] 无保存的连接信息，无法重连');
      return false;
    }

    print('[Connection] 执行重连...');
    return await connect(_savedConfig!, _savedCredentials!);
  }

  /// 重连状态变化回调
  void _onReconnectStateChange(
    ReconnectState state,
    int attempt,
    int maxAttempts,
    Duration? nextRetryIn,
  ) {
    print('[Connection] 重连状态: $state, 尝试: $attempt/$maxAttempts');

    if (state == ReconnectState.reconnecting) {
      _updateState(ImConnectionState.reconnecting);
    }
  }

  /// 达到最大重连次数
  void _onMaxReconnectAttemptsReached() {
    print('[Connection] 达到最大重连次数，停止重连');
    _updateState(
      ImConnectionState.failed,
      error: '达到最大重连次数，请检查网络后手动重连',
    );
  }

  @override
  ImConnectionState get currentState => _currentState;

  @override
  Stream<ConnectionStateEvent> get connectionState => _stateController.stream;

  /// 接收消息流
  Stream<ReceivedMessage> get messageStream => _messageController.stream;

  @override
  String? get currentJid => _currentJid;

  /// 获取保存的配置（用于其他服务获取服务器地址）
  ImSdkConfig? get savedConfig => _savedConfig;

  /// 获取 Whixp 实例（用于 XEP-0363 文件上传等）
  Whixp? get whixp => _whixp;

  @override
  bool get isConnected => _currentState == ImConnectionState.authenticated;

  /// 重连管理器（供外部访问）
  ReconnectManager get reconnectManager => _reconnectManager;

  @override
  Future<bool> connect(ImSdkConfig config, ImCredentials credentials) async {
    if (_whixp != null) {
      await _disconnectInternal(triggerReconnect: false);
    }

    // 保存配置用于重连
    _savedConfig = config;
    _savedCredentials = credentials;

    // 初始化 ejabberd REST API 客户端
    // 假设 REST API 端口为 XMPP 端口 - 2（如 5222 -> 5280 或自定义）
    final apiPort = config.apiPort ?? 5280;
    final apiScheme = config.useTls ? 'https' : 'http';
    _ejabberdApi = EjabberdApiClient(
      baseUrl: '$apiScheme://${config.host}:$apiPort',
      // 不使用认证，ejabberd 配置为 IP 白名单模式
      // adminUser: credentials.username,
      // adminPassword: credentials.password,
    );

    // 重置重连管理器
    _reconnectManager.resetManualDisconnect();

    final completer = Completer<bool>();

    try {
      _updateState(ImConnectionState.connecting);

      // 创建临时数据库路径
      final tempDir = Directory.systemTemp;
      _dbPath =
          '${tempDir.path}/im_sdk_${DateTime.now().millisecondsSinceEpoch}';

      final fullCredentials = credentials.withDomain(config.domain);
      _currentJid = fullCredentials.jid;

      print('[Whixp] Creating connection with host=${config.host}, port=${config.port}, useTLS=${config.useTls}');

      // useTls=true: DirectTLS 连接（端口 5223，直接 TLS）
      // useTls=false: 明文连接（端口 5222，不使用任何 TLS）
      // 总是禁用 STARTTLS，因为 Whixp 的证书回调在 STARTTLS 升级时不生效
      const shouldDisableStartTLS = true;

      print('[Whixp] disableStartTLS: $shouldDisableStartTLS (always disabled)');

      _whixp = Whixp(
        jabberID: fullCredentials.jid,
        password: fullCredentials.password,
        host: config.host,
        port: config.port,
        useTLS: config.useTls,
        disableStartTLS: shouldDisableStartTLS,
        // 使用系统默认证书存储
        context: SecurityContext(withTrustedRoots: true),
        onBadCertificateCallback: (cert) {
          print('[Whixp] Certificate callback for: ${cert.subject}');
          return true; // 调试阶段接受所有证书
        },
        internalDatabasePath: _dbPath!,
        reconnectionPolicy: null,
      );

      // 监听状态变化
      _whixp!.addEventHandler<TransportState>('state', (state) {
        print('[Whixp] Transport state changed: $state');
        switch (state) {
          case TransportState.connected:
            print('[Whixp] TCP connection established!');
            _updateState(ImConnectionState.connected);
            break;
          case TransportState.disconnected:
            print('[Whixp] Disconnected');
            _updateState(ImConnectionState.disconnected);
            // 非手动断开时触发重连
            if (!_reconnectManager.isManuallyDisconnected) {
              print('[Whixp] 意外断开，调度重连');
              _reconnectManager.scheduleReconnect(reason: DisconnectReason.networkError);
            }
            break;
          case TransportState.connecting:
            print('[Whixp] Connecting to ${config.host}:${config.port}...');
            break;
          case TransportState.pickingAddress:
            print('[Whixp] DNS lookup for ${config.host}...');
            break;
          default:
            print('[Whixp] State: $state');
            break;
        }
      });

      // 监听连接尝试详情
      _whixp!.addEventHandler<String>('connecting', (address) {
        print('[Whixp] Trying to connect to $address on port ${config.port}');
      });

      // 监听流协商完成
      _whixp!.addEventHandler('streamNegotiated', (_) {
        print('[Whixp] Stream negotiated - authentication successful!');
        _updateState(ImConnectionState.authenticated);
        _reconnectManager.markConnectionSuccess();
        // 自动发送 Presence，告知服务器客户端已上线
        _whixp!.sendPresence();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      });

      // 监听会话开始（备用事件）
      _whixp!.addEventHandler('sessionStarted', (_) {
        print('[Whixp] Session started!');
        if (!completer.isCompleted) {
          _updateState(ImConnectionState.authenticated);
          _reconnectManager.markConnectionSuccess();
          _whixp!.sendPresence();
          completer.complete(true);
        }
      });

      // 监听认证成功
      _whixp!.addEventHandler('authenticationSuccess', (_) {
        print('[Whixp] Authentication success event!');
        if (!completer.isCompleted) {
          _updateState(ImConnectionState.authenticated);
          _reconnectManager.markConnectionSuccess();
          _whixp!.sendPresence();
          completer.complete(true);
        }
      });

      // 监听认证失败
      _whixp!.addEventHandler<String>('failedAuthentication', (reason) {
        print('[Whixp] Authentication failed: $reason');
        _updateState(ImConnectionState.failed, error: 'Authentication failed: $reason');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      // 监听连接失败
      _whixp!.addEventHandler<Object>('connectionFailure', (error) {
        print('[Whixp] Connection failure details: $error');
        print('[Whixp] Error type: ${error.runtimeType}');
        _updateState(ImConnectionState.failed, error: 'Connection failed: $error');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      // 监听 socket 错误
      _whixp!.addEventHandler<Object>('socketError', (error) {
        print('[Whixp] Socket error: $error');
      });

      // 监听收到的消息
      _whixp!.addEventHandler<Message?>('message', (message) {
        if (message == null) return;
        // 忽略错误类型的消息
        if (message.type == 'error') {
          print('[Whixp] Ignoring error message: ${message.body}');
          return;
        }

        final body = message.body;
        if (body != null && body.isNotEmpty) {
          // 详细日志：检查 from 字段
          final fromObj = message.from;
          String fromJid;
          if (fromObj == null) {
            fromJid = 'unknown';
            print('[Whixp] Message from is NULL');
          } else {
            // 使用 full 获取完整 JID（包括 resource）
            fromJid = fromObj.full.isNotEmpty ? fromObj.full : fromObj.toString();
            print('[Whixp] Message from - full: "${fromObj.full}", bare: "${fromObj.bare}", resource: "${fromObj.resource}"');
          }
          print('[Whixp] Message received - from: $fromJid, type: ${message.type}, body: $body');
          _messageController.add(ReceivedMessage(
            from: fromJid,
            to: message.to?.toString(),
            body: body,
            type: message.type ?? 'chat',
          ));
        }
      });

      // 开始连接
      _whixp!.connect();

      // 等待连接结果（30 秒超时）
      print('[Whixp] Waiting for connection result...');
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[Whixp] Connection timeout after 30 seconds!');
          _updateState(ImConnectionState.failed, error: 'Connection timeout');
          return false;
        },
      );
    } catch (e) {
      _updateState(ImConnectionState.failed, error: e.toString());
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    // 用户主动断开，标记为手动断开
    _reconnectManager.markManualDisconnect();
    await _disconnectInternal(triggerReconnect: false);
    // 清除保存的凭据
    _savedConfig = null;
    _savedCredentials = null;
  }

  /// 内部断开连接方法
  ///
  /// [triggerReconnect] 是否触发重连（非手动断开时使用）
  Future<void> _disconnectInternal({bool triggerReconnect = true}) async {
    if (_whixp != null) {
      try {
        _whixp!.disconnect();
      } catch (_) {
        // 忽略断开连接时的错误
      }
      _whixp = null;
    }
    _currentJid = null;
    _updateState(ImConnectionState.disconnected);

    // 清理临时数据库
    if (_dbPath != null) {
      try {
        final dbDir = Directory(_dbPath!);
        if (await dbDir.exists()) {
          await dbDir.delete(recursive: true);
        }
      } catch (_) {
        // 忽略清理错误
      }
      _dbPath = null;
    }

    // 触发重连
    if (triggerReconnect && !_reconnectManager.isManuallyDisconnected) {
      _reconnectManager.scheduleReconnect(reason: DisconnectReason.networkError);
    }
  }

  @override
  Future<void> sendMessage(String toJid, String body, {bool isGroupChat = false}) async {
    if (!isConnected || _whixp == null) {
      throw StateError('Not connected');
    }

    // 如果是群聊消息且未加入房间，先自动加入
    if (isGroupChat && !_joinedRooms.contains(toJid)) {
      final nickname = _currentJid?.split('@').first ?? 'user';
      print('[MUC] Auto-joining room before sending: $toJid');
      await joinRoom(toJid, nickname);
      // 等待一小段时间让加入完成
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _whixp!.sendMessage(
      JabberID(toJid),
      body: body,
      type: isGroupChat ? MessageType.groupchat : MessageType.chat,
    );
  }

  @override
  Future<void> sendPresence({String? show, String? status}) async {
    if (!isConnected || _whixp == null) {
      throw StateError('Not connected');
    }

    _whixp!.sendPresence(
      show: show,
      status: status,
    );
  }

  @override
  Future<void> joinRoom(String roomJid, String nickname) async {
    if (!isConnected || _whixp == null) {
      throw StateError('Not connected');
    }

    // MUC join 需要发送特定的 presence
    final mucJid = '$roomJid/$nickname';
    _whixp!.sendPresence(to: JabberID(mucJid));

    // 记录已加入的房间
    _joinedRooms.add(roomJid);
    print('[MUC] Joined room: $roomJid as $nickname');
  }

  @override
  Future<void> leaveRoom(String roomJid, String nickname) async {
    if (_whixp == null) return;

    final mucJid = '$roomJid/$nickname';
    _whixp!.sendPresence(
      to: JabberID(mucJid),
      type: 'unavailable',
    );

    // 从已加入列表中移除
    _joinedRooms.remove(roomJid);
    print('[MUC] Left room: $roomJid');
  }

  /// 创建 MUC 群聊房间
  ///
  /// [roomName] 房间显示名称
  /// [members] 要邀请的成员 JID 列表
  /// 返回房间 JID
  Future<String> createRoom(String roomName, List<String> members) async {
    if (!isConnected || _whixp == null) {
      throw StateError('Not connected');
    }

    final domain = _currentJid?.split('@').last ?? 'localhost';
    final nickname = _currentJid?.split('@').first ?? 'user';

    // 生成房间 JID (使用时间戳作为唯一 ID)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final roomJid = 'room_$timestamp@conference.$domain';

    // 加入/创建房间（发送 presence 到房间）
    await joinRoom(roomJid, nickname);

    // 等待一小段时间让房间创建完成
    await Future.delayed(const Duration(milliseconds: 500));

    // 邀请成员，传递群名，并通过 API 添加到房间成员列表
    final invitedNames = <String>[];
    for (final memberJid in members) {
      try {
        // 通过 API 将成员添加到房间（设置 affiliation 为 member）
        await inviteMember(roomJid, memberJid);
        // 发送邀请通知消息
        await inviteToRoom(roomJid, memberJid, roomName);
        invitedNames.add(memberJid.split('@').first);
      } catch (e) {
        print('[MUC] 邀请成员失败: $memberJid, 错误: $e');
      }
    }

    // 向群里发送一条创建通知（可选）
    if (invitedNames.isNotEmpty) {
      await sendMessage(
        roomJid,
        '群聊「$roomName」已创建，已邀请: ${invitedNames.join(', ')}',
        isGroupChat: true,
      );
    }

    return roomJid;
  }

  /// 邀请用户加入群聊
  Future<void> inviteToRoom(String roomJid, String userJid, [String? roomName]) async {
    if (!isConnected || _whixp == null) {
      throw StateError('Not connected');
    }

    // 发送邀请消息给被邀请者（单聊消息）
    // 格式: 你被邀请加入群聊|群名|roomJid
    final displayName = roomName ?? '群聊';
    _whixp!.sendMessage(
      JabberID(userJid),
      body: '你被邀请加入群聊|$displayName|$roomJid',
      type: MessageType.chat, // 确保是单聊消息
    );
  }

  // ============================================================================
  // MUC 群聊管理功能（通过 ejabberd REST API）
  // ============================================================================

  /// 从 roomJid 解析房间名和服务域
  ///
  /// roomJid 格式: room_name@conference.domain
  (String room, String service) _parseRoomJid(String roomJid) {
    final parts = roomJid.split('@');
    if (parts.length != 2) {
      throw ArgumentError('Invalid room JID format: $roomJid');
    }
    return (parts[0], parts[1]);
  }

  /// 获取群聊成员列表
  ///
  /// 通过 ejabberd REST API 获取完整成员列表（包括离线成员）
  Future<List<MucMember>> getRoomMembers(String roomJid) async {
    if (_ejabberdApi == null) {
      throw StateError('ejabberd API not initialized');
    }

    print('[MUC] 获取群成员: $roomJid');

    final (room, service) = _parseRoomJid(roomJid);

    try {
      // 获取成员角色列表
      final affiliations = await _ejabberdApi!.getRoomAffiliations(room, service);

      return affiliations.map((a) => MucMember(
        jid: a.jid,
        affiliation: a.affiliation,
        role: 'participant', // 角色需要从 occupants 获取
      )).toList();
    } catch (e) {
      print('[MUC] 获取群成员失败: $e');
      rethrow;
    }
  }

  /// 踢出群成员（临时移除，可重新加入）
  ///
  /// 注意：这需要通过 XMPP presence 实现，REST API 不直接支持
  Future<void> kickMember(String roomJid, String memberNickname, {String? reason}) async {
    if (!isConnected || _whixp == null) {
      throw StateError('Not connected');
    }

    print('[MUC] 踢出成员: $memberNickname from $roomJid');
    // 踢出是临时的，通过设置 role 为 none 实现
    // 这需要 XMPP IQ 实现，暂时用 removeMember 替代
  }

  /// 永久移除群成员
  ///
  /// 设置成员 affiliation 为 none，永久移除
  Future<void> removeMember(String roomJid, String memberJid) async {
    if (_ejabberdApi == null) {
      throw StateError('ejabberd API not initialized');
    }

    print('[MUC] 移除成员: $memberJid from $roomJid');

    final (room, service) = _parseRoomJid(roomJid);

    try {
      await _ejabberdApi!.setRoomAffiliation(room, service, memberJid, 'none');
      print('[MUC] 成员已移除');
    } catch (e) {
      print('[MUC] 移除成员失败: $e');
      rethrow;
    }
  }

  /// 邀请用户加入群聊
  ///
  /// 设置用户 affiliation 为 member
  Future<void> inviteMember(String roomJid, String memberJid) async {
    if (_ejabberdApi == null) {
      throw StateError('ejabberd API not initialized');
    }

    print('[MUC] 邀请成员: $memberJid to $roomJid');

    final (room, service) = _parseRoomJid(roomJid);

    try {
      await _ejabberdApi!.setRoomAffiliation(room, service, memberJid, 'member');
      print('[MUC] 成员已邀请');
    } catch (e) {
      print('[MUC] 邀请成员失败: $e');
      rethrow;
    }
  }

  /// 设置群成员角色
  ///
  /// [affiliation] 可选: owner, admin, member, outcast, none
  Future<void> setMemberAffiliation(
    String roomJid,
    String memberJid,
    String affiliation,
  ) async {
    if (_ejabberdApi == null) {
      throw StateError('ejabberd API not initialized');
    }

    print('[MUC] 设置角色: $memberJid -> $affiliation in $roomJid');

    final (room, service) = _parseRoomJid(roomJid);

    try {
      await _ejabberdApi!.setRoomAffiliation(room, service, memberJid, affiliation);
      print('[MUC] 角色已设置');
    } catch (e) {
      print('[MUC] 设置角色失败: $e');
      rethrow;
    }
  }

  /// 修改群名称
  Future<void> setRoomName(String roomJid, String newName) async {
    if (_ejabberdApi == null) {
      throw StateError('ejabberd API not initialized');
    }

    print('[MUC] 修改群名称: $roomJid -> $newName');

    final (room, service) = _parseRoomJid(roomJid);

    try {
      await _ejabberdApi!.changeRoomOption(room, service, 'title', newName);
      print('[MUC] 群名称已修改');
    } catch (e) {
      print('[MUC] 修改群名称失败: $e');
      rethrow;
    }
  }

  /// 销毁群聊（群主权限）
  Future<void> destroyRoom(String roomJid, {String? reason}) async {
    if (_ejabberdApi == null) {
      throw StateError('ejabberd API not initialized');
    }

    print('[MUC] 销毁群聊: $roomJid');

    final (room, service) = _parseRoomJid(roomJid);

    try {
      await _ejabberdApi!.destroyRoom(room, service, reason: reason);
      print('[MUC] 群聊已销毁');
    } catch (e) {
      print('[MUC] 销毁群聊失败: $e');
      rethrow;
    }
  }

  /// 获取群聊配置
  Future<Map<String, dynamic>> getRoomOptions(String roomJid) async {
    if (_ejabberdApi == null) {
      throw StateError('ejabberd API not initialized');
    }

    final (room, service) = _parseRoomJid(roomJid);
    return await _ejabberdApi!.getRoomOptions(room, service);
  }

  /// 退出群聊（普通成员）
  ///
  /// 对于群主，需要先转让或销毁群聊
  Future<void> quitRoom(String roomJid) async {
    if (!isConnected || _currentJid == null) {
      throw StateError('Not connected');
    }

    print('[MUC] 退出群聊: $roomJid');

    // 先离开房间（发送离开 presence）
    final nickname = _currentJid!.split('@').first;
    await leaveRoom(roomJid, nickname);

    // 然后移除自己的 affiliation
    if (_ejabberdApi != null) {
      final (room, service) = _parseRoomJid(roomJid);
      try {
        await _ejabberdApi!.setRoomAffiliation(room, service, _currentJid!, 'none');
      } catch (e) {
        print('[MUC] 移除 affiliation 失败: $e');
        // 忽略错误，已经离开房间了
      }
    }
  }

  void _updateState(ImConnectionState state, {String? error}) {
    _currentState = state;
    _stateController.add(ConnectionStateEvent(state: state, error: error));
  }

  @override
  void dispose() {
    _reconnectManager.markManualDisconnect();
    _reconnectManager.dispose();
    _lifecycleSubscription?.cancel();
    _lifecycleService.dispose();
    disconnect();
    _stateController.close();
    _messageController.close();
  }

  /// 手动触发重连
  ///
  /// 当自动重连失败后，用户可以调用此方法手动重连
  Future<bool> manualReconnect() async {
    if (_savedConfig == null || _savedCredentials == null) {
      print('[Connection] 无保存的连接信息，无法重连');
      return false;
    }

    _reconnectManager.resetManualDisconnect();
    return await connect(_savedConfig!, _savedCredentials!);
  }

  /// 获取所有注册用户
  ///
  /// 返回用户 JID 列表（排除当前用户）
  Future<List<String>> getRegisteredUsers() async {
    if (_ejabberdApi == null) {
      print('[Connection] ejabberd API 未初始化');
      return [];
    }

    final domain = _savedConfig?.domain ?? 'localhost';

    try {
      final users = await _ejabberdApi!.getRegisteredUsers(domain);
      // 转换为 JID 格式并排除当前用户
      return users
          .map((user) => '$user@$domain')
          .where((jid) => jid != _currentJid)
          .toList();
    } catch (e) {
      print('[Connection] 获取注册用户失败: $e');
      return [];
    }
  }
}
