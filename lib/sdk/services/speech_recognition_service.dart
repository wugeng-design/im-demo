/// 语音识别服务
///
/// 功能：
/// - 初始化语音识别引擎
/// - 支持中英文语言切换
/// - 处理语音转文字
/// - 提供状态管理和错误处理
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 语音识别状态
enum SpeechRecognitionState {
  /// 未初始化
  idle,

  /// 准备中
  preparing,

  /// 正在识别
  listening,

  /// 识别完成
  completed,

  /// 错误
  error,
}

/// 语音识别结果
class SpeechRecognitionResult {
  final String text;
  final double confidence;
  final bool isFinal;

  const SpeechRecognitionResult({
    required this.text,
    required this.confidence,
    this.isFinal = false,
  });
}

/// 语音识别服务
class SpeechRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  String _currentLocale = 'zh_CN';
  StreamController<SpeechRecognitionState>? _stateController;
  StreamController<SpeechRecognitionResult>? _resultController;
  SpeechRecognitionState _state = SpeechRecognitionState.idle;

  /// 语音识别状态流
  Stream<SpeechRecognitionState> get stateStream =>
      _stateController?.stream ?? const Stream.empty();

  /// 语音识别结果流
  Stream<SpeechRecognitionResult> get resultStream =>
      _resultController?.stream ?? const Stream.empty();

  /// 当前状态
  SpeechRecognitionState get state => _state;

  /// 当前语言
  String get currentLocale => _currentLocale;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 检查麦克风权限
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    debugPrint('[SpeechRecognition] 麦克风权限状态: $status');
    return status.isGranted;
  }

  /// 请求麦克风权限
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    debugPrint('[SpeechRecognition] 请求麦克风权限结果: $status');
    return status.isGranted;
  }

  /// 检查并请求权限
  Future<bool> ensurePermission() async {
    final hasPermission = await checkPermission();
    if (hasPermission) return true;
    return await requestPermission();
  }

  /// 初始化
  void _ensureInitialized() {
    if (_stateController == null) {
      _stateController = StreamController<SpeechRecognitionState>.broadcast();
    }
    if (_resultController == null) {
      _resultController = StreamController<SpeechRecognitionResult>.broadcast();
    }
  }

  /// 初始化语音识别引擎
  Future<bool> initialize() async {
    _ensureInitialized();

    if (_isInitialized) {
      return true;
    }

    _updateState(SpeechRecognitionState.preparing);

    try {
      // 检查并请求麦克风权限
      final hasPermission = await ensurePermission();
      if (!hasPermission) {
        _updateState(SpeechRecognitionState.error);
        debugPrint('[SpeechRecognition] 没有麦克风权限');
        return false;
      }

      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[SpeechRecognition] 状态变化: $status');
          switch (status) {
            case 'listening':
              _updateState(SpeechRecognitionState.listening);
              break;
            case 'notListening':
              _updateState(SpeechRecognitionState.completed);
              break;
            case 'done':
              _updateState(SpeechRecognitionState.completed);
              break;
            case 'error':
              _updateState(SpeechRecognitionState.error);
              break;
            default:
              break;
          }
        },
        onError: (error) {
          debugPrint('[SpeechRecognition] 错误: $error');
          _updateState(SpeechRecognitionState.error);
        },
      );

      _isInitialized = available;
      if (available) {
        _updateState(SpeechRecognitionState.idle);
        debugPrint('[SpeechRecognition] 初始化成功');
      } else {
        _updateState(SpeechRecognitionState.error);
        debugPrint('[SpeechRecognition] 初始化失败');
      }

      return available;
    } catch (e) {
      _updateState(SpeechRecognitionState.error);
      debugPrint('[SpeechRecognition] 初始化异常: $e');
      return false;
    }
  }

  /// 设置语言
  void setLocale(String locale) {
    _currentLocale = locale;
    debugPrint('[SpeechRecognition] 设置语言: $locale');
  }

  /// 开始语音识别
  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return false;
      }
    }

    if (_state == SpeechRecognitionState.listening) {
      return true;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          final recognitionResult = SpeechRecognitionResult(
            text: result.recognizedWords,
            confidence: result.confidence,
            isFinal: result.finalResult,
          );
          _resultController?.add(recognitionResult);
          debugPrint('[SpeechRecognition] 识别结果: ${result.recognizedWords} (${result.confidence})');
        },
        localeId: _currentLocale,
        cancelOnError: true,
        partialResults: true,
      );

      _updateState(SpeechRecognitionState.listening);
      debugPrint('[SpeechRecognition] 开始识别');
      return true;
    } catch (e) {
      _updateState(SpeechRecognitionState.error);
      debugPrint('[SpeechRecognition] 开始识别失败: $e');
      return false;
    }
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    if (_state != SpeechRecognitionState.listening) {
      return;
    }

    try {
      await _speech.stop();
      _updateState(SpeechRecognitionState.completed);
      debugPrint('[SpeechRecognition] 停止识别');
    } catch (e) {
      debugPrint('[SpeechRecognition] 停止识别失败: $e');
    }
  }

  /// 取消语音识别
  Future<void> cancelListening() async {
    if (_state != SpeechRecognitionState.listening) {
      return;
    }

    try {
      await _speech.cancel();
      _updateState(SpeechRecognitionState.idle);
      debugPrint('[SpeechRecognition] 取消识别');
    } catch (e) {
      debugPrint('[SpeechRecognition] 取消识别失败: $e');
    }
  }

  /// 从音频文件进行识别（需要平台支持）
  Future<String?> recognizeFromFile(String filePath) async {
    // 注意：speech_to_text 库主要支持实时录音识别
    // 对于文件识别，这里实现一个模拟版本，实际应用中可能需要使用其他服务或API
    debugPrint('[SpeechRecognition] 从文件识别: $filePath');
    
    // 模拟识别过程，返回示例文本
    // 实际应用中，这里应该调用真实的语音识别API
    await Future.delayed(const Duration(seconds: 1));
    
    // 示例识别结果
    final sampleTexts = [
      '你好，这是一段语音识别的示例文本',
      '今天天气真好，适合出去走走',
      '语音转文字功能已经实现',
      '你好，请问有什么可以帮助你的吗',
      '这个功能真的很方便',
    ];
    
    // 随机选择一个示例文本作为识别结果
    final random = Random();
    final result = sampleTexts[random.nextInt(sampleTexts.length)];
    
    debugPrint('[SpeechRecognition] 文件识别结果: $result');
    return result;
  }

  /// 获取可用的语言列表
  Future<List<stt.LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final locales = await _speech.locales();
      debugPrint('[SpeechRecognition] 可用语言: ${locales.map((l) => l.name).toList()}');
      return locales;
    } catch (e) {
      debugPrint('[SpeechRecognition] 获取语言列表失败: $e');
      return [];
    }
  }

  /// 更新状态
  void _updateState(SpeechRecognitionState newState) {
    _state = newState;
    _stateController?.add(newState);
  }

  /// 释放资源
  void dispose() {
    _speech.cancel();
    _stateController?.close();
    _resultController?.close();
    debugPrint('[SpeechRecognition] 资源已释放');
  }
}

/// 全局语音识别服务单例
final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>((ref) {
  final service = SpeechRecognitionService();
  ref.onDispose(() => service.dispose());
  return service;
});
