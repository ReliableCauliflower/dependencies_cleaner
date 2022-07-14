import 'dart:io';
import 'package:dependencies_cleaner/dependencies_cleanup.dart';
import 'package:yaml/yaml.dart';

import 'package:dependencies_cleaner/models/pubspec_file_data.dart';
import 'package:dependencies_cleaner/files.dart' as files;

Future<void> main(List<String> args) async {
  final currentPath = Directory.current.path;

  final basePubspecPath = '${currentPath}/pubspec.yaml';
  final pubspecYamlFile = File(basePubspecPath);
  final pubspecYaml = loadYaml(pubspecYamlFile.readAsStringSync());

  final additionalPaths = <String>[];

  if (pubspecYaml.containsKey('dependencies_cleaner')) {
    final config = pubspecYaml['dependencies_cleaner'];
    if (config.containsKey('additional_paths')) {
      final yamlList = config['additional_paths'];
      additionalPaths.addAll(List<String>.from(yamlList));
    }
  }

  final stopwatch = Stopwatch();
  stopwatch.start();

  final List<PubspecFileData> pubspecFilesData = files.pubspecFiles(
    currentPath: currentPath,
    additionalPaths: additionalPaths,
    basePubspecPath: basePubspecPath,
  );

  stdout.write('┏━━ Checking ${pubspecFilesData.length} packages dependencies');

  final cleanedUpPaths = await cleanUpDependencies(pubspecFilesData);

  if (cleanedUpPaths.isNotEmpty) {
    if (cleanedUpPaths.length > 1) {
      stdout.write("\n");
    }
    for (int i = 0; i < cleanedUpPaths.length; ++i) {
      final pubspecPath = cleanedUpPaths[i];
      stdout.write(
        '${cleanedUpPaths.length == 1 ? '\n' : ''}┃ '
        ' ${i == cleanedUpPaths.length - 1 ? '┗' : '┣'}━━ '
        'Cleaned up $pubspecPath\n',
      );
    }
  } else {
    stdout.write("\n");
  }

  stopwatch.stop();

  stdout.write(
    '┗━━ Cleaned up ${cleanedUpPaths.length} pubspeck '
    'files in ${stopwatch.elapsedMilliseconds}ms\n',
  );
}
