import 'package:test/test.dart';
import 'package:simslim_cli/simslim_cli.dart';

void main() {
  group('profile model', () {
    test('except category and keep labels remove services from disable set', () {
      final desired = profileDisabled(except: ['store'], keep: ['com.apple.apsd']);
      expect(desired.contains('com.apple.appstored'), isFalse);
      expect(desired.contains('com.apple.apsd'), isFalse);
      expect(desired.contains('com.apple.searchd'), isTrue);
    });

    test('overlapping categories keep shared daemon enabled if one is excepted', () {
      final desired = profileDisabled(except: ['icloud']);
      expect(desired.contains('com.apple.amsaccountsd'), isFalse);
      expect(desired.contains('com.apple.amsengagementd'), isFalse);
    });

    test('only managed labels are mutated by delta', () {
      final (disable, enable) = delta({'com.example.outside', 'com.apple.apsd'},
          {'com.example.outside', 'com.apple.searchd'});
      expect(disable, {'com.apple.searchd'});
      expect(enable, {'com.apple.apsd'});
    });

    test('platform exceptions are respected', () {
      expect(desiredForPlatform({'com.apple.homed'}, 'watchOS'), isEmpty);
      expect(desiredForPlatform({'com.apple.mobileassetd'}, 'visionOS'), isEmpty);
    });

    test('catalog feature labels are all managed', () {
      for (final feature in features.values) {
        expect(managedLabels.containsAll(feature.$2), isTrue);
      }
    });
  });
}
