# SimSlim Dart CLI

This directory contains an initial Dart CLI port of simslim. The existing Go library/CLI and SwiftUI app are intentionally left unchanged; this port is focused on the command-line experience and uses `xcrun simctl` directly.

## Requirements

- macOS with Xcode and an installed Apple Simulator runtime
- Dart SDK 3.3+

## Run and test

```sh
cd dart_cli
dart pub get
dart test
dart run bin/simslim.dart list
dart run bin/simslim.dart profiles
```

Commands currently implemented: `list`, `profiles`, `on`, `off`, `status`, `verify`, `doctor`, `boot`, `shutdown`, `erase`, `delete`, and `rename`. Read-only commands support `--json`. Service mutation is restricted to the explicit allowlist in `lib/src/catalog.dart`; labels outside it are not changed.

This first port does not yet include the original CLI's TUI, `watch`, clone/repair, disk cleanup/measurement, or the full management command set. The category memory estimates and GUI-specific JSON details are also not yet ported. Those are follow-up parity work, not implemented behavior.
