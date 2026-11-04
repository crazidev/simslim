import 'dart:convert';
import 'dart:io';

import 'catalog.dart';
import 'simctl.dart';

class SlimProfile {
  const SlimProfile({this.name = '', this.description = '', this.except = const {}, this.keep = const {}});
  final String name, description;
  final Set<String> except, keep;

  static Future<SlimProfile> load(String path) async {
    final dynamic decoded;
    try { decoded = jsonDecode(await File(path).readAsString()); }
    on FileSystemException catch (error) { throw FormatException('read profile $path: $error'); }
    if (decoded is! Map<String, dynamic>) throw FormatException('profile $path must be a JSON object');
    final unknown = decoded.keys.toSet().difference({'name', 'description', 'except', 'keep'});
    if (unknown.isNotEmpty) throw FormatException('profile $path: unknown field "${unknown.first}"');
    Set<String> strings(String key) {
      final value = decoded[key];
      if (value == null) return {};
      if (value is! List || value.any((element) => element is! String)) {
        throw FormatException('profile $path: "$key" must be an array of strings');
      }
      return value.map((e) => (e as String).trim()).where((e) => e.isNotEmpty).toSet();
    }
    final except = strings('except'), keep = strings('keep');
    for (final id in except) {
      if (!categoryById.containsKey(id)) throw FormatException('profile $path: unknown category "$id"');
    }
    for (final label in keep) {
      if (!managedLabels.contains(label)) throw FormatException('profile $path: "$label" is not a managed daemon');
    }
    return SlimProfile(
      name: decoded['name'] as String? ?? '',
      description: decoded['description'] as String? ?? '',
      except: except, keep: keep,
    );
  }

  Set<String> desired => profileDisabled(except: except, keep: keep);
}

class SimSlimCli {
  SimSlimCli(this.simctl, {this.stdout = stdout, this.stderr = stderr});
  final Simctl simctl;
  final IOSink stdout, stderr;

  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.first == 'help' || args.first == '--help' || args.first == '-h') {
      _usage(); return 0;
    }
    if (args.first == 'version' || args.first == '--version' || args.first == '-v') {
      stdout.writeln('simslim dart 0.1.0'); return 0;
    }
    if (!Platform.isMacOS) { stderr.writeln('simslim only works on macOS (it drives Apple\'s simulators).'); return 1; }
    try {
      final command = args.first;
      final rest = args.skip(1).toList();
      final json = rest.remove('--json');
      switch (command) {
        case 'list': return await _list(rest, json);
        case 'profiles': return _profiles(rest, json);
        case 'on': return await _on(rest, json);
        case 'off': return await _off(rest, json);
        case 'status': return await _status(rest, json);
        case 'verify': return await _verify(rest, json);
        case 'doctor': return await _doctor(rest, json);
        case 'boot': case 'shutdown': case 'erase': case 'delete': case 'rename':
          return await _manage(command, rest, json);
        default:
          throw FormatException('unsupported command "$command" in this initial Dart CLI port');
      }
    } catch (error) {
      stderr.writeln('simslim: $error');
      return 1;
    }
  }

  Future<int> _list(List<String> args, bool json) async {
    final bootedOnly = args.remove('--booted');
    if (args.isNotEmpty) throw FormatException('list takes no arguments');
    var devices = await simctl.list();
    if (bootedOnly) devices = devices.where((d) => d.booted).toList();
    devices.sort((a, b) => a.platform.compareTo(b.platform));
    if (json) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(devices.map((d) => {
        ...d.toJson(), 'managedTotal': desiredForPlatform(slimmableLabels, d.platform).length,
      }).toList()));
    } else {
      for (final d in devices) {
        stdout.writeln('${d.udid}  ${d.name.padRight(22)} ${d.runtimeName.padRight(14)} ${d.booted ? 'booted' : 'shutdown'}');
      }
    }
    return 0;
  }

  int _profiles(List<String> args, bool json) {
    if (args.length > 1) throw FormatException('profiles takes at most one category ID');
    final selected = args.isEmpty ? categories : [categoryById[args.single]].whereType<SlimCategory>().toList();
    if (args.isNotEmpty && selected.isEmpty) throw FormatException('unknown category "${args.single}"');
    if (json) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(args.isEmpty ? selected.map((c) => c.toJson()).toList() : selected.single.toJson()));
    } else {
      for (final c in selected) {
        stdout.writeln('${c.id.padRight(14)} ${c.name}\n               ${c.description}\n               When disabled: ${c.downside}');
        if (args.isNotEmpty) for (final label in c.labels) stdout.writeln('  $label');
      }
    }
    return 0;
  }

  Future<int> _on(List<String> args, bool json) async {
    final udid = _oneUdid(args);
    final profile = await _profileOptions(args);
    final device = await simctl.find(udid);
    final desired = desiredForPlatform(profile.desired, device.platform);
    if (desired.isNotEmpty && !device.persistentOverrides && !args.contains('--no-reboot')) {
      throw StateError('${device.runtimeName} cannot persist launchd overrides; use --no-reboot for this boot session');
    }
    await simctl.boot(device);
    final current = await simctl.disabled(device);
    final changes = delta(current, desired);
    if (args.contains('--no-reboot')) {
      await simctl.applyDelta(device, changes.$1, {}, live: true);
      final after = await simctl.disabled(device);
      if (!after.containsAll(desired)) throw StateError('not all requested disable overrides took effect');
      if (!json) stdout.writeln('Done. Simulator slimmed for this boot session without a reboot.');
      return 0;
    }
    if (changes.$1.isEmpty && changes.$2.isEmpty) {
      if (!json) stdout.writeln('Already slim. Nothing to change.');
      return 0;
    }
    await simctl.applyDelta(device, changes.$1, changes.$2);
    await simctl.shutdown(device);
    await simctl.boot(device);
    final after = await simctl.disabled(device);
    if (delta(after, desired).$1.isNotEmpty || delta(after, desired).$2.isNotEmpty) {
      throw StateError('disable overrides did not survive reboot');
    }
    if (!json) stdout.writeln('Done. Simulator reconfigured and rebooted slim.');
    return 0;
  }

  Future<int> _off(List<String> args, bool json) async {
    final device = await simctl.find(_oneUdid(args));
    await simctl.boot(device);
    final current = await simctl.disabled(device);
    final changes = delta(current, {});
    if (changes.$2.isNotEmpty) {
      await simctl.applyDelta(device, {}, changes.$2);
      await simctl.shutdown(device);
      await simctl.boot(device);
    }
    if (!json) stdout.writeln(changes.$2.isEmpty ? 'Already stock. Nothing to change.' : 'Done. All managed services re-enabled.');
    return 0;
  }

  Future<int> _status(List<String> args, bool json) async {
    final device = await simctl.find(_oneUdid(args));
    if (!device.booted) throw StateError('simulator must be booted to read its state (it is ${device.state})');
    final disabled = await simctl.disabled(device);
    final managed = desiredForPlatform(slimmableLabels, device.platform);
    final count = disabled.intersection(managed).length;
    final verdict = count == managed.length ? 'slim' : count > 0 ? 'partially slim' : 'stock';
    final result = {'managedDisabled': count, 'managedTotal': managed.length, 'booted': true,
      'persistent': device.persistentOverrides, 'verdict': verdict};
    if (json) stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
    else stdout.writeln('${device.udid}: $count/${managed.length} managed launchd labels disabled ($verdict)');
    return 0;
  }

  Future<int> _verify(List<String> args, bool json) async {
    final udid = _oneUdid(args);
    final profile = await _profileOptions(args);
    final device = await simctl.find(udid);
    if (!device.booted) throw StateError('simulator must be booted to verify');
    final expected = desiredForPlatform(profile.desired, device.platform);
    final current = (await simctl.disabled(device)).intersection(managedLabels);
    final missing = expected.difference(current).toList()..sort();
    final extra = current.difference(expected).toList()..sort();
    final ok = missing.isEmpty && extra.isEmpty;
    if (json) stdout.writeln(const JsonEncoder.withIndent('  ').convert({'udid': udid, 'ok': ok, 'missing': missing, 'extra': extra}));
    else stdout.writeln(ok ? '$udid matches the profile.' : '$udid does not match the profile: ${missing.length} missing, ${extra.length} extra.');
    return ok ? 0 : 1;
  }

  Future<int> _doctor(List<String> args, bool json) async {
    final list = args.remove('--list');
    if (list) {
      final output = features.entries.map((e) => {'id': e.key, 'name': e.value.$1, 'labels': e.value.$2}).toList();
      if (json) stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
      else for (final e in features.entries) stdout.writeln('${e.key.padRight(16)} ${e.value.$1.padRight(38)} ${e.value.$2.join(', ')}');
      return 0;
    }
    if (args.isEmpty) throw FormatException('doctor expects a simulator UDID and --requires feature IDs');
    final udid = args.removeAt(0);
    final requiresIndex = args.indexOf('--requires');
    if (requiresIndex < 0 || requiresIndex + 1 >= args.length) throw FormatException('doctor needs --requires feature IDs');
    final required = args[requiresIndex + 1].split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    for (final id in required) { if (!features.containsKey(id)) throw FormatException('unknown feature "$id"'); }
    final device = await simctl.find(udid);
    final disabled = await simctl.disabled(device);
    final rows = required.map((id) {
      final feature = features[id]!;
      final down = feature.$2.where(disabled.contains).toList();
      return {'id': id, 'name': feature.$1, 'ok': down.isEmpty, 'disabled': down};
    }).toList();
    final ok = rows.every((r) => r['ok'] == true);
    final result = {'udid': udid, 'ok': ok, 'features': rows};
    if (json) stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
    else {
      stdout.writeln('$udid: ${rows.where((r) => r['ok'] == true).length}/${rows.length} required features OK');
      for (final row in rows) stdout.writeln(row['ok'] == true ? '  ok     ${row['id']}' : '  BROKEN ${row['id']} — ${(row['disabled'] as List).join(', ')} disabled');
    }
    return ok ? 0 : 1;
  }

  Future<int> _manage(String command, List<String> args, bool json) async {
    if (args.isEmpty) throw FormatException('$command expects a simulator UDID');
    final device = await simctl.find(args.first);
    switch (command) {
      case 'boot': await simctl.boot(device); break;
      case 'shutdown': if (device.booted) await simctl.shutdown(device); break;
      case 'erase':
        if (device.booted) await simctl.shutdown(device);
        await simctl.call('', ['erase', device.udid]); break;
      case 'delete':
        if (device.booted) await simctl.shutdown(device);
        await simctl.call('', ['delete', device.udid]); break;
      case 'rename':
        if (args.length != 2 || args[1].trim().isEmpty) throw FormatException('rename expects a UDID and non-empty name');
        await simctl.call('', ['rename', device.udid, args[1].trim()]); break;
    }
    if (json) stdout.writeln(const JsonEncoder.withIndent('  ').convert({'action': command, 'udid': device.udid}));
    else stdout.writeln('${command[0].toUpperCase()}${command.substring(1)} complete for ${device.udid}.');
    return 0;
  }

  Future<SlimProfile> _profileOptions(List<String> args) async {
    String valueAfter(String name) {
      final index = args.indexOf(name);
      if (index < 0) return '';
      if (index + 1 >= args.length) throw FormatException('$name requires a value');
      return args[index + 1];
    }
    final path = valueAfter('--profile'), except = valueAfter('--except'), keep = valueAfter('--keep');
    if (path.isNotEmpty) {
      if (except.isNotEmpty || keep.isNotEmpty) throw FormatException('--profile cannot be combined with --except or --keep');
      return SlimProfile.load(path);
    }
    final exceptIDs = except.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final keepLabels = keep.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    for (final label in keepLabels) { if (!managedLabels.contains(label)) throw FormatException('"$label" is not a managed daemon'); }
    return SlimProfile(except: exceptIDs, keep: keepLabels);
  }

  String _oneUdid(List<String> args) {
    if (args.isEmpty) throw FormatException('expected exactly one simulator UDID');
    return args.first;
  }

  void _usage() => stdout.writeln('''simslim (Dart CLI)
Usage: dart run bin/simslim.dart <command> [arguments]

Commands: list, profiles, on, off, status, verify, doctor, boot, shutdown,
          erase, delete, rename
Slim profile options: --profile <file> | --except <category,...> --keep <label,...>
Read-only commands accept --json. This port operates on macOS Simulator via xcrun simctl.''');
}
