library;

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TencentAsrConfig {
  final String secretId;
  final String secretKey;
  final String appId;
  final String region;

  const TencentAsrConfig({
    required this.secretId,
    required this.secretKey,
    required this.appId,
    this.region = 'ap-guangzhou',
  });

  TencentAsrConfig copyWith({
    String? secretId,
    String? secretKey,
    String? appId,
    String? region,
  }) {
    return TencentAsrConfig(
      secretId: secretId ?? this.secretId,
      secretKey: secretKey ?? this.secretKey,
      appId: appId ?? this.appId,
      region: region ?? this.region,
    );
  }
}

class TencentAsrResult {
  final bool success;
  final String? text;
  final String? errorMessage;
  final double? confidence;

  const TencentAsrResult({
    required this.success,
    this.text,
    this.errorMessage,
    this.confidence,
  });

  factory TencentAsrResult.success(String text, {double? confidence}) {
    return TencentAsrResult(
      success: true,
      text: text,
      confidence: confidence,
    );
  }

  factory TencentAsrResult.failure(String errorMessage) {
    return TencentAsrResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

class TencentAsrService {
  TencentAsrConfig? _config;
  String? _accessToken;
  DateTime? _tokenExpiry;

  static const String _tokenUrl = 'https://iam.myqcloud.com/tokens/v1.0.0';
  static const String _asrUrl = 'https://asr.myqcloud.com/asr/v1';
  static const String _cosUrl = 'https://cos.avator.cloud';

  void configure(TencentAsrConfig config) {
    _config = config;
    debugPrint('[TencentAsr] Configured with AppId: ${config.appId}, Region: ${config.region}');
  }

  bool get isConfigured => _config != null;

  Future<String> _getAccessToken() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    if (_config == null) {
      throw Exception('Tencent ASR 未配置，请先调用 configure() 配置 SecretId 和 SecretKey');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signatureOrigin = 'a=${_config!.secretId}&b=${_config!.appId}&c=$timestamp';
    final signatureBytes = Hmac(sha1, utf8.encode(_config!.secretKey)).convert(utf8.encode(signatureOrigin));
    final signature = base64Encode(signatureBytes.bytes);

    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'a': _config!.secretId,
          'b': _config!.appId,
          'c': timestamp,
          'signature': signature,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['token'];
        _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
        debugPrint('[TencentAsr] Access token obtained successfully');
        return _accessToken!;
      } else {
        throw Exception('获取访问令牌失败: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[TencentAsr] Failed to get access token: $e');
      rethrow;
    }
  }

  Future<String> _uploadToCos(String filePath) async {
    if (_config == null) {
      throw Exception('Tencent ASR 未配置');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('音频文件不存在: $filePath');
    }

    final fileName = filePath.split('/').last;
    final fileSize = await file.length();
    final fileContent = await file.readAsBytes();

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signatureOrigin = 'a=${_config!.secretId}&b=${_config!.appId}&c=$timestamp';
    final signatureBytes = Hmac(sha1, utf8.encode(_config!.secretKey)).convert(utf8.encode(signatureOrigin));
    final signature = base64Encode(signatureBytes.bytes);

    final uploadUrl = '$_cosUrl/${_config!.appId}/$fileName';

    try {
      final response = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': 'audio/mpeg',
          'Content-Length': fileSize.toString(),
          'x-cos-security-token': signature,
          'x-cos-appid': _config!.appId,
        },
        body: fileContent,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[TencentAsr] File uploaded to COS: ${data['data']['url'] ?? uploadUrl}');
        return data['data']['url'] ?? uploadUrl;
      } else {
        throw Exception('上传文件到COS失败: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[TencentAsr] Failed to upload to COS: $e');
      rethrow;
    }
  }

  Future<TencentAsrResult> transcribe(String filePath, {
    String language = 'zh',
    int sampleRate = 16000,
  }) async {
    if (_config == null) {
      debugPrint('[TencentAsr] Using mock transcription (service not configured)');
      return _mockTranscribe(filePath);
    }

    try {
      debugPrint('[TencentAsr] Starting transcription for: $filePath');

      final token = await _getAccessToken();
      final cosUrl = await _uploadToCos(filePath);

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signatureOrigin = 'a=${_config!.secretId}&b=${_config!.appId}&c=$timestamp';
      final signatureBytes = Hmac(sha1, utf8.encode(_config!.secretKey)).convert(utf8.encode(signatureOrigin));
      final signature = base64Encode(signatureBytes.bytes);

      final response = await http.post(
        Uri.parse('$_asrUrl/${_config!.appId}?sub_service_type=1&engine_model_type=16k_0&hotword_id=&result_type=1&token=$token&timestamp=$timestamp&expired=$timestamp&signature=$signature'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audio_url': cosUrl,
          'source': 0,
          'language': language,
          'sample_rate': sampleRate,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[TencentAsr] Response: $data');

        if (data['code'] == 0 && data['data'] != null) {
          final result = data['data'];
          final text = result['text'] as String?;
          final confidence = result['confidence'] as double?;

          if (text != null && text.isNotEmpty) {
            debugPrint('[TencentAsr] Transcription successful: $text');
            return TencentAsrResult.success(text, confidence: confidence);
          } else {
            debugPrint('[TencentAsr] No text recognized');
            return TencentAsrResult.failure('未能识别到文字');
          }
        } else {
          final errorMsg = data['message'] ?? '识别失败';
          debugPrint('[TencentAsr] Transcription failed: $errorMsg');
          return TencentAsrResult.failure(errorMsg);
        }
      } else {
        final errorMsg = 'HTTP ${response.statusCode}: ${response.body}';
        debugPrint('[TencentAsr] Transcription request failed: $errorMsg');
        return TencentAsrResult.failure(errorMsg);
      }
    } catch (e) {
      debugPrint('[TencentAsr] Transcription error: $e');
      return TencentAsrResult.failure(e.toString());
    }
  }

  Future<TencentAsrResult> _mockTranscribe(String filePath) async {
    debugPrint('[TencentAsr] Running mock transcription for: $filePath');

    final file = File(filePath);
    if (await file.exists()) {
      final fileSize = await file.length();
      debugPrint('[TencentAsr] Mock file size: $fileSize bytes');
    }

    await Future.delayed(const Duration(seconds: 1));

    final mockTexts = [
      '您好，请问有什么可以帮助您的吗？',
      '这是一段语音转文字的测试内容。',
      '今天天气真不错，适合出去走走。',
      '收到您的消息了，我会尽快处理。',
      '好的，我已经明白了。',
    ];

    final index = filePath.hashCode % mockTexts.length;
    final result = mockTexts[index.abs()];

    debugPrint('[TencentAsr] Mock transcription result: $result');
    return TencentAsrResult.success(result, confidence: 0.95);
  }

  void dispose() {
    _accessToken = null;
    _tokenExpiry = null;
    debugPrint('[TencentAsr] Service disposed');
  }
}

final tencentAsrServiceProvider = Provider<TencentAsrService>((ref) {
  final service = TencentAsrService();
  ref.onDispose(() => service.dispose());
  return service;
});

final tencentAsrConfigProvider = StateProvider<TencentAsrConfig?>((ref) => null);
