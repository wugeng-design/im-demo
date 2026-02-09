import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:whixp/whixp.dart';
import 'package:xml/xml.dart' as xml;

import '../media_upload_service.dart';
import '../media/video_processor.dart';
import '../../models/media.dart';

/// XEP-0363 HTTP File Upload 服务
///
/// 实现正确的 XEP-0363 流程：
/// 1. 通过 XMPP IQ 请求上传 slot
/// 2. 服务器返回 PUT URL 和 GET URL
/// 3. 客户端 PUT 上传到服务器
/// 4. 使用 GET URL 作为文件访问地址
class Xep0363UploadService implements MediaUploadService {
  /// XMPP 服务器域名
  final String domain;

  /// Whixp 实例（用于发送 IQ）
  final Whixp whixp;

  final Map<String, UploadTask> _tasks = {};
  final _taskController = StreamController<UploadTask>.broadcast();

  /// XEP-0363 命名空间
  static const String namespace = 'urn:xmpp:http:upload:0';

  Xep0363UploadService({
    required this.domain,
    required this.whixp,
  });

  @override
  Future<MediaUploadResult> uploadImage({
    required String messageId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    return _uploadFile(
      messageId: messageId,
      file: file,
      type: MediaType.image,
      mimeType: _getMimeType(file.path),
      onProgress: onProgress,
    );
  }

  @override
  Future<MediaUploadResult> uploadVideo({
    required String messageId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    String? thumbnailUrl;

    // 1. 生成视频缩略图 (0-10%)
    onProgress?.call(0.05);
    debugPrint('[XEP-0363] 生成视频缩略图: $messageId');
    final thumbnailData = await VideoProcessor.generateThumbnail(
      file.path,
      maxWidth: 320,
    );
    onProgress?.call(0.10);

    // 2. 上传缩略图（如果生成成功）(10-20%)
    if (thumbnailData != null) {
      debugPrint('[XEP-0363] 上传视频缩略图: $messageId');
      thumbnailUrl = await _uploadThumbnail(
        messageId: messageId,
        thumbnailData: thumbnailData,
      );
      if (thumbnailUrl != null) {
        debugPrint('[XEP-0363] 缩略图上传成功: $thumbnailUrl');
      } else {
        debugPrint('[XEP-0363] 缩略图上传失败');
      }
    } else {
      debugPrint('[XEP-0363] 视频缩略图生成失败，将不包含缩略图');
    }
    onProgress?.call(0.20);

    // 3. 上传视频文件 (20-100%)
    final result = await _uploadFile(
      messageId: messageId,
      file: file,
      type: MediaType.video,
      mimeType: _getMimeType(file.path),
      onProgress: onProgress != null
          ? (p) => onProgress(0.20 + p * 0.80)
          : null,
    );

    // 4. 返回结果（包含缩略图 URL）
    if (result.success) {
      return MediaUploadResult.success(
        remoteUrl: result.remoteUrl!,
        thumbnailUrl: thumbnailUrl,
      );
    }
    return result;
  }

  /// 上传缩略图
  Future<String?> _uploadThumbnail({
    required String messageId,
    required Uint8List thumbnailData,
  }) async {
    try {
      final fileName = 'thumb_$messageId.jpg';
      final fileSize = thumbnailData.length;

      // 请求上传 slot
      final slot = await _requestSlot(
        fileName: fileName,
        fileSize: fileSize,
        contentType: 'image/jpeg',
      );
      if (slot == null) {
        return null;
      }

      // 上传缩略图
      final response = await http.put(
        Uri.parse(slot.putUrl),
        headers: {
          'Content-Type': 'image/jpeg',
          'Content-Length': fileSize.toString(),
          ...slot.headers,
        },
        body: thumbnailData,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return slot.getUrl;
      }
      return null;
    } catch (e) {
      debugPrint('[XEP-0363] 缩略图上传异常: $e');
      return null;
    }
  }

  @override
  Future<MediaUploadResult> uploadFile({
    required String messageId,
    required File file,
    required String mimeType,
    UploadProgressCallback? onProgress,
  }) async {
    return _uploadFile(
      messageId: messageId,
      file: file,
      type: MediaType.file,
      mimeType: mimeType,
      onProgress: onProgress,
    );
  }

  Future<MediaUploadResult> _uploadFile({
    required String messageId,
    required File file,
    required MediaType type,
    required String mimeType,
    UploadProgressCallback? onProgress,
  }) async {
    final fileName = file.path.split('/').last;
    final fileSize = await file.length();

    // 创建上传任务
    final task = UploadTask(
      id: messageId,
      messageId: messageId,
      media: MediaMetadata(
        type: type,
        localFilePath: file.path,
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
      ),
      status: UploadStatus.uploading,
    );
    _tasks[messageId] = task;
    _taskController.add(task);

    try {
      // 1. 请求上传 slot
      print('[XEP-0363] Requesting upload slot for $fileName ($fileSize bytes)');
      final slot = await _requestSlot(
        fileName: fileName,
        fileSize: fileSize,
        contentType: mimeType,
      );

      if (slot == null) {
        throw Exception('服务器未返回上传 slot');
      }

      print('[XEP-0363] Got slot - PUT: ${slot.putUrl}, GET: ${slot.getUrl}');

      // 2. 上传文件到 PUT URL
      onProgress?.call(0.1);

      final fileBytes = await file.readAsBytes();

      final request = http.Request('PUT', Uri.parse(slot.putUrl));
      request.headers['Content-Type'] = mimeType;
      request.headers['Content-Length'] = fileSize.toString();

      // 添加服务器要求的额外头部
      for (final header in slot.headers.entries) {
        request.headers[header.key] = header.value;
      }

      request.bodyBytes = fileBytes;

      onProgress?.call(0.5);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('[XEP-0363] Upload response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 上传成功，使用 GET URL 作为文件地址
        _tasks[messageId] = task.copyWith(
          status: UploadStatus.completed,
          progress: 1.0,
        );
        _taskController.add(_tasks[messageId]!);

        onProgress?.call(1.0);

        return MediaUploadResult.success(remoteUrl: slot.getUrl);
      } else {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('[XEP-0363] Error: $e');

      _tasks[messageId] = task.copyWith(
        status: UploadStatus.failed,
      );
      _taskController.add(_tasks[messageId]!);

      return MediaUploadResult.failure('上传失败: $e');
    }
  }

  /// 请求上传 slot
  ///
  /// 发送 IQ stanza:
  /// ```xml
  /// <iq type='get' to='upload.example.org' id='step_03'>
  ///   <request xmlns='urn:xmpp:http:upload:0'
  ///     filename='my_juliet.png'
  ///     size='23456'
  ///     content-type='image/jpeg' />
  /// </iq>
  /// ```
  Future<UploadSlot?> _requestSlot({
    required String fileName,
    required int fileSize,
    required String contentType,
  }) async {
    final completer = Completer<UploadSlot?>();

    try {
      // 生成唯一 ID
      final iqId = 'upload_${DateTime.now().millisecondsSinceEpoch}';

      // 直接构建 XML 字符串（避免 namespace 解析问题）
      // 注意: 需要对特殊字符进行 XML 转义
      final escapedFileName = _xmlEscape(fileName);
      // from 属性可省略，服务器会自动填充
      final iqXml = '<iq type="get" to="upload.$domain" id="$iqId">'
          '<request xmlns="$namespace" '
          'filename="$escapedFileName" '
          'size="$fileSize" '
          'content-type="$contentType"/>'
          '</iq>';

      print('[XEP-0363] Sending raw IQ: $iqXml');

      // 使用 Transport 发送原始 XML 并等待响应
      final response = await _sendRawIqAndWait(iqId, iqXml, timeout: 30);

      if (response == null) {
        print('[XEP-0363] Request timed out or failed');
        return null;
      }

      print('[XEP-0363] Response: $response');

      // 解析响应 XML
      final slot = _parseSlotXml(response);
      completer.complete(slot);
    } catch (e) {
      print('[XEP-0363] Error requesting slot: $e');
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  /// XML 转义特殊字符
  String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// 发送原始 IQ 并等待响应
  Future<String?> _sendRawIqAndWait(String iqId, String iqXml, {int timeout = 30}) async {
    final completer = Completer<String?>();

    // 注册响应处理器
    void handleResponse(dynamic event) {
      if (event is IQ && event.id == iqId) {
        if (!completer.isCompleted) {
          completer.complete(event.toXML().toXmlString());
        }
      }
    }

    // 添加 IQ 响应监听器
    whixp.addEventHandler<IQ>('iq_response_$iqId', handleResponse);

    // 发送原始 XML
    // 使用内部方法直接发送
    try {
      // 构建 IQ 对象用于发送
      final iq = IQ.fromString(iqXml);

      final response = await iq.send(
        timeout: timeout,
        timeoutCallback: () {
          print('[XEP-0363] Request timed out');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
        failureCallback: (error) {
          print('[XEP-0363] Request failed: ${error.text}');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );

      if (!completer.isCompleted) {
        completer.complete(response.toXML().toXmlString());
      }
    } catch (e) {
      print('[XEP-0363] Send error: $e');
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return completer.future;
  }

  /// 解析 slot 响应 XML 字符串
  UploadSlot? _parseSlotXml(String responseXml) {
    try {
      final doc = xml.XmlDocument.parse(responseXml);
      final iqElement = doc.rootElement;

      if (iqElement.getAttribute('type') != 'result') {
        print('[XEP-0363] Response type is not result');
        return null;
      }

      // 查找 slot 元素
      xml.XmlElement? slotElement;
      for (final child in iqElement.children.whereType<xml.XmlElement>()) {
        if (child.localName == 'slot') {
          slotElement = child;
          break;
        }
      }

      if (slotElement == null) {
        print('[XEP-0363] No slot element found');
        return null;
      }

      String? putUrl;
      String? getUrl;
      final headers = <String, String>{};

      for (final child in slotElement.children.whereType<xml.XmlElement>()) {
        if (child.localName == 'put') {
          putUrl = child.getAttribute('url');
          // 解析额外的 header
          for (final header in child.children.whereType<xml.XmlElement>()) {
            if (header.localName == 'header') {
              final name = header.getAttribute('name');
              final value = header.innerText;
              if (name != null && value.isNotEmpty) {
                headers[name] = value;
              }
            }
          }
        } else if (child.localName == 'get') {
          getUrl = child.getAttribute('url');
        }
      }

      if (putUrl == null || getUrl == null) {
        print('[XEP-0363] Missing PUT or GET URL');
        return null;
      }

      return UploadSlot(
        putUrl: putUrl,
        getUrl: getUrl,
        headers: headers,
      );
    } catch (e) {
      print('[XEP-0363] Error parsing slot XML: $e');
      return null;
    }
  }

  @override
  bool cancelUpload(String messageId) {
    final task = _tasks[messageId];
    if (task != null && task.status == UploadStatus.uploading) {
      _tasks[messageId] = task.copyWith(status: UploadStatus.cancelled);
      _taskController.add(_tasks[messageId]!);
      return true;
    }
    return false;
  }

  @override
  Future<MediaUploadResult> retryUpload(String messageId) async {
    final task = _tasks[messageId];
    if (task == null) {
      return MediaUploadResult.failure('任务不存在');
    }

    final file = File(task.media.localFilePath!);
    return _uploadFile(
      messageId: messageId,
      file: file,
      type: task.media.type,
      mimeType: task.media.mimeType ?? 'application/octet-stream',
    );
  }

  @override
  UploadTask? getUploadTask(String messageId) => _tasks[messageId];

  @override
  Stream<UploadTask> get uploadTaskStream => _taskController.stream;

  String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

  void dispose() {
    _taskController.close();
  }
}

/// 上传 slot 信息
class UploadSlot {
  /// PUT URL（用于上传）
  final String putUrl;

  /// GET URL（用于下载/访问）
  final String getUrl;

  /// 额外的 HTTP 头部（如授权信息）
  final Map<String, String> headers;

  UploadSlot({
    required this.putUrl,
    required this.getUrl,
    this.headers = const {},
  });
}
