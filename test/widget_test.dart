import 'package:flutter_test/flutter_test.dart';
import 'package:icw16b/dev_faults.dart';

void main() {
  test('dev faults are consumed once and report what is armed', () {
    final f = DevFaults();
    expect(f.armedSummary, 'nothing armed');
    f.armTrivia(TriviaFault.fourResults);
    expect(f.takeTrivia(), TriviaFault.fourResults);
    expect(f.takeTrivia(), TriviaFault.none);
  });
}
