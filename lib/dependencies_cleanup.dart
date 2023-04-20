import 'package:dependencies_cleaner/models/package_info.dart';
import 'package:path/path.dart';
import 'package:pre_commit_helpers/pre_commit_helpers.dart';
import 'package:yaml/yaml.dart';

import 'values.dart';

Future<List<String>> cleanUpDependencies(
  List<PackageInfo> pubspecFilesData,
  List<String> ignoreDependencies,
) async {
  if (pubspecFilesData.isEmpty) {
    return [];
  }
  final Set<String> cleanedPubspecInfos = {};
  for (final pdfFileData in pubspecFilesData) {
    final dartFiles = pdfFileData.dartFiles;
    final pubspecDependencies = pdfFileData.pubspecDependencies;
    if (pubspecDependencies.isEmpty || dartFiles.isEmpty) {
      continue;
    }
    final Set<String> dependenciesToKeep = {...ignoreDependencies};
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
    final pubspecFile = pdfFileData.pubspecFile;
    final pubspecLines = pubspecFile.readAsLinesSync();
    final linesToRemoveIndexes = <int>[];
    for (final String dependency in pubspecDependencies) {
      if (dependenciesToKeep.contains(dependency)) {
        continue;
      }
      int? lastDependencyIndent;
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
          final currIndentLength = _getLineIndent(pubspecLine);
          if (currIndentLength > lastDependencyIndent) {
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
          final depIndent = _getLineIndent(pubspecLine);
          if (i > 0) {
            final prevDepIndent = _getLineIndent(pubspecLines[i - 1]);
            if (prevDepIndent > 0 && prevDepIndent < depIndent) {
              lastDependencyIndent = null;
              continue;
            }
          }
          lastDependencyIndent = depIndent;
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
    final dependencies = (parsedYaml['dependencies'] as YamlMap?)?.keys;

    if (dependencies?.isEmpty ?? true) {
      pubspecLines.removeWhere((line) => line.startsWith('dependencies:'));
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

int _getLineIndent(String pubspecLine) {
  for (int i = 0; i < pubspecLine.length; ++i) {
    final char = pubspecLine[i];
    if (char != ' ') {
      return i;
    }
  }
  return 0;
}
