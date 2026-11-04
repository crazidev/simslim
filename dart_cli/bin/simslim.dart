import 'dart:io';

import 'package:simslim_cli/simslim_cli.dart';

Future<void> main(List<String> arguments) async {
  final exitCode = await SimSlimCli(Simctl()).run(arguments);
  if (exitCode != 0) exit(exitCode);
}
