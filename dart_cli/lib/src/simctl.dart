import 'dart:convert';
import 'dart:io';

class SimDevice {
  const SimDevice({required this.udid, required this.name, required this.state,
    required this.platform, required this.osVersion, required this.runtimeId,
    required this.dataPath});

  final String udid, name, state, platform, osVersion, runtimeId, dataPath;
  bool get booted => state == 'Booted';
  String get runtimeName => '$platform $osVersion';
  bool get persistentOverrides {
    final parts = osVersion.split('.');
    if (parts.length < 2) return false;
    final major = int.tryParse(parts[0]), minor = int.tryParse(parts[1]);
    if (major == null || minor == null) return false;
    final minimum = platform == 'watchOS' ? 11 : platform == 'visionOS' ? 2 : 18;
    return (platform == 'iOS' || platform == 'tvOS' || platform == 'watchOS' || platform == 'visionOS') &&
        (major > minimum || (major == minimum && minor >= 5));
  }

  Map<String, Object?> toJson() => {
    'udid': udid, 'name': name, 'state': state, 'platform': platform,
    'osVersion': osVersion,
  };
}

class Simctl {
  Simctl({this.sets = const []});
  final List<String> sets;

  Future<ProcessResult> _run(List<String> args, {Duration timeout = const Duration(minutes: 10)}) async {
    if (!Platform.isMacOS) throw const ProcessException('xcrun', [], 'simslim only works on macOS');
    final process = await Process.start('xcrun', args);
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    try {
      final code = await process.exitCode.timeout(timeout, onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        throw TimeoutException('command timed out after $timeout');
      });
      return ProcessResult(process.pid, code, await stdoutFuture, await stderrFuture);
    } catch (_) {
      process.kill(ProcessSignal.sigkill);
      rethrow;
    }
  }

  List<String> _args(String set, List<String> command) => [
    'simctl', if (set.isNotEmpty) ...['--set', set], ...command,
  ];

  Future<String> call(String set, List<String> command, {Duration timeout = const Duration(minutes: 10)}) async {
    final result = await _run(_args(set, command), timeout: timeout);
    if (result.exitCode != 0) {
      throw StateError('xcrun ${_args(set, command).join(' ')} failed: ${result.stderr.toString().trim()}');
    }
    return result.stdout as String;
  }

  Future<List<SimDevice>> list() async {
    final devices = <SimDevice>[];
    final allSets = ['', 'testing', ...sets.where((s) => s != 'testing')];
    for (final set in allSets.toSet()) {
      try {
        final raw = jsonDecode(await call(set, ['list', 'devices', '-j'])) as Map<String, dynamic>;
        final deviceMap = raw['devices'] as Map<String, dynamic>? ?? {};
        for (final runtimeEntry in deviceMap.entries) {
          final parsed = _parseRuntime(runtimeEntry.key);
          if (parsed == null) continue;
          for (final item in runtimeEntry.value as List<dynamic>) {
            final row = item as Map<String, dynamic>;
            if (row['isAvailable'] != true) continue;
            devices.add(SimDevice(
              udid: row['udid'] as String,
              name: row['name'] as String,
              state: row['state'] as String,
              platform: parsed.$1,
              osVersion: parsed.$2,
              runtimeId: runtimeEntry.key,
              dataPath: row['dataPath'] as String? ?? '',
            ));
          }
        }
      } on StateError {
        if (set.isEmpty) rethrow;
      }
    }
    return devices;
  }

  Future<SimDevice> find(String udid) async {
    for (final device in await list()) {
      if (device.udid == udid) return device;
    }
    throw StateError('no simulator with udid $udid');
  }

  static (String, String)? _parseRuntime(String id) {
    const prefix = 'com.apple.CoreSimulator.SimRuntime.';
    if (!id.startsWith(prefix)) return null;
    final name = id.substring(prefix.length);
    final dash = name.indexOf('-');
    if (dash < 0) return null;
    final rawPlatform = name.substring(0, dash);
    final platform = rawPlatform == 'xrOS' ? 'visionOS' : rawPlatform;
    if (!{'iOS', 'tvOS', 'watchOS', 'visionOS'}.contains(platform)) return null;
    return (platform, name.substring(dash + 1).replaceAll('-', '.'));
  }

  Future<Set<String>> disabled(SimDevice device) async {
    final output = await call('', ['spawn', device.udid, 'launchctl', 'print-disabled', 'system']);
    final result = <String>{};
    final pattern = RegExp(r'"([^"]+)"\s*=>\s*(disabled|true)');
    for (final match in pattern.allMatches(output)) {
      result.add(match.group(1)!);
    }
    return result;
  }

  Future<void> transition(SimDevice device, String verb, String label) async {
    await call('', ['spawn', device.udid, 'launchctl', verb, 'system/$label'], timeout: const Duration(minutes: 2));
  }

  Future<void> boot(SimDevice device) async {
    final result = await _run(_args('', ['boot', device.udid]));
    final combined = '${result.stdout}\n${result.stderr}';
    if (result.exitCode != 0 && !combined.contains('already booted') && !combined.contains('current state: Booted')) {
      throw StateError('simctl boot failed: ${combined.trim()}');
    }
    await call('', ['bootstatus', device.udid, '-b']);
  }

  Future<void> shutdown(SimDevice device) async {
    final result = await _run(_args('', ['shutdown', device.udid]), timeout: const Duration(seconds: 30));
    if (result.exitCode != 0 && !'${result.stdout}\n${result.stderr}'.contains('current state: Shutdown')) {
      throw StateError('simctl shutdown failed: ${result.stderr}');
    }
  }

  Future<Set<String>> applyDelta(SimDevice device, Set<String> disable, Set<String> enable,
      {bool live = false}) async {
    // Serialized launchctl operations reduce contention and keep progress/errors attributable.
    for (final label in disable.toList()..sort()) {
      await transition(device, 'disable', label);
      if (live) {
        try { await transition(device, 'bootout', label); } on StateError catch (error) {
          if (!error.message.toString().contains('No such process')) rethrow;
        }
      }
    }
    for (final label in enable.toList()..sort()) {
      await transition(device, 'enable', label);
    }
    return disabled(device);
  }
}
