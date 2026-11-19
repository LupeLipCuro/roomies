import 'package:flutter_test/flutter_test.dart';
import 'package:roomies/utils/split.dart';

void main() {
  test('partes iguales suman el total', () {
    final parts = splitEqual(10000, 3);
    expect(parts, [3334, 3333, 3333]);
    expect(parts.reduce((a, b) => a + b), 10000);
  });

  test('porcentajes que suman 100', () {
    final parts = splitByPercent(9000, [50, 30, 20]);
    expect(parts, [4500, 2700, 1800]);
  });

  test('porcentajes con redondeo siguen sumando el total', () {
    final parts = splitByPercent(10000, [33.33, 33.33, 33.34])!;
    expect(parts.reduce((a, b) => a + b), 10000);
  });

  test('porcentajes que no suman 100 son inválidos', () {
    expect(splitByPercent(9000, [50, 30, 10]), isNull);
  });

  test('parseCents', () {
    expect(parseCents('90.50'), 9050);
    expect(parseCents('S/ 90,5'), 9050);
    expect(parseCents('abc'), isNull);
  });
}
