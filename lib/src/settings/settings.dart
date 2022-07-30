import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'persistence/settings_persistence.dart';

class Settings {
  final bool muted;
  final String playerName;
  final bool soundsOn;
  final bool musicOn;

  Settings({
    required this.muted,
    required this.playerName,
    required this.soundsOn,
    required this.musicOn,
  });

  Settings copyWith({bool? muted, String? playerName, bool? soundsOn, bool? musicOn}) {
    return Settings(
      muted: muted ?? this.muted,
      playerName: playerName ?? this.playerName,
      soundsOn: soundsOn ?? this.soundsOn,
      musicOn: musicOn ?? this.musicOn,
    );
  }
}

/// An class that holds settings like [playerName] or [musicOn],
/// and saves them to an injected persistence store.
class SettingsController extends StateNotifier<Settings> {
  final SettingsPersistence _persistence;

  Settings _settings;

  /// Creates a new instance of [SettingsController] backed by [persistence].
  SettingsController({required SettingsPersistence persistence})
      : _persistence = persistence,
        _settings = Settings(playerName: "Player", musicOn: false, muted: false, soundsOn: false),
        super(Settings(playerName: "Player", musicOn: false, muted: false, soundsOn: false));

  /// Asynchronously loads values from the injected persistence store.
  Future<void> loadStateFromPersistence() async {
    await Future.wait([
      _persistence
          // On the web, sound can only start after user interaction, so
          // we start muted there.
          // On any other platform, we start unmuted.
          .getMuted(defaultValue: kIsWeb)
          .then((value) => _settings.copyWith(muted: value)),
      _persistence.getSoundsOn().then((value) => _settings = _settings.copyWith(soundsOn: value)),
      _persistence.getMusicOn().then((value) => _settings = _settings.copyWith(musicOn: value)),
      _persistence.getPlayerName().then((value) => _settings = _settings.copyWith(playerName: value)),
    ]);

    state = _settings;
  }

  void setPlayerName(String name) {
    _settings = _settings.copyWith(playerName: name);
    _persistence.savePlayerName(_settings.playerName);

    state = _settings;
  }

  void toggleMusicOn() {
    _settings = _settings.copyWith(musicOn: !_settings.musicOn);
    _persistence.saveMusicOn(_settings.musicOn);

    state = _settings;
  }

  void toggleMuted() {
    _settings = _settings.copyWith(muted: !_settings.muted);
    _persistence.saveMuted(_settings.muted);

    state = _settings;
  }

  void toggleSoundsOn() {
    _settings = _settings.copyWith(soundsOn: !_settings.soundsOn);
    _persistence.saveSoundsOn(_settings.soundsOn);

    state = _settings;
  }
}
