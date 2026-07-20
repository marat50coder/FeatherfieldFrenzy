import 'package:flutter_test/flutter_test.dart';

import 'package:frenzygame/data/game_data.dart';

void main() {
  test('there are four playable worlds', () {
    expect(kThemes.length, 4);
    expect(kThemes.first.unlockCost, 0);
  });
}
