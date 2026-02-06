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

      _whixp = Whixp(
        jabberID: fullCredentials.jid,
        password: fullCredentials.password,
        host: config.host,
        port: config.port,
        useTLS: false,
        context: SecurityContext(withTrustedRoots: false),
        onBadCertificateCallback: (cert) => true,
        internalDatabasePath: _dbPath!,
        reconnectionPolicy: null,
      );

      // 监听状态变化
      _whixp!.addEventHandler<TransportState>('state', (state) {
        switch (state) {
          case TransportState.connected:
            _updateState(ImConnectionState.connected);
            break;
          case TransportState.disconnected:
            _updateState(ImConnectionState.disconnected);
            break;
          default:
            break;
        }
      });

      // 监听流协商完成
      _whixp!.addEventHandler('streamNegotiated', (_) {
        _updateState(ImConnectionState.authenticated);
        // 自动发送 Presence，告知服务器客户端已上线
        _whixp!.sendPresence();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      });

      // 监听认证失败
      _whixp!.addEventHandler<String>('failedAuthentication', (reason) {
        _updateState(ImConnectionState.failed, error: 'Authentication failed: $reason');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      // 监听连接失败
      _whixp!.addEventHandler<Object>('connectionFailure', (error) {
        _updateState(ImConnectionState.failed, error: 'Connection failed: $error');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
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
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
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
