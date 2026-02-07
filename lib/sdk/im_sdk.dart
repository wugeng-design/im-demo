/// IM SDK for Demo
///
/// 独立的 IM SDK，可连接任何 XMPP 服务器

// 扩展接口
export 'extensions/group_metadata_provider.dart';
export 'extensions/member_sync_provider.dart';
export 'extensions/im_extension_registry.dart';

// 核心模型
export 'models/im_conversation.dart';
export 'models/conversation.dart';
export 'models/message.dart';
export 'models/contact.dart';

// 配置
export 'config/im_sdk_config.dart';

// 连接服务
export 'services/im_connection_service.dart';
export 'services/impl/standalone_connection_service.dart';
