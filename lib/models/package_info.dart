import 'dart:io';

import 'package:pre_commit_helpers/pre_commit_helpers.dart';
import 'package:yaml/yaml.dart';

import '../values.dart';

class PackageInfo {
  final File pubspecFile;
  final List<File> dartFiles;
  final List<String> pubspecDependencies;

  PackageInfo({
    required this.pubspecFile,
    required this.dartFiles,
  }) : pubspecDependencies = _getPubspecDependencies(pubspecFile);

  factory PackageInfo.fromPackageData(PackageData packageData) {
    return PackageInfo(
      pubspecFile: packageData.pubspecFile,
      dartFiles: packageData.dartFiles,
    );
  }

  static List<String> _getPubspecDependencies(File pubspecFile) {
    final parsedFile = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    if (parsedFile.containsKey('dependencies')) {
      final dependencies = (parsedFile['dependencies'] as YamlMap?)?.keys;
      final buildRunnerDependencies =
          (parsedFile['dev_dependencies'] as YamlMap?)?.keys.where(
                (element) => supportedBuildRunnerDependencies.contains(element),
              );
      return [
        if (dependencies != null) ...List<String>.from(dependencies),
        if (buildRunnerDependencies != null)
          ...List<String>.from(buildRunnerDependencies),
      ];
    }
    return [];
  }
}
