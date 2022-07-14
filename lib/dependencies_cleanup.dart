import 'package:dependencies_cleaner/dart_commands.dart';
import 'package:dependencies_cleaner/models/pubspec_file_data.dart';

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
      final dartFileLines = dartFile.readAsLinesSync();
      final importsString = _getImportsString(dartFileLines);
      for (final dependency in pubspecDependencies) {
        if (importsString.contains('package:$dependency')) {
          dependenciesToKeep.add(dependency);
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
      String lastDependencyIndent = '';
      for (int i = 0; i < pubspecLines.length; ++i) {
        final pubspecLine = pubspecLines[i];
        if (lastDependencyIndent.isNotEmpty) {
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
            break;
          }
        }
        if (pubspecLine.contains('$dependency:')) {
          lastDependencyIndent =
              pubspecLine.substring(0, pubspecLine.indexOf(dependency));
          linesToRemoveIndexes.add(i);
          continue;
        }
      }
    }
    for (int i = 0; i < linesToRemoveIndexes.length; ++i) {
      pubspecLines.removeAt(linesToRemoveIndexes[i] - i);
    }
    pubspecFile.writeAsStringSync(pubspecLines.join('\n'));
    final pubspecPath = pubspecFile.path;
    final packagePath = pubspecPath.substring(
      0,
      pubspecPath.lastIndexOf('/') + 1,
    );
    await pubGet(packagePath);
    cleanedPubspecInfos.add(pubspecFile.absolute.path);
  }

  return cleanedPubspecInfos.toList(growable: false);
}

String _getImportsString(List<String> dartFileLines) {
  final importLines = <String>[];

  for (final line in dartFileLines) {
    if (line.startsWith('import') || line.startsWith('export')) {
      importLines.add(line);
    }
  }
  return importLines.join();
}
