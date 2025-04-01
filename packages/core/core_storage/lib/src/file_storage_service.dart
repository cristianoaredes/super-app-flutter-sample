import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';


abstract class FileStorageService {
  
  Future<void> initialize();

  
  Future<String> saveFile(String fileName, Uint8List data, {String? directory});

  
  Future<Uint8List?> readFile(String fileName, {String? directory});

  
  Future<bool> fileExists(String fileName, {String? directory});

  
  Future<bool> deleteFile(String fileName, {String? directory});

  
  Future<List<String>> listFiles({String? directory});

  
  Future<int> getFileSize(String fileName, {String? directory});

  
  Future<String> getFilePath(String fileName, {String? directory});

  
  Future<String> createDirectory(String directoryName);

  
  Future<bool> directoryExists(String directoryName);

  
  Future<bool> deleteDirectory(String directoryName, {bool recursive = false});
}


class FileStorageServiceImpl implements FileStorageService {
  late String _basePath;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final directory = await getApplicationDocumentsDirectory();
    _basePath = directory.path;

    _initialized = true;
  }

  @override
  Future<String> saveFile(String fileName, Uint8List data,
      {String? directory}) async {
    _ensureInitialized();

    final filePath = await getFilePath(fileName, directory: directory);
    final file = File(filePath);

    
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await file.writeAsBytes(data);
    return filePath;
  }

  @override
  Future<Uint8List?> readFile(String fileName, {String? directory}) async {
    _ensureInitialized();

    final filePath = await getFilePath(fileName, directory: directory);
    final file = File(filePath);

    if (!await file.exists()) {
      return null;
    }

    return file.readAsBytes();
  }

  @override
  Future<bool> fileExists(String fileName, {String? directory}) async {
    _ensureInitialized();

    final filePath = await getFilePath(fileName, directory: directory);
    final file = File(filePath);

    return file.exists();
  }

  @override
  Future<bool> deleteFile(String fileName, {String? directory}) async {
    _ensureInitialized();

    final filePath = await getFilePath(fileName, directory: directory);
    final file = File(filePath);

    if (!await file.exists()) {
      return false;
    }

    await file.delete();
    return true;
  }

  @override
  Future<List<String>> listFiles({String? directory}) async {
    _ensureInitialized();

    final dirPath = directory != null ? '$_basePath/$directory' : _basePath;
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      return [];
    }

    final files = await dir.list().toList();
    return files
        .where((entity) => entity is File)
        .map((entity) => entity.path.split('/').last)
        .toList();
  }

  @override
  Future<int> getFileSize(String fileName, {String? directory}) async {
    _ensureInitialized();

    final filePath = await getFilePath(fileName, directory: directory);
    final file = File(filePath);

    if (!await file.exists()) {
      return 0;
    }

    return file.length();
  }

  @override
  Future<String> getFilePath(String fileName, {String? directory}) async {
    _ensureInitialized();

    if (directory != null) {
      return '$_basePath/$directory/$fileName';
    }

    return '$_basePath/$fileName';
  }

  @override
  Future<String> createDirectory(String directoryName) async {
    _ensureInitialized();

    final dirPath = '$_basePath/$directoryName';
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dirPath;
  }

  @override
  Future<bool> directoryExists(String directoryName) async {
    _ensureInitialized();

    final dirPath = '$_basePath/$directoryName';
    final dir = Directory(dirPath);

    return dir.exists();
  }

  @override
  Future<bool> deleteDirectory(String directoryName,
      {bool recursive = false}) async {
    _ensureInitialized();

    final dirPath = '$_basePath/$directoryName';
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      return false;
    }

    await dir.delete(recursive: recursive);
    return true;
  }

  
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
          'FileStorageService was not initialized. Call initialize() first.');
    }
  }
}
