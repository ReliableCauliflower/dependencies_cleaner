import 'dart:io';

import 'package:yaml/yaml.dart';
import 'models/pubspec_file_data.dart';

/// Get all the dart files for the project and the contents
List<PubspecFileData> pubspecFiles({
  required String currentPath,
  required List<String> additionalPaths,
  required String basePubspecPath,
}) {
  final packagesDartFiles = <String, List<File>>{};
  final additionalPathsFileEntities = <FileSystemEntity>[];
  for (final path in additionalPaths) {
    additionalPathsFileEntities.addAll(_readDir(currentPath, path));
  }
  final allContents = [
    ..._readDir(currentPath, 'lib'),
    ..._readDir(currentPath, 'bin'),
    ..._readDir(currentPath, 'test'),
    ..._readDir(currentPath, 'tests'),
    ..._readDir(currentPath, 'test_driver'),
    ..._readDir(currentPath, 'integration_test'),
    ...additionalPathsFileEntities,
  ];

  String lastPackageDirPath = currentPath;
  String pubspecPath = basePubspecPath;
  for (final fileSysEntity in allContents) {
    if (fileSysEntity is File) {
      final filePath = fileSysEntity.path;
      if (filePath.endsWith('.dart')) {
        if (!filePath.startsWith(lastPackageDirPath)) {
          pubspecPath = basePubspecPath;
        }
        if (packagesDartFiles[pubspecPath] != null) {
          packagesDartFiles[pubspecPath]!.add(fileSysEntity);
        } else {
          packagesDartFiles[pubspecPath] = [fileSysEntity];
        }
        ;
      } else if (filePath.endsWith('pubspec.yaml')) {
        try {
          final pubspecYaml = loadYaml(fileSysEntity.readAsStringSync());
          final pubspecPackageName = pubspecYaml['name'];
          if (pubspecPackageName != null) {
            pubspecPath = fileSysEntity.path;
            lastPackageDirPath = fileSysEntity.parent.path;
          }
        } catch (e) {
          stdout.write('An error occured parsing the $filePath:\n$e');
          continue;
        }
      }
    }
  }

  final List<PubspecFileData> pubspecFilesData = [];

  for (final entry in packagesDartFiles.entries) {
    pubspecFilesData.add(PubspecFileData(
      file: File(entry.key),
      packageFiles: entry.value,
    ));
  }

  return pubspecFilesData;
}

List<FileSystemEntity> _readDir(String currentPath, String name) {
  final dir = Directory('$currentPath/$name');
  if (dir.existsSync()) {
    return dir.listSync(recursive: true);
  }
  return [];
}
