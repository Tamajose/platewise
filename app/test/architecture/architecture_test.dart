import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'layer_rules.dart';

void main() {
  group('rules catch violations', () {
    test('domain may not import Flutter, Supabase or Riverpod', () {
      for (final import in [
        'package:flutter/widgets.dart',
        'package:supabase_flutter/supabase_flutter.dart',
        'package:flutter_riverpod/flutter_riverpod.dart',
        'package:http/http.dart',
        'dart:io',
        'dart:ui',
      ]) {
        expect(
          violations('features/meals/domain/x.dart', [import]),
          isNotEmpty,
          reason: import,
        );
      }
    });

    test('domain may import pure Dart and its own domain', () {
      expect(
        violations('features/meals/domain/x.dart', [
          'dart:math',
          'package:timezone/timezone.dart',
          '../../../core/domain/domain.dart',
          'y.dart',
        ]),
        isEmpty,
      );
    });

    test('domain may not reach into data or presentation', () {
      expect(
        violations('core/domain/x.dart', ['../../features/meals/data/y.dart']),
        isNotEmpty,
      );
      expect(
        violations('features/meals/domain/x.dart', ['../data/y.dart']),
        isNotEmpty,
      );
      expect(
        violations('features/meals/domain/x.dart', [
          'package:platewise/features/meals/presentation/y.dart',
        ]),
        isNotEmpty,
      );
    });

    test('features may not import each other', () {
      expect(
        violations('features/meals/presentation/x.dart', [
          '../../water/domain/y.dart',
        ]),
        isNotEmpty,
      );
      expect(
        violations('features/meals/data/x.dart', [
          'package:platewise/features/water/data/y.dart',
        ]),
        isNotEmpty,
      );
    });

    test('data may not import presentation', () {
      expect(
        violations('features/meals/data/x.dart', ['../presentation/y.dart']),
        isNotEmpty,
      );
    });

    test('presentation reaches data only through provider files', () {
      expect(
        violations('features/meals/presentation/x.dart', [
          '../data/meal_repository_impl.dart',
        ]),
        isNotEmpty,
      );
      expect(
        violations('features/meals/presentation/x.dart', [
          '../data/meal_providers.dart',
          '../domain/meal.dart',
          '../../../core/domain/domain.dart',
          'package:flutter/widgets.dart',
        ]),
        isEmpty,
      );
    });

    test('the shell may import any feature', () {
      expect(
        violations('app/router.dart', [
          '../features/meals/presentation/x.dart',
          '../features/water/presentation/y.dart',
        ]),
        isEmpty,
      );
    });
  });

  test('the source tree follows the layer rules', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'run from the app/ folder');
    final problems = <String>[];
    var checked = 0;
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll(r'\', '/');
      final libPath = normalized.substring(normalized.indexOf('lib/') + 4);
      problems.addAll(
        violations(libPath, importsIn(entity.readAsStringSync())),
      );
      checked++;
    }
    expect(checked, greaterThan(0));
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
