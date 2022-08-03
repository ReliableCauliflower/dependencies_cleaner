import 'package:dependencies_cleaner/dart_commands.dart';
import 'package:dependencies_cleaner/models/pubspec_file_data.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

import 'values.dart';

Future<List<String>> cleanUpDependencies(
  List<PubspecFileData> pubspecFilesData,
) async {
  if (pubspecFilesData.isEmpty) {
    return [];
  }
  final Set<String> cleanedPubspecInfos = {};
  for (final pdfFileData in pubspecFilesData) {
    final dartFiles = pdfFileData.packageFiles;
    final pubspecDependencies = pdfFileData.pubspecDependencies;
    if (pubspecDependencies.isEmpty || dartFiles.isEmpty) {
      continue;
    }
    final Set<String> dependenciesToKeep = {};
    for (final dartFile in dartFiles) {
      final fileString = dartFile.readAsStringSync();
      for (final dependency in pubspecDependencies) {
        if (fileString.contains('package:$dependency')) {
          dependenciesToKeep.add(dependency);
        } else if (dependency == freezedDependencyName) {
          final fileName = basenameWithoutExtension(dartFile.path);
          if (fileString.contains("part '$fileName.$freezedPartSufix';")) {
            dependenciesToKeep.add(dependency);
          }
        }
      }
    }
    if (dependenciesToKeep.length == pubspecDependencies.length) {
      continue;
    }
    final pubspecFile = pdfFileData.file;
    final pubspecLines = pubspecFile.readAsLinesSync();
    final linesToRemoveIndexes = <int>[];
    for (final String dependency in pubspecDependencies) {
      if (dependenciesToKeep.contains(dependency)) {
        continue;
      }
      String? lastDependencyIndent;
      for (int i = 0; i < pubspecLines.length; ++i) {
        final pubspecLine = pubspecLines[i];
        if (pubspecLine.isEmpty) {
          if (i == pubspecLines.length - 1 || pubspecLines[i + 1].isEmpty) {
            pubspecLines.removeAt(i);
            i--;
            continue;
          }
        }
        if (lastDependencyIndent != null) {
          int currIndentLength = 0;
          for (int i = 0; i < pubspecLine.length; ++i) {
            final char = pubspecLine[i];
            if (char != ' ') {
              currIndentLength = i;
              break;
            }
          }
          if (currIndentLength > lastDependencyIndent.length) {
            linesToRemoveIndexes.add(i);
            continue;
          } else {
            lastDependencyIndent = null;
            if (!multipleWritesDependencies.contains(dependency)) {
              break;
            }
          }
        }
        if (pubspecLine.contains('$dependency:')) {
          lastDependencyIndent =
              pubspecLine.substring(0, pubspecLine.indexOf(dependency));
          linesToRemoveIndexes.add(i);
        } else {
          lastDependencyIndent = null;
        }
      }
    }
    linesToRemoveIndexes.sort();
    for (int i = 0; i < linesToRemoveIndexes.length; ++i) {
      pubspecLines.removeAt(linesToRemoveIndexes[i] - i);
    }
    final parsedYaml = loadYaml(pubspecLines.join('\n'));
    late final Iterable dependencies;
    try {
      dependencies = (parsedYaml['dependencies'] as YamlMap).keys;
    } catch (e) {
      print(
        'Failed to parse dependencies for the pubspec '
        'at path: ${pubspecFile.path}',
      );
      continue;
    }

    if (dependencies.isEmpty) {
      pubspecLines.removeWhere((line) => line.contains('dependencies'));
    }

    final devDependencies =
        (parsedYaml['dev_dependencies'] as YamlMap?)?.keys ?? [];

    if (devDependencies.isNotEmpty) {
      bool canRemoveBuildRunner = true;
      for (final devDep in devDependencies) {
        if (devDep == 'build_runner' ||
            nonBuildRunnerDevDependencies.contains(devDep)) {
          continue;
        }
        canRemoveBuildRunner = false;
        break;
      }

      if (canRemoveBuildRunner) {
        for (int i = 0; i < pubspecLines.length; ++i) {
          if (pubspecLines[i].contains('dev_dependencies')) {
            if (devDependencies.length == 1 &&
                devDependencies.first == 'build_runner') {
              pubspecLines.removeAt(i);
              --i;
            }
          } else if (pubspecLines[i].contains('build_runner')) {
            pubspecLines.removeAt(i);
            break;
          }
        }
      }
    }

    for (int i = pubspecLines.length - 1; i >= 0; --i) {
      final line = pubspecLines[i];
      if (line.isEmpty) {
        pubspecLines.removeLast();
      } else {
        bool isLineOfSpaces = true;
        for (int i = 0; i < line.length; ++i) {
          final char = line[i];
          if (char == ' ') {
            continue;
          } else {
            isLineOfSpaces = false;
            break;
          }
        }
        if (isLineOfSpaces) {
          pubspecLines.removeLast();
        } else {
          break;
        }
      }
    }

    pubspecFile.writeAsStringSync(pubspecLines.join('\n'));

    await pubGet(pubspecFile.parent.path);
    cleanedPubspecInfos.add(pubspecFile.absolute.path);
  }

  return cleanedPubspecInfos.toList(growable: false);
}
