/// Money as an integer number of öre (1 krona = 100 öre).
///
/// All amounts in Trakta are integers; there is no floating point anywhere
/// in the money path. Fractions are applied as integer numerator/denominator
/// pairs and rounded explicitly.
final class Ore implements Comparable<Ore> {
  const Ore(this.value);

  /// Whole kronor, the unit Skatteverket publishes.
  const Ore.kr(int kronor) : value = kronor * 100;

  static const zero = Ore(0);

  final int value;

  /// `this * numerator / denominator`, rounded half up to whole öre.
  ///
  /// Only non-negative amounts are expected in the engine; negative values
  /// round half away from zero for symmetry.
  Ore times(int numerator, int denominator) =>
      Ore(_divRoundHalfUp(value * numerator, denominator));

  /// `this * pct / 100`, rounded half up to whole öre.
  Ore percent(int pct) => times(pct, 100);

  /// Rounds to whole kronor, half up (Skatteverket rounds 73.50 → 74).
  Ore roundHalfUpToKrona() => Ore(_divRoundHalfUp(value, 100) * 100);

  bool get isZero => value == 0;
  bool get isNegative => value < 0;

  /// Whole-kronor part (truncated). Use for display only.
  int get kronorTruncated => value ~/ 100;

  Ore operator +(Ore other) => Ore(value + other.value);
  Ore operator -(Ore other) => Ore(value - other.value);
  Ore operator -() => Ore(-value);
  bool operator <(Ore other) => value < other.value;
  bool operator <=(Ore other) => value <= other.value;
  bool operator >(Ore other) => value > other.value;
  bool operator >=(Ore other) => value >= other.value;

  static Ore max(Ore a, Ore b) => a.value >= b.value ? a : b;
  static Ore min(Ore a, Ore b) => a.value <= b.value ? a : b;
  static Ore sum(Iterable<Ore> xs) => xs.fold(zero, (a, b) => a + b);

  @override
  int compareTo(Ore other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is Ore && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// `1 226,50 kr` style formatting (Swedish), without locale dependencies.
  String format({bool withUnit = true}) {
    final negative = value < 0;
    final abs = value.abs();
    final kr = abs ~/ 100;
    final ore = abs % 100;
    final digits = kr.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final kronor = buf.toString();
    final body = ore == 0 ? kronor : '$kronor,${ore.toString().padLeft(2, '0')}';
    return '${negative ? '-' : ''}$body${withUnit ? ' kr' : ''}';
  }

  @override
  String toString() => format();
}

int _divRoundHalfUp(int numerator, int denominator) {
  if (denominator <= 0) {
    throw ArgumentError.value(denominator, 'denominator', 'must be positive');
  }
  if (numerator >= 0) {
    return (numerator * 2 + denominator) ~/ (denominator * 2);
  }
  return -((-numerator * 2 + denominator) ~/ (denominator * 2));
}
