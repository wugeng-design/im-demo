/// 群组元数据提供者接口
///
/// SDK 扩展点：允许业务层注入群组的业务元数据
///
/// 设计目的：
/// - 将业务特定数据（classId、communityId、courseInfo 等）与核心 IM 功能解耦
/// - 允许不同业务场景提供不同的元数据实现
/// - SDK 核心只依赖此接口，不直接依赖业务 API
///
/// 使用示例：
/// ```dart
/// class EdxGroupMetadataProvider implements GroupMetadataProvider {
///   final EdxApiClient _apiClient;
///
///   @override
///   Future<GroupMetadata?> getGroupMetadata(String roomBareJid) async {
///     final classInfo = await _apiClient.getClassInfo(roomBareJid);
///     return GroupMetadata(
///       groupType: classInfo.type,
///       displayName: classInfo.className,
///       businessId: classInfo.classId.toString(),
///       extra: {'courseId': classInfo.courseId},
///     );
///   }
/// }
/// ```

/// 群组元数据
///
/// 包含业务层需要关联到群组的额外信息
class GroupMetadata {
  /// 群组类型（业务定义，如 'class', 'study_group', 'community'）
  final String? groupType;

  /// 业务显示名称（如班级名称，优先于 XMPP 群名）
  final String? displayName;

  /// 业务 ID（如 classId、communityId）
  final String? businessId;

  /// 社区 ID（用于社区聚合）
  final int? communityId;

  /// 社区名称
  final String? communityName;

  /// 社区类型（用于显示 tag）
  final String? communityType;

  /// 额外的业务数据
  final Map<String, dynamic> extra;

  const GroupMetadata({
    this.groupType,
    this.displayName,
    this.businessId,
    this.communityId,
    this.communityName,
    this.communityType,
    Map<String, dynamic>? extra,
  }) : extra = extra ?? const {};

  /// 空元数据
  static const empty = GroupMetadata();

  /// 是否为空
  bool get isEmpty =>
      groupType == null &&
      displayName == null &&
      businessId == null &&
      communityId == null;

  @override
  String toString() => 'GroupMetadata('
      'groupType: $groupType, '
      'displayName: $displayName, '
      'businessId: $businessId, '
      'communityId: $communityId)';
}

/// 群组元数据提供者接口
///
/// 业务层实现此接口，为 IM SDK 提供群组的业务元数据
abstract class GroupMetadataProvider {
  /// 获取单个群组的元数据
  ///
  /// [roomBareJid] 群组 JID（如 room123@conference.example.com）
  /// 返回 null 表示无业务元数据（纯 IM 群组）
  Future<GroupMetadata?> getGroupMetadata(String roomBareJid);

  /// 批量获取群组元数据
  ///
  /// [roomBareJids] 群组 JID 列表
  /// 返回 Map<roomBareJid, metadata>，不存在的群组不在结果中
  Future<Map<String, GroupMetadata>> getGroupMetadataBatch(
    List<String> roomBareJids,
  );

  /// 监听群组元数据变化
  ///
  /// 当业务数据更新时（如班级改名），通过此流通知 SDK 刷新显示
  Stream<GroupMetadataUpdate> get metadataUpdates;
}

/// 群组元数据更新事件
class GroupMetadataUpdate {
  /// 更新的群组 JID
  final String roomBareJid;

  /// 新的元数据（null 表示删除）
  final GroupMetadata? metadata;

  const GroupMetadataUpdate({
    required this.roomBareJid,
    this.metadata,
  });
}

/// 默认空实现
///
/// 当业务层未注册 Provider 时使用
class NoOpGroupMetadataProvider implements GroupMetadataProvider {
  const NoOpGroupMetadataProvider();

  @override
  Future<GroupMetadata?> getGroupMetadata(String roomBareJid) async => null;

  @override
  Future<Map<String, GroupMetadata>> getGroupMetadataBatch(
    List<String> roomBareJids,
  ) async =>
      const {};

  @override
  Stream<GroupMetadataUpdate> get metadataUpdates => const Stream.empty();
}
