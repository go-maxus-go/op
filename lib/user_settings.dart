import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

/// Persistent user settings, stored on the device.
///
/// Call [UserSettings.init] once before `runApp`. Until then (e.g. in widget
/// tests) [instance] holds defaults in memory and nothing is persisted.
class UserSettings {
  UserSettings._(SharedPreferences? prefs)
    : practice = PracticeSettings._(prefs),
      configurator = ConfiguratorSettings._(prefs),
      equity = EquitySettings._(prefs),
      ranges = RangeSettings._(prefs);

  static UserSettings? _instance;

  static UserSettings get instance => _instance ??= UserSettings._(null);

  static Future<void> init() async {
    _instance = UserSettings._(await SharedPreferences.getInstance());
  }

  /// Practice table options.
  final PracticeSettings practice;

  /// Last selection made in the charts / practice configurator.
  final ConfiguratorSettings configurator;

  /// Equity calculator options.
  final EquitySettings equity;

  /// Ranges saved from the range selector.
  final RangeSettings ranges;
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

  int _getInt(String key, int fallback) =>
      _prefs?.getInt('$_prefix.$key') ?? fallback;

  void _setInt(String key, int value) => _prefs?.setInt('$_prefix.$key', value);
}

class EquitySettings extends _SettingsSection {
  static const int defaultSimulations = 10000;
  static const List<int> simulationCounts = [1000, 10000, 100000];

  EquitySettings._(SharedPreferences? prefs) : super(prefs, 'equity') {
    final stored = _getInt('simulations', defaultSimulations);
    _simulations = simulationCounts.contains(stored)
        ? stored
        : defaultSimulations;
  }

  late int _simulations;

  int get simulations => _simulations;
  set simulations(int value) {
    _simulations = value;
    _setInt('simulations', value);
  }
}

class SavedRange {
  const SavedRange(this.name, this.hands);

  final String name;

  /// Compact range text, e.g. `QQ+, AKs, AsKh`.
  final String hands;
}

class RangeSettings extends _SettingsSection {
  RangeSettings._(SharedPreferences? prefs) : super(prefs, 'ranges') {
    try {
      final decoded = jsonDecode(_getString('saved', '{}'));
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          if (entry.key is String && entry.value is String) {
            _saved[entry.key as String] = entry.value as String;
          }
        }
      }
    } on FormatException {
      // Unreadable data is dropped; the user starts with no saved ranges.
    }
  }

  final Map<String, String> _saved = {};

  /// Saved ranges sorted by name, ignoring case.
  List<SavedRange> get saved {
    final ranges = [
      for (final entry in _saved.entries) SavedRange(entry.key, entry.value),
    ];
    ranges.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.name.compareTo(b.name);
    });
    return ranges;
  }

  bool contains(String name) => _saved.containsKey(name);

  /// Saves [hands] under [name], replacing a range with the same name.
  void save(String name, String hands) {
    _saved[name] = hands;
    _store();
  }

  void rename(String oldName, String newName) {
    final hands = _saved.remove(oldName);
    if (hands == null) return;
    _saved[newName] = hands;
    _store();
  }

  void remove(String name) {
    if (_saved.remove(name) != null) _store();
  }

  void _store() => _setString('saved', jsonEncode(_saved));
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
    _opponentPosition = _getString(
      'opponentPosition',
      PokerConstants.positionUTG,
    );
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
