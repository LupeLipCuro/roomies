/// Todos los montos se manejan en céntimos (int) para evitar errores de redondeo.

/// Reparte [totalCents] en [n] partes iguales. Los céntimos sobrantes se
/// reparten de a uno entre las primeras personas.
List<int> splitEqual(int totalCents, int n) {
  if (n <= 0) return [];
  final base = totalCents ~/ n;
  final rem = totalCents - base * n;
  return List.generate(n, (i) => base + (i < rem ? 1 : 0));
}

/// Reparte según porcentajes. Devuelve null si los porcentajes no suman 100
/// (tolerancia de 0.01) o si alguno es negativo.
List<int>? splitByPercent(int totalCents, List<double> percents) {
  if (percents.isEmpty || percents.any((p) => p < 0)) return null;
  final sum = percents.fold<double>(0, (a, b) => a + b);
  if ((sum - 100).abs() > 0.01) return null;
  final amounts = percents.map((p) => (totalCents * p / 100).floor()).toList();
  var rest = totalCents - amounts.fold<int>(0, (a, b) => a + b);
  var i = 0;
  while (rest > 0) {
    amounts[i % amounts.length] += 1;
    rest--;
    i++;
  }
  return amounts;
}

/// "90.50" / "90,50" / "S/ 90" -> 9050. Devuelve null si no es válido.
int? parseCents(String text) {
  final clean = text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
  final value = double.tryParse(clean);
  if (value == null || value <= 0) return null;
  return (value * 100).round();
}

String formatSoles(int cents) => 'S/ ${(cents / 100).toStringAsFixed(2)}';
