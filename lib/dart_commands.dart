import 'dart:io';

Future<void> pubGet(String packagePath) {
  return _runFlutter(
    'pub get',
    workingDirPath: packagePath,
  );
}

Future<void> _runFlutter(
  String args, {
  required String workingDirPath,
}) async {
  await Process.start(
    'flutter',
    args.split(' '),
    workingDirectory: workingDirPath,
  );
}
