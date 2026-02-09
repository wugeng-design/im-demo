/// 音频播放状态管理
///
/// 功能：
/// - 全局音频播放控制（同时只播放一个）
/// - 播放状态管理
/// - 播放进度追踪
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// 音频播放状态
class AudioPlaybackState {
  const AudioPlaybackState({
    this.currentMessageId,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  /// 当前播放的消息 ID（null 表示没有播放）
  final String? currentMessageId;

  /// 是否正在播放
  final bool isPlaying;

  /// 当前播放位置
  final Duration position;

  /// 总时长
  final Duration duration;

  AudioPlaybackState copyWith({
    String? currentMessageId,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool clearMessageId = false,
  }) {
    return AudioPlaybackState(
      currentMessageId:
          clearMessageId ? null : (currentMessageId ?? this.currentMessageId),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

/// 音频播放控制器
class AudioPlaybackNotifier extends StateNotifier<AudioPlaybackState> {
  AudioPlaybackNotifier() : super(const AudioPlaybackState());

  AudioPlayer? _player;

  /// 播放或暂停音频
  ///
  /// 如果是同一个消息，切换播放/暂停
  /// 如果是不同消息，停止当前播放，开始新的
  ///
  /// [localFilePath] 本地文件路径（优先使用）
  Future<void> togglePlay(
    String messageId,
    String audioUrl, {
    String? localFilePath,
  }) async {
    // 同一个消息：切换播放/暂停
    if (state.currentMessageId == messageId) {
      if (state.isPlaying) {
        await _player?.pause();
        state = state.copyWith(isPlaying: false);
      } else {
        await _player?.play();
        state = state.copyWith(isPlaying: true);
      }
      return;
    }

    // 不同消息：停止当前，播放新的
    await stop();

    try {
      _player = AudioPlayer();

      // 监听播放状态
      _player!.playerStateStream.listen((playerState) {
        if (!mounted) return;

        final isPlaying = playerState.playing;
        final processingState = playerState.processingState;

        // 播放完成
        if (processingState == ProcessingState.completed) {
          state = state.copyWith(
            isPlaying: false,
            position: Duration.zero,
          );
          return;
        }

        state = state.copyWith(isPlaying: isPlaying);
      });

      // 监听播放位置
      _player!.positionStream.listen((position) {
        if (!mounted) return;
        state = state.copyWith(position: position);
      });

      // 监听时长
      _player!.durationStream.listen((duration) {
        if (!mounted) return;
        if (duration != null) {
          state = state.copyWith(duration: duration);
        }
      });

      // 设置音频源并播放（优先使用本地文件）
      if (localFilePath != null && localFilePath.isNotEmpty) {
        await _player!.setFilePath(localFilePath);
      } else {
        await _player!.setUrl(audioUrl);
      }

      state = AudioPlaybackState(
        currentMessageId: messageId,
        isPlaying: true,
        duration: _player!.duration ?? Duration.zero,
      );

      await _player!.play();
    } catch (e) {
      // 播放失败，重置状态
      state = const AudioPlaybackState();
      _player?.dispose();
      _player = null;
    }
  }

  /// 停止播放
  Future<void> stop() async {
    await _player?.stop();
    _player?.dispose();
    _player = null;
    state = const AudioPlaybackState();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }
}

/// 音频播放 Provider
final audioPlaybackProvider =
    StateNotifierProvider<AudioPlaybackNotifier, AudioPlaybackState>((ref) {
  return AudioPlaybackNotifier();
});

/// 检查特定消息是否正在播放
bool isMessagePlaying(AudioPlaybackState state, String messageId) {
  return state.currentMessageId == messageId && state.isPlaying;
}
