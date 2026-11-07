import 'package:test/test.dart';
import 'package:trakta_core/trakta_core.dart';

void main() {
  test('kr constructor', () => expect(const Ore.kr(300).value, 30000));

  test('percent rounds half up to öre', () {
    expect(const Ore(21000).percent(35), const Ore(7350));
    expect(const Ore(1).percent(50), const Ore(1)); // 0.5 öre -> 1
  });

  test('round half up to krona', () {
    expect(const Ore(7350).roundHalfUpToKrona(), const Ore.kr(74));
    expect(const Ore(7349).roundHalfUpToKrona(), const Ore.kr(73));
    expect(const Ore(29750).roundHalfUpToKrona(), const Ore.kr(298));
    expect(const Ore(5250).roundHalfUpToKrona(), const Ore.kr(53));
  });

  test('odd half normalbelopp keeps öre precision', () {
    expect(const Ore.kr(1049).times(1, 2), const Ore(52450));
  });

  test('format', () {
    expect(const Ore(122650).format(), '1 226,50 kr');
    expect(const Ore.kr(300).format(withUnit: false), '300');
    expect(const Ore(-5).format(), '-0,05 kr');
  });

  test('sum/min/max', () {
    expect(Ore.sum([const Ore(1), const Ore(2)]), const Ore(3));
    expect(Ore.max(const Ore(1), const Ore(2)), const Ore(2));
    expect(Ore.min(const Ore(1), const Ore(2)), const Ore(1));
  });
}
