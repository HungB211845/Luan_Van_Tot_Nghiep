// Stub file for web compilation - provides empty implementations for packages not available on web
import 'dart:io';

// File saver stubs
class FileSaver {
  static FileSaver get instance => FileSaver();
  Future<String?> saveFile({required String name, required List<int> bytes, required String ext, required MimeType mimeType}) async {
    throw UnsupportedError('FileSaver not supported on web');
  }
}

enum MimeType { csv }

// Share plus stubs
class Share {
  static Future<ShareResult> shareXFiles(List<XFile> files, {String? subject, String? text}) async {
    throw UnsupportedError('Share not supported on web');
  }
}

class XFile {
  final String path;
  XFile(this.path);
}

class ShareResult {
  final ShareResultStatus status;
  ShareResult(this.status);
}

enum ShareResultStatus { success }

// Path provider stubs
Future<Directory> getTemporaryDirectory() async {
  throw UnsupportedError('Path provider not supported on web');
}

class File {
  File(String path);
  Future<void> writeAsBytes(List<int> bytes) async {
    throw UnsupportedError('File operations not supported on web');
  }
  Future<void> delete() async {
    throw UnsupportedError('File operations not supported on web');
  }
}