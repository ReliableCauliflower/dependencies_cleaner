import 'dart:io';
import 'package:dependencies_cleaner/dependencies_cleanup.dart';
import 'package:pre_commit_helpers/pre_commit_helpers.dart';

import 'package:dependencies_cleaner/models/package_info.dart';

const dependenciesCleanerName = 'dependencies_cleaner';
const additionalPathsName = 'additional_paths';
const ignorePathsName = 'ignore_paths';
const ignoreDependenciesName = 'ignore_dependencies';

Future<void> main(List<String> args) async {
  final currentPath = Directory.current.path;

  final basePubspecPath = getPubspecPath(currentPath);

  final additionalPaths = getArgList(
    pubspecPath: basePubspecPath,
    configName: dependenciesCleanerName,
    argName: additionalPathsName,
  );

  final ignorePaths = getArgList(
    pubspecPath: basePubspecPath,
    configName: dependenciesCleanerName,
    argName: ignorePathsName,
  );

  final ignoreDependencies = getArgList(
    pubspecPath: basePubspecPath,
    configName: dependenciesCleanerName,
    argName: ignoreDependenciesName,
  );

  final stopwatch = Stopwatch();
  stopwatch.start();

  final packageData = getPackagesData(
    currentPath: currentPath,
    additionalPaths: additionalPaths,
    ignorePaths: ignorePaths,
  ).map((e) => PackageInfo.fromPackageData(e)).toList();

  stdout.write('┏━━ Checking ${packageData.length} packages dependencies');

  final cleanedUpPaths = await cleanUpDependencies(
    packageData,
    ignoreDependencies,
  );

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
