import 'package:flutter_test/flutter_test.dart';
import 'package:optimal_poker/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saved ranges survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    await UserSettings.init();
    UserSettings.instance.ranges
      ..save('b', 'KK')
      ..save('a', 'AA')
      ..save('c', 'QQ')
      ..rename('c', 'C')
      ..remove('b');

    await UserSettings.init();

    final saved = UserSettings.instance.ranges.saved;
    expect(saved.map((r) => r.name), ['a', 'C']);
    expect(saved.map((r) => r.hands), ['AA', 'QQ']);
  });

  test('unreadable saved ranges are ignored', () async {
    SharedPreferences.setMockInitialValues({'ranges.saved': 'not json'});
    await UserSettings.init();

    expect(UserSettings.instance.ranges.saved, isEmpty);
  });
}
