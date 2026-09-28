import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

/// Persistent user settings, stored on the device.
///
/// Call [UserSettings.init] once before `runApp`. Until then (e.g. in widget
/// tests) [instance] holds defaults in memory and nothing is persisted.
class UserSettings {
  UserSettings._(SharedPreferences? prefs)
      : practice = PracticeSettings._(prefs),
        configurator = ConfiguratorSettings._(prefs);

  static UserSettings? _instance;

  static UserSettings get instance => _instance ??= UserSettings._(null);

  static Future<void> init() async {
    _instance = UserSettings._(await SharedPreferences.getInstance());
  }

  /// Practice table options.
  final PracticeSettings practice;

  /// Last selection made in the charts / practice configurator.
  final ConfiguratorSettings configurator;
}

/// Base for a group of settings backed by [SharedPreferences] keys sharing a
/// common prefix.
abstract class _SettingsSection {
  _SettingsSection(this._prefs, this._prefix);

  final SharedPreferences? _prefs;
  final String _prefix;

  bool _getBool(String key, bool fallback) =>
      _prefs?.getBool('$_prefix.$key') ?? fallback;

  String _getString(String key, String fallback) =>
      _prefs?.getString('$_prefix.$key') ?? fallback;

  void _setBool(String key, bool value) =>
      _prefs?.setBool('$_prefix.$key', value);

  void _setString(String key, String value) =>
      _prefs?.setString('$_prefix.$key', value);
}

class PracticeSettings extends _SettingsSection {
  PracticeSettings._(SharedPreferences? prefs) : super(prefs, 'practice') {
    _autoAdvance = _getBool('autoAdvance', true);
    _displayInDollars = _getBool('displayInDollars', false);
    _showOpponentCards = _getBool('showOpponentCards', true);
  }

  late bool _autoAdvance;
  late bool _displayInDollars;
  late bool _showOpponentCards;

  bool get autoAdvance => _autoAdvance;
  set autoAdvance(bool value) {
    _autoAdvance = value;
    _setBool('autoAdvance', value);
  }

  bool get displayInDollars => _displayInDollars;
  set displayInDollars(bool value) {
    _displayInDollars = value;
    _setBool('displayInDollars', value);
  }

  bool get showOpponentCards => _showOpponentCards;
  set showOpponentCards(bool value) {
    _showOpponentCards = value;
    _setBool('showOpponentCards', value);
  }
}

class ConfiguratorSettings extends _SettingsSection {
  ConfiguratorSettings._(SharedPreferences? prefs)
      : super(prefs, 'configurator') {
    _mode = _getString('mode', 'Practice');
    _limit = _getString('limit', PokerConstants.limitNL100);
    _position = _getString('position', 'All');
    _opponentPosition =
        _getString('opponentPosition', PokerConstants.positionUTG);
    _chart = _getString('chart', PokerConstants.chartOPR);
  }

  late String _mode;
  late String _limit;
  late String _position;
  late String _opponentPosition;
  late String _chart;

  /// 'Chart' or 'Practice'.
  String get mode => _mode;
  set mode(String value) {
    _mode = value;
    _setString('mode', value);
  }

  String get limit => _limit;
  set limit(String value) {
    _limit = value;
    _setString('limit', value);
  }

  /// Hero position, or 'All' to cycle through positions in practice.
  String get position => _position;
  set position(String value) {
    _position = value;
    _setString('position', value);
  }

  /// Raiser position for the vs OPR chart.
  String get opponentPosition => _opponentPosition;
  set opponentPosition(String value) {
    _opponentPosition = value;
    _setString('opponentPosition', value);
  }

  String get chart => _chart;
  set chart(String value) {
    _chart = value;
    _setString('chart', value);
  }
}
