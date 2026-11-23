import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';

/// The Dart entities, the JSON mappers and the SQL migrations describe one API
/// contract. These tests read the migrations so a change on one side that is
/// not made on the other fails here.
String sql() {
  final directory = Directory('../supabase/migrations');
  expect(directory.existsSync(), isTrue, reason: 'run from the app/ folder');
  final files = directory.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files.map((f) => f.readAsStringSync()).join('\n');
}

String tableBody(String sql, String table) {
  final start = sql.indexOf('create table public.$table (');
  expect(start, isNonNegative, reason: 'table $table not found');
  return sql.substring(start, sql.indexOf('\n);', start));
}

Set<String> columns(String body) => {
  for (final line in body.split('\n').skip(1))
    if (RegExp(r'^\s+([a-z_]+)\s').firstMatch(line) case final m?
        when !const {'primary', 'check'}.contains(m.group(1)))
      m.group(1)!,
};

Set<String> allowedValues(String sql, String table, String column) {
  final body = tableBody(sql, table);
  final match = RegExp('$column text[^\\n]*? in \\(([^)]*)\\)')
      .firstMatch(body);
  expect(
    match,
    isNotNull,
    reason: '$table.$column has no allowed-values check',
  );
  return RegExp("'([^']+)'")
      .allMatches(match!.group(1)!)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  late String migrations;
  setUpAll(() => migrations = sql());

  test('every nutrient key is a meal_items column', () {
    final cols = columns(tableBody(migrations, 'meal_items'));
    for (final nutrient in Nutrient.values) {
      expect(cols, contains(nutrient.key), reason: nutrient.name);
    }
  });

  test('food units match the database check', () {
    expect(allowedValues(migrations, 'meal_items', 'unit'), foodUnits.toSet());
  });

  test('meal sources match the database check', () {
    expect(
      allowedValues(migrations, 'meals', 'source'),
      MealSource.values.map((s) => s.name).toSet(),
    );
  });

  test('confidence levels match the database check', () {
    expect(
      allowedValues(migrations, 'meals', 'confidence'),
      Confidence.values.map((c) => c.name).toSet(),
    );
  });

  test('profile fields the app reads are profile columns', () {
    final cols = columns(tableBody(migrations, 'profiles'));
    for (final key in [
      'height_cm',
      'weight_kg',
      'daily_calorie_target',
      'water_goal_ml',
      'timezone',
      'preferred_units',
      'preferred_language',
      'correction_consent',
    ]) {
      expect(cols, contains(key));
    }
  });

  test('meal, water and target fields the app reads exist', () {
    expect(
      columns(tableBody(migrations, 'meals')),
      containsAll([
        'id',
        'consumed_at',
        'source',
        'image_storage_path',
        'representative_calories',
        'confidence',
        'user_edited',
        'assumptions',
        'model',
        'updated_at',
      ]),
    );
    expect(
      columns(tableBody(migrations, 'water_logs')),
      containsAll(['id', 'logged_at', 'amount_ml', 'updated_at']),
    );
    expect(
      columns(tableBody(migrations, 'target_history')),
      containsAll(['effective_on', 'target_kcal']),
    );
  });

  test('the target policy matches the database bounds', () {
    expect(
      migrations,
      contains(
        'daily_calorie_target between $targetMinimum and $targetMaximum',
      ),
    );
  });
}
