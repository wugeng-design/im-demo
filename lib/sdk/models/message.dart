import 'dart:convert';

import 'media.dart';

/// 消息类型
enum MessageType {
  text,
  image,
  video,
  file,
  system,
}

/// 消息模型
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String body;
  final DateTime timestamp;
  final bool isMe;
  final String? status; // sending, sent, delivered, read, failed
  final MessageType messageType;
  final MediaMetadata? media;
  final bool isEdited;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.body,
    required this.timestamp,
    this.isMe = false,
    this.status = 'sent',
    this.messageType = MessageType.text,
    this.media,
    this.isEdited = false,
  });

  /// 是否是媒体消息
  bool get isMediaMessage =>
      messageType == MessageType.image ||
      messageType == MessageType.video ||
      messageType == MessageType.file;

  /// 获取显示文本（媒体消息显示类型描述）
  String get displayBody {
    switch (messageType) {
      case MessageType.image:
        return '[图片]';
      case MessageType.video:
        return '[视频]';
      case MessageType.file:
        return '[文件] ${media?.fileName ?? ''}';
      case MessageType.system:
        return body;
      case MessageType.text:
      default:
        return body;
    }
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? body,
    DateTime? timestamp,
    bool? isMe,
    String? status,
    MessageType? messageType,
    MediaMetadata? media,
    bool? isEdited,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      status: status ?? this.status,
      messageType: messageType ?? this.messageType,
      media: media ?? this.media,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  /// 从 JSON 创建
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderAvatar: json['senderAvatar'] as String?,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isMe: json['isMe'] as bool? ?? false,
      status: json['status'] as String?,
      messageType: MessageType.values.firstWhere(
        (t) => t.name == json['messageType'],
        orElse: () => MessageType.text,
      ),
      media: json['media'] != null
          ? MediaMetadata.fromJson(json['media'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe,
      'status': status,
      'messageType': messageType.name,
      'media': media?.toJson(),
    };
  }

  /// 序列化媒体数据为 JSON 字符串（用于数据库存储）
  String? get mediaJson => media != null ? jsonEncode(media!.toJson()) : null;

  /// 从 JSON 字符串反序列化媒体数据
  static MediaMetadata? parseMediaJson(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return MediaMetadata.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}
