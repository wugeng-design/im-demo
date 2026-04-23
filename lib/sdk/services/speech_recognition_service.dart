/// 语音识别服务
///
/// 功能：
/// - 初始化语音识别引擎
/// - 支持中英文语言切换
/// - 处理语音转文字
/// - 提供状态管理和错误处理
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // 对于文件识别，可能需要使用其他服务或API
    // 这里作为预留接口
    debugPrint('[SpeechRecognition] 从文件识别: $filePath');
    return null;
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
