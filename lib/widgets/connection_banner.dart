import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/im_provider.dart';
import '../sdk/services/im_connection_service.dart' show ImConnectionState;
import '../sdk/services/reconnect_manager.dart';
import '../theme/im_design_tokens.dart';

/// 连接状态横幅
///
/// 在页面顶部显示当前连接状态：
/// - 连接中
/// - 已断开（点击重连）
/// - 重连中（显示倒计时）
/// - 重连失败（手动重连）
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(imConnectionStateProvider);
    final reconnectState = ref.watch(reconnectStateProvider);
    final isConnected = ref.watch(isConnectedProvider);

    // 已连接则不显示
    if (isConnected) {
      return const SizedBox.shrink();
    }

    return connectionState.when(
      data: (event) => _buildBanner(context, ref, event.state, reconnectState),
      loading: () => _buildLoadingBanner(context),
      error: (_, __) => _buildErrorBanner(context, ref),
    );
  }

  Widget _buildBanner(
    BuildContext context,
    WidgetRef ref,
    ImConnectionState state,
    ReconnectState reconnectState,
  ) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    String message;
    Color backgroundColor;
    Color textColor;
    IconData icon;
    VoidCallback? onTap;

    switch (state) {
      case ImConnectionState.connecting:
        message = '正在连接...';
        backgroundColor = colors.primary.withValues(alpha: 0.1);
        textColor = colors.primary;
        icon = Icons.sync;
        break;

      case ImConnectionState.disconnected:
        if (reconnectState == ReconnectState.waiting) {
          message = '连接已断开，正在重连...';
          backgroundColor = Colors.orange.withValues(alpha: 0.1);
          textColor = Colors.orange;
          icon = Icons.sync;
        } else if (reconnectState == ReconnectState.maxAttemptsReached) {
          message = '连接失败，点击重试';
          backgroundColor = Colors.red.withValues(alpha: 0.1);
          textColor = Colors.red;
          icon = Icons.error_outline;
          onTap = () => _manualReconnect(ref);
        } else {
          message = '网络已断开，点击重连';
          backgroundColor = Colors.red.withValues(alpha: 0.1);
          textColor = Colors.red;
          icon = Icons.wifi_off;
          onTap = () => _manualReconnect(ref);
        }
        break;

      case ImConnectionState.connected:
        return const SizedBox.shrink();

      case ImConnectionState.failed:
        message = '连接错误，点击重试';
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red;
        icon = Icons.error_outline;
        onTap = () => _manualReconnect(ref);
        break;

      case ImConnectionState.authenticating:
      case ImConnectionState.authenticated:
      case ImConnectionState.reconnecting:
        // 这些状态在其他地方处理
        return const SizedBox.shrink();
    }

    return Material(
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              bottom: BorderSide(color: colors.divider, width: 0.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(icon, textColor, state == ImConnectionState.connecting),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: textColor,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color color, bool isAnimating) {
    final iconWidget = Icon(icon, color: color, size: 16);

    if (isAnimating) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(seconds: 1),
        builder: (context, value, child) {
          return Transform.rotate(
            angle: value * 2 * 3.14159,
            child: child,
          );
        },
        onEnd: () {},
        child: iconWidget,
      );
    }

    return iconWidget;
  }

  Widget _buildLoadingBanner(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(colors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '正在连接...',
              style: TextStyle(color: colors.primary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, WidgetRef ref) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Material(
      child: InkWell(
        onTap: () => _manualReconnect(ref),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(color: colors.divider, width: 0.5),
            ),
          ),
          child: const SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text(
                  '连接失败，点击重试',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.red, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _manualReconnect(WidgetRef ref) {
    final service = ref.read(imConnectionServiceProvider);
    service.manualReconnect();
  }
}

/// 带连接状态横幅的 Scaffold 包装器
class ConnectionAwareScaffold extends ConsumerWidget {
  const ConnectionAwareScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.background,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
