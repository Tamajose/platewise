import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/format/number_format.dart';

void main() {
  test('number groups thousands in English locale', () {
    expect(number(0), '0');
    expect(number(999), '999');
    expect(number(1234567), '1,234,567');
  });

  test('number keeps decimals', () {
    expect(number(1234.5), '1,234.5');
  });
}
