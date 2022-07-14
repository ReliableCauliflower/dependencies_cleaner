import 'dart:io';

import 'package:yaml/yaml.dart';

class PubspecFileData {
  final File file;
  final List<File> packageFiles;
  final List<String> pubspecDependencies;

  PubspecFileData({
    required this.file,
    required this.packageFiles,
  }) : pubspecDependencies = _getPubspecDependencies(file);

  static List<String> _getPubspecDependencies(File pubspecFile) {
    final parsedFile = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    if (parsedFile.containsKey('dependencies')) {
      final dependencies = (parsedFile['dependencies'] as YamlMap).keys;
      return List<String>.from(dependencies);
    }
    return [];
  }
}
