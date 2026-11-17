import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Service for local file operations (images, logs, etc.).
class FileService {
  FileService._internal();

  static final FileService _instance = FileService._internal();

  factory FileService() => _instance;

  Future<Directory> getAppSupportDir() async {
    return await getApplicationSupportDirectory();
  }

  Future<Directory> getProductImagesFolder() async {
    final appDir = await getApplicationSupportDirectory();
    final imagesFolder = Directory('${appDir.path}/images/products');
    if (!await imagesFolder.exists()) {
      await imagesFolder.create(recursive: true);
    }
    return imagesFolder;
  }

  Future<Directory> getLogsFolder() async {
    final appDir = await getApplicationSupportDirectory();
    final logsFolder = Directory('${appDir.path}/logs');
    if (!await logsFolder.exists()) {
      await logsFolder.create(recursive: true);
    }
    return logsFolder;
  }

  /// Save a product image locally and return the path.
  Future<String> saveProductImage(String sourcePath, String fileName) async {
    final imagesFolder = await getProductImagesFolder();
    final destination = File(p.join(imagesFolder.path, fileName));
    await File(sourcePath).copy(destination.path);
    return destination.path;
  }

  /// Initialize all required directories.
  Future<void> initializeDirectories() async {
    await getProductImagesFolder();
    await getLogsFolder();

    final appDir = await getApplicationSupportDirectory();
    final dbFolder = Directory('${appDir.path}/database');
    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }
  }
}
