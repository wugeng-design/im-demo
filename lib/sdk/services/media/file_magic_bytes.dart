/// 文件魔数（Magic Bytes）定义
///
/// 用于通过文件头部字节识别真实文件类型
library;

/// 文件魔数检测器
///
/// 通过检查文件头部的魔数（Magic Bytes）来识别文件的真实类型
class FileMagicBytes {
  /// Magic Bytes 签名映射表
  ///
  /// Key: MIME 类型
  /// Value: 文件头部字节签名
  static const Map<String, List<int>> signatures = {
    // 图片格式
    'image/jpeg': [0xFF, 0xD8, 0xFF],
    'image/png': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    'image/gif': [0x47, 0x49, 0x46, 0x38],
    'image/webp': [0x52, 0x49, 0x46, 0x46], // RIFF
    'image/bmp': [0x42, 0x4D],
    // HEIC/HEIF 格式使用 ftyp box，需要特殊处理（见 detectMimeType）

    // 文档格式
    'application/pdf': [0x25, 0x50, 0x44, 0x46],
    'application/zip': [0x50, 0x4B, 0x03, 0x04],
    'application/x-rar-compressed': [0x52, 0x61, 0x72, 0x21],
    'application/x-7z-compressed': [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C],

    // Office 文档（ZIP 格式）
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': [0x50, 0x4B, 0x03, 0x04],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': [0x50, 0x4B, 0x03, 0x04],
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': [0x50, 0x4B, 0x03, 0x04],

    // 旧版 Office 文档（OLE2 格式）
    'application/msword': [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
    'application/vnd.ms-excel': [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
    'application/vnd.ms-powerpoint': [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],

    // 音频格式
    'audio/mpeg': [0xFF, 0xFB],
    'audio/wav': [0x52, 0x49, 0x46, 0x46],

    // 视频格式
    'video/x-msvideo': [0x52, 0x49, 0x46, 0x46],
    'video/x-matroska': [0x1A, 0x45, 0xDF, 0xA3],

    // 压缩格式
    'application/gzip': [0x1F, 0x8B],
  };

  /// 从字节数据检测 MIME 类型
  static String? detectMimeType(List<int> bytes) {
    if (bytes.isEmpty) return null;

    // 特殊处理：ftyp box 格式（MP4/MOV/M4A/HEIC/HEIF）
    // ftyp box 结构: [size(4)] [ftyp(4)] [brand(4)] [version(4)] [compatible brands...]
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 && bytes[5] == 0x74 &&
        bytes[6] == 0x79 && bytes[7] == 0x70) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12));

      // HEIC/HEIF 格式（iOS 拍照默认格式）
      if (brand == 'heic' || brand == 'heix' || brand == 'hevc' ||
          brand == 'hevx' || brand == 'heim' || brand == 'heis' ||
          brand == 'mif1' || brand == 'msf1') {
        return 'image/heic';
      }
      // AVIF 格式
      if (brand == 'avif' || brand == 'avis') {
        return 'image/avif';
      }
      // 视频格式
      if (brand.startsWith('isom') || brand.startsWith('mp4') || brand.startsWith('M4V')) {
        return 'video/mp4';
      } else if (brand.startsWith('qt')) {
        return 'video/quicktime';
      } else if (brand.startsWith('M4A')) {
        return 'audio/x-m4a';
      }
    }

    // RIFF 容器格式（WebP, WAV, AVI）
    if (bytes.length >= 12 && _matchesSignature(bytes, [0x52, 0x49, 0x46, 0x46])) {
      if (bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
        return 'image/webp';
      }
      if (bytes[8] == 0x57 && bytes[9] == 0x41 && bytes[10] == 0x56 && bytes[11] == 0x45) {
        return 'audio/wav';
      }
      if (bytes[8] == 0x41 && bytes[9] == 0x56 && bytes[10] == 0x49 && bytes[11] == 0x20) {
        return 'video/x-msvideo';
      }
    }

    // MP3 ID3 标签
    if (bytes.length >= 3 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
      return 'audio/mpeg';
    }

    // 通用签名匹配
    for (final entry in signatures.entries) {
      if (_matchesSignature(bytes, entry.value)) {
        return entry.key;
      }
    }

    return null;
  }

  /// 检查字节是否匹配签名
  static bool _matchesSignature(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (int i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// 验证字节内容是否与声明的 MIME 类型匹配
  static bool validateBytes(List<int> bytes, String expectedMime) {
    final signature = signatures[expectedMime];
    if (signature == null) return true; // 未知类型跳过
    if (bytes.length < signature.length) return false;

    for (int i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// 扩展名到 MIME 类型映射
  static const Map<String, List<String>> extensionToMime = {
    'jpg': ['image/jpeg'],
    'jpeg': ['image/jpeg'],
    'png': ['image/png'],
    'gif': ['image/gif'],
    'webp': ['image/webp'],
    'bmp': ['image/bmp'],
    'heic': ['image/heic', 'image/heif'],
    'heif': ['image/heif', 'image/heic'],
    'avif': ['image/avif'],
    'pdf': ['application/pdf'],
    'doc': ['application/msword'],
    'docx': ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    'xls': ['application/vnd.ms-excel'],
    'xlsx': ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    'ppt': ['application/vnd.ms-powerpoint'],
    'pptx': ['application/vnd.openxmlformats-officedocument.presentationml.presentation'],
    'zip': ['application/zip'],
    'rar': ['application/x-rar-compressed'],
    '7z': ['application/x-7z-compressed'],
    'mp3': ['audio/mpeg'],
    'm4a': ['audio/x-m4a', 'audio/mp4'],
    'wav': ['audio/wav', 'audio/x-wav'],
    'mp4': ['video/mp4'],
    'mov': ['video/quicktime'],
    'avi': ['video/x-msvideo'],
    'mkv': ['video/x-matroska'],
    'txt': ['text/plain'],
  };

  /// 根据文件名获取 MIME 类型
  static String getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    final mimes = extensionToMime[ext];
    if (mimes != null && mimes.isNotEmpty) {
      return mimes.first;
    }

    const extraMimes = {
      'html': 'text/html',
      'css': 'text/css',
      'js': 'text/javascript',
      'json': 'application/json',
      'xml': 'application/xml',
      'csv': 'text/csv',
      'webm': 'video/webm',
      'heic': 'image/heic',
    };

    return extraMimes[ext] ?? 'application/octet-stream';
  }
}
