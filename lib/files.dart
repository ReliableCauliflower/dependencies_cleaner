import 'dart:io';

import 'package:path/path.dart';
import 'models/pubspec_file_data.dart';

/// Get the project pubspec file(s), its contents and a list of related dart
/// files. The current algorithm assumes that pubspec.yaml files do not exist in
/// the same folder with dart files
List<PubspecFileData> pubspecFiles({
  required String currentPath,
  required List<String> additionalPaths,
}) {
  final basePubspecPath = getPubspecPath(currentPath);
  final packagesDartFiles = <String, List<File>>{
    basePubspecPath: _getPackageBaseFiles(currentPath),
  };

  void addFile(String pubspecPath, File file) {
    if (packagesDartFiles[pubspecPath] == null) {
      packagesDartFiles[pubspecPath] = [file];
    } else {
      packagesDartFiles[pubspecPath]!.add(file);
    }
  }

  void handleAdditionalPaths({required String packagePath}) {
    final pubspecPath = getPubspecPath(packagePath);

    void checkDir(String dirPath) {
      final contents = _readDir(
        dirPath,
        recursive: false,
        withDirs: true,
      )..sort((a, b) {
          if (a is File) {
            return -1;
          }
          if (b is File) {
            return 1;
          }
          return 0;
        });
      for (final fileEntity in contents) {
        final fileEntityPath = fileEntity.path;
        if (fileEntity is File) {
          if (_isPubspecFile(fileEntityPath)) {
            packagesDartFiles[fileEntityPath] = _getPackageBaseFiles(dirPath);
            handleAdditionalPaths(packagePath: dirPath);
            return;
          } else {
            addFile(pubspecPath, fileEntity);
          }
        } else if (fileEntity is Directory) {
          checkDir(fileEntity.path);
        }
      }
    }

    for (final path in additionalPaths) {
      checkDir('$packagePath$separator$path');
    }
  }

  handleAdditionalPaths(packagePath: currentPath);

  final List<PubspecFileData> pubspecFilesData = [];

  for (final entry in packagesDartFiles.entries) {
    pubspecFilesData.add(PubspecFileData(
      file: File(entry.key),
      packageFiles: entry.value,
    ));
  }

  return pubspecFilesData;
}

List<File> _getPackageBaseFiles(String packagePath) {
  String getSubDir(String subDirName) {
    return '$packagePath$separator$subDirName';
  }

  return [
    ..._readDir(getSubDir('lib')),
    ..._readDir(getSubDir('bin')),
    ..._readDir(getSubDir('test')),
    ..._readDir(getSubDir('tests')),
    ..._readDir(getSubDir('test_driver')),
    ..._readDir(getSubDir('integration_test')),
  ].cast<File>();
}

List<FileSystemEntity> _readDir(
  String dirPath, {
  bool recursive: true,
  bool withDirs: false,
}) {
  final dir = Directory(dirPath);
  if (dir.existsSync()) {
    return dir
        .listSync(recursive: recursive)
        .where((el) => withDirs ? true : el is! Directory)
        .where((el) {
      if (withDirs && el is Directory) {
        return true;
      }
      final filePath = el.path;
      return _isPubspecFile(filePath) || _isDartFile(filePath);
    }).toList();
  }
  return [];
}

bool _isPubspecFile(String path) {
  return path.endsWith('pubspec.yaml');
}

bool _isDartFile(String path) {
  return path.endsWith('.dart');
}

String getPubspecPath(String packagePath) {
  return '$packagePath${separator}pubspec.yaml';
}
