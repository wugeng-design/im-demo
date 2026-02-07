/// 消息模型
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime timestamp;
  final bool isMe;
  final String? status; // sent, delivered, read, failed
  final String? type; // text, image, file, etc.

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.timestamp,
    this.isMe = false,
    this.status = 'sent',
    this.type = 'text',
  });

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? body,
    DateTime? timestamp,
    bool? isMe,
    String? status,
    String? type,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      status: status ?? this.status,
      type: type ?? this.type,
    );
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}
