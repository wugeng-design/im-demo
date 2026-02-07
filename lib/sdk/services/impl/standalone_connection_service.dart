import 'dart:async';
import 'dart:io';

import 'package:whixp/whixp.dart';

import '../../config/im_sdk_config.dart';
import '../im_connection_service.dart';

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

  @override
  ImConnectionState get currentState => _currentState;

  @override
  Stream<ConnectionStateEvent> get connectionState => _stateController.stream;

  /// 接收消息流
  Stream<ReceivedMessage> get messageStream => _messageController.stream;

  @override
  String? get currentJid => _currentJid;

  @override
  bool get isConnected => _currentState == ImConnectionState.authenticated;

  @override
  Future<bool> connect(ImSdkConfig config, ImCredentials credentials) async {
    if (_whixp != null) {
      await disconnect();
    }

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

      // 对于不要求 TLS 的服务器，禁用 STARTTLS 尝试
      final shouldDisableStartTLS = !config.useTls &&
          (config.host == 'localhost' ||
           config.host.startsWith('192.168.') ||
           config.host.startsWith('10.') ||
           RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(config.host)); // IP 地址

      print('[Whixp] disableStartTLS: $shouldDisableStartTLS');

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
          _whixp!.sendPresence();
          completer.complete(true);
        }
      });

      // 监听认证成功
      _whixp!.addEventHandler('authenticationSuccess', (_) {
        print('[Whixp] Authentication success event!');
        if (!completer.isCompleted) {
          _updateState(ImConnectionState.authenticated);
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
        final body = message.body;
        if (body != null && body.isNotEmpty) {
          _messageController.add(ReceivedMessage(
            from: message.from?.toString() ?? 'unknown',
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
  }

  @override
  Future<void> sendMessage(String toJid, String body, {bool isGroupChat = false}) async {
    if (!isConnected || _whixp == null) {
      throw StateError('Not connected');
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
  }

  @override
  Future<void> leaveRoom(String roomJid, String nickname) async {
    if (_whixp == null) return;

    final mucJid = '$roomJid/$nickname';
    _whixp!.sendPresence(
      to: JabberID(mucJid),
      type: 'unavailable',
    );
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

    // 邀请成员，传递群名
    final invitedNames = <String>[];
    for (final memberJid in members) {
      await inviteToRoom(roomJid, memberJid, roomName);
      invitedNames.add(memberJid.split('@').first);
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

  void _updateState(ImConnectionState state, {String? error}) {
    _currentState = state;
    _stateController.add(ConnectionStateEvent(state: state, error: error));
  }

  @override
  void dispose() {
    disconnect();
    _stateController.close();
    _messageController.close();
  }
}
