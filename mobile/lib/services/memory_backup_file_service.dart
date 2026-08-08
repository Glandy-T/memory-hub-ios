import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';

const int _maximumBackupBytes = 25 * 1024 * 1024;

class BackupFileSelection {
  const BackupFileSelection({required this.name, required this.contents});

  final String name;
  final String contents;
}

abstract class MemoryBackupFileService {
  const MemoryBackupFileService();

  Future<bool> save(String contents);

  Future<BackupFileSelection?> pick();
}

class SystemMemoryBackupFileService extends MemoryBackupFileService {
  const SystemMemoryBackupFileService();

  @override
  Future<bool> save(String contents) async {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final result = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        data: Uint8List.fromList(utf8.encode(contents)),
        fileName: 'memory-hub-$date.json',
        mimeTypesFilter: const ['application/json'],
      ),
    );
    return result != null;
  }

  @override
  Future<BackupFileSelection?> pick() async {
    final path = await FlutterFileDialog.pickFile(
      params: const OpenFileDialogParams(
        dialogType: OpenFileDialogType.document,
        allowedUtiTypes: ['public.json', 'public.text'],
        fileExtensionsFilter: ['json'],
        mimeTypesFilter: ['application/json', 'text/json', 'text/plain'],
        copyFileToCacheDir: true,
      ),
    );
    if (path == null) return null;

    final file = File(path);
    final length = await file.length();
    if (length > _maximumBackupBytes) {
      throw const FormatException('备份文件超过 25 MB，已停止读取');
    }
    return BackupFileSelection(
      name: _fileName(path),
      contents: await file.readAsString(),
    );
  }
}

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final name = normalized.split('/').last.trim();
  return name.isEmpty ? '所选备份文件' : name;
}
