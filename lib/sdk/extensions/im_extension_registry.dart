import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'group_metadata_provider.dart';
import 'member_sync_provider.dart';

/// IM SDK 扩展注册表
///
/// 集中管理业务层注入的扩展实现
///
/// 设计目的：
/// - 提供统一的扩展注册入口
/// - 支持运行时动态注册/替换
/// - 通过 Riverpod Provider 暴露给 SDK 内部使用
///
/// 使用示例：
/// ```dart
/// // 业务层初始化时注册扩展
/// void initializeImSdk(WidgetRef ref) {
///   final registry = ref.read(imExtensionRegistryProvider);
///
///   // 注册群组元数据提供者
///   registry.registerGroupMetadataProvider(
///     EdxGroupMetadataProvider(apiClient: ref.read(apiClientProvider)),
///   );
///
///   // 注册成员同步提供者
///   registry.registerMemberSyncProvider(
///     EdxMemberSyncProvider(apiClient: ref.read(apiClientProvider)),
///   );
/// }
/// ```

/// IM SDK 扩展注册表
class ImExtensionRegistry {
  /// 群组元数据提供者
  GroupMetadataProvider _groupMetadataProvider = const NoOpGroupMetadataProvider();

  /// 成员同步提供者
  MemberSyncProvider _memberSyncProvider = const NoOpMemberSyncProvider();

  /// 获取群组元数据提供者
  GroupMetadataProvider get groupMetadataProvider => _groupMetadataProvider;

  /// 获取成员同步提供者
  MemberSyncProvider get memberSyncProvider => _memberSyncProvider;

  /// 注册群组元数据提供者
  ///
  /// 替换默认的 NoOp 实现
  void registerGroupMetadataProvider(GroupMetadataProvider provider) {
    _groupMetadataProvider = provider;
  }

  /// 注册成员同步提供者
  ///
  /// 替换默认的 NoOp 实现
  void registerMemberSyncProvider(MemberSyncProvider provider) {
    _memberSyncProvider = provider;
  }

  /// 重置所有扩展为默认实现
  ///
  /// 用于测试或登出清理
  void reset() {
    _groupMetadataProvider = const NoOpGroupMetadataProvider();
    _memberSyncProvider = const NoOpMemberSyncProvider();
  }

  /// 检查是否已注册业务扩展
  bool get hasBusinessExtensions =>
      _groupMetadataProvider is! NoOpGroupMetadataProvider ||
      _memberSyncProvider is! NoOpMemberSyncProvider;
}

/// 扩展注册表 Provider（单例）
///
/// 在应用生命周期内保持同一实例
final imExtensionRegistryProvider = Provider<ImExtensionRegistry>((ref) {
  return ImExtensionRegistry();
});

/// 群组元数据提供者 Provider
///
/// 便捷访问当前注册的 GroupMetadataProvider
final groupMetadataProviderProvider = Provider<GroupMetadataProvider>((ref) {
  final registry = ref.watch(imExtensionRegistryProvider);
  return registry.groupMetadataProvider;
});

/// 成员同步提供者 Provider
///
/// 便捷访问当前注册的 MemberSyncProvider
final memberSyncProviderProvider = Provider<MemberSyncProvider>((ref) {
  final registry = ref.watch(imExtensionRegistryProvider);
  return registry.memberSyncProvider;
});
