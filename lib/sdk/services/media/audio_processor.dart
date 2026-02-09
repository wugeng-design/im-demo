/// 音频处理服务
///
/// 提供音频波形生成、时长获取等功能
/// 用于语音消息的元数据提取和波形可视化
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, Uint8List, debugPrint;
import 'package:just_audio/just_audio.dart';

/// 音频处理服务
///
/// 封装音频元数据提取和波形数据生成
///
/// 使用示例：
/// ```dart
/// // 获取音频时长
/// final duration = await AudioProcessor.getAudioDuration('/path/to/audio.mp3');
///
/// // 生成波形数据
/// final waveform = await AudioProcessor.generateWaveform('/path/to/audio.mp3');
/// ```
class AudioProcessor {
  static final AudioPlayer _player = AudioPlayer();

  /// 获取音频时长
  ///
  /// [audioPath] 音频文件路径
  /// 返回音频时长（秒），失败返回 null
  static Future<double?> getAudioDuration(String audioPath) async {
    if (kIsWeb) {
      debugPrint('[AudioProcessor] Web 平台音频处理受限');
    }

    try {
      debugPrint('[AudioProcessor] 获取音频时长 - $audioPath');

      final duration = await _player.setFilePath(audioPath);

      if (duration != null) {
        final seconds = duration.inMilliseconds / 1000.0;
        debugPrint('[AudioProcessor] 时长 ${formatDuration(seconds)}');
        return seconds;
      } else {
        debugPrint('[AudioProcessor] 无法获取音频时长');
        return null;
      }
    } catch (e) {
      debugPrint('[AudioProcessor] 获取时长失败: $e');
      return null;
    } finally {
      await _player.stop();
    }
  }

  /// 生成简易波形数据
  ///
  /// 基于音频文件生成波形采样点
  /// 注意：这是一个简化版本，生成的是模拟波形数据
  ///
  /// [audioPath] 音频文件路径
  /// [samplesCount] 采样点数量
  /// 返回归一化的波形数据列表 (0.0 - 1.0)
  static Future<List<double>> generateWaveform(
    String audioPath, {
    int samplesCount = 50,
  }) async {
    if (kIsWeb) {
      debugPrint('[AudioProcessor] Web 平台不支持波形生成');
      return _generatePlaceholderWaveform(samplesCount);
    }

    try {
      debugPrint('[AudioProcessor] 生成音频波形 (采样点: $samplesCount)');

      final file = File(audioPath);
      if (!await file.exists()) {
        debugPrint('[AudioProcessor] 文件不存在');
        return _generatePlaceholderWaveform(samplesCount);
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return _generatePlaceholderWaveform(samplesCount);
      }

      final waveform = _extractWaveformFromBytes(bytes, samplesCount);
      debugPrint('[AudioProcessor] 波形生成成功');
      return waveform;
    } catch (e) {
      debugPrint('[AudioProcessor] 波形生成失败: $e');
      return _generatePlaceholderWaveform(samplesCount);
    }
  }

  /// 从字节数据提取波形
  static List<double> _extractWaveformFromBytes(
    Uint8List bytes,
    int samplesCount,
  ) {
    if (bytes.isEmpty) return List.filled(samplesCount, 0.5);

    final waveform = <double>[];
    final chunkSize = bytes.length ~/ samplesCount;

    if (chunkSize == 0) {
      return _generatePlaceholderWaveform(samplesCount);
    }

    for (int i = 0; i < samplesCount; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize).clamp(0, bytes.length);

      double sum = 0;
      for (int j = start; j < end; j++) {
        final value = bytes[j];
        sum += (value - 128).abs();
      }

      final average = sum / (end - start);
      final normalized = (average / 128.0).clamp(0.0, 1.0);
      waveform.add(normalized);
    }

    return _smoothWaveform(waveform);
  }

  /// 平滑波形数据
  static List<double> _smoothWaveform(List<double> waveform) {
    if (waveform.length < 3) return waveform;

    final smoothed = <double>[];
    for (int i = 0; i < waveform.length; i++) {
      if (i == 0 || i == waveform.length - 1) {
        smoothed.add(waveform[i]);
      } else {
        final avg = (waveform[i - 1] + waveform[i] + waveform[i + 1]) / 3;
        smoothed.add(avg);
      }
    }
    return smoothed;
  }

  /// 生成占位波形
  static List<double> _generatePlaceholderWaveform(int count) {
    final waveform = <double>[];
    for (int i = 0; i < count; i++) {
      final value = 0.3 + 0.4 * (0.5 + 0.5 * (i / count) * (1 - i / count) * 4);
      waveform.add(value.clamp(0.2, 0.8));
    }
    return waveform;
  }

  /// 将波形数据序列化为字符串（用于存储）
  static String serializeWaveform(List<double> waveform) {
    return waveform.map((v) => v.toStringAsFixed(3)).join(',');
  }

  /// 从字符串反序列化波形数据
  static List<double> deserializeWaveform(String waveformString) {
    if (waveformString.isEmpty) return [];

    try {
      return waveformString
          .split(',')
          .map((s) => double.parse(s.trim()))
          .toList();
    } catch (e) {
      debugPrint('[AudioProcessor] 波形反序列化失败: $e');
      return [];
    }
  }

  /// 格式化时长显示 (MM:SS)
  static String formatDuration(double? seconds) {
    if (seconds == null || seconds <= 0) return '0:00';
    final totalSeconds = seconds.toInt();
    final minutes = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// 检查文件是否为音频文件
  static bool isAudioFile(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac', 'wma'].contains(ext);
  }

  /// 获取音频 MIME 类型
  static String getAudioMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;

    const mimeTypes = {
      'mp3': 'audio/mpeg',
      'm4a': 'audio/x-m4a',
      'wav': 'audio/wav',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',
      'flac': 'audio/flac',
      'wma': 'audio/x-ms-wma',
    };

    return mimeTypes[ext] ?? 'audio/mpeg';
  }

  /// 释放资源
  static Future<void> dispose() async {
    await _player.dispose();
    debugPrint('[AudioProcessor] 资源已释放');
  }
}

/// 音频元数据
class AudioMetadata {
  final String filePath;
  final String fileName;
  final double? duration;
  final List<double>? waveform;
  final int fileSize;
  final String mimeType;

  const AudioMetadata({
    required this.filePath,
    required this.fileName,
    this.duration,
    this.waveform,
    required this.fileSize,
    required this.mimeType,
  });

  String get formattedDuration => AudioProcessor.formatDuration(duration);

  String? get serializedWaveform =>
      waveform != null ? AudioProcessor.serializeWaveform(waveform!) : null;

  @override
  String toString() {
    return 'AudioMetadata(file: $fileName, duration: $formattedDuration, '
        'size: ${(fileSize / 1024).toStringAsFixed(1)}KB, waveform: ${waveform?.length ?? 0}点)';
  }
}

/// 音频处理配置
class AudioProcessorConfig {
  final int waveformSamples;
  final bool generateWaveform;
  final bool extractDuration;

  const AudioProcessorConfig({
    this.waveformSamples = 50,
    this.generateWaveform = true,
    this.extractDuration = true,
  });

  static const AudioProcessorConfig defaultConfig = AudioProcessorConfig();

  static const AudioProcessorConfig simple = AudioProcessorConfig(
    generateWaveform: false,
  );

  static const AudioProcessorConfig detailed = AudioProcessorConfig(
    waveformSamples: 100,
  );
}
