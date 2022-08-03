import 'dart:collection';
import 'dart:math';

import 'package:flame_audio/audio_pool.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:game_template/main.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';

import '../settings/settings.dart';
import 'songs.dart';
import 'sounds.dart';

// TODO: check if later versions of flame_audio (and underlying audioplayers library) has fixed audio on android
class AudioController {
  static final _log = Logger('AudioController');

  final ProviderRef _ref;

  final Queue<Song> _playlist;

  final Random _random = Random();

  late AudioPool pool;

  late List<Uri> audioCache;

  AudioController(this._ref) : _playlist = Queue.of(List<Song>.of(songs)..shuffle());

  Future<void> initialize() async {
    _log.info('Preloading sound effects');

    audioCache = await FlameAudio.audioCache
        .loadAll(SfxType.values.expand(soundTypeToFilename).map((sound) => "sfx/$sound").toList());

    for (var uri in audioCache) {
      await AudioPool.create(
        uri.pathSegments.last,
        minPlayers: 3,
        maxPlayers: 4,
      );
    }

    FlameAudio.bgm.initialize();
    FlameAudio.bgm.audioPlayer?.onPlayerCompletion.listen(_changeSong);

    if (!_ref.read(settingsControllerProvider).muted && _ref.read(settingsControllerProvider).musicOn) {
      _startMusic();
    }

    _ref.read(settingsControllerProvider.notifier).addListener((state) {
      _musicOnHandler();
      _mutedHandler();
    });
  }

  /// Plays a single sound effect, defined by [type].
  ///
  /// The controller will ignore this call when the attached settings'
  /// [SettingsController.muted] is `true` or if its
  /// [SettingsController.soundsOn] is `false`.
  void playSfx(SfxType type) {
    final muted = _ref.read(settingsControllerProvider).muted;
    if (muted) {
      _log.info(() => 'Ignoring playing sound ($type) because audio is muted.');
      return;
    }
    final soundsOn = _ref.read(settingsControllerProvider).soundsOn;
    if (!soundsOn) {
      _log.info(() => 'Ignoring playing sound ($type) because sounds are turned off.');
      return;
    }

    _log.info(() => 'Playing sound: $type');
    final options = soundTypeToFilename(type);
    final filename = options[_random.nextInt(options.length)];
    _log.info(() => '- Chosen filename: $filename');

    FlameAudio.play("sfx/$filename");
  }

  void _changeSong(void _) {
    _log.info('Last song finished playing.');
    // Put the song that just finished playing to the end of the playlist.
    _playlist.addLast(_playlist.removeFirst());
    // Play the next song.
    _log.info(() => 'Playing ${_playlist.first} now.');
    FlameAudio.bgm.play("music/${_playlist.first.filename}");
  }

  void _musicOnHandler() {
    if (_ref.read(settingsControllerProvider).musicOn) {
      // Music got turned on.
      if (!_ref.read(settingsControllerProvider).muted) {
        _resumeMusic();
      }
    } else {
      // Music got turned off.
      _stopMusic();
    }
  }

  void _mutedHandler() {
    if (_ref.read(settingsControllerProvider).muted) {
      // All sound just got muted.
      _stopAllSound();
    } else {
      // All sound just got un-muted.
      if (_ref.read(settingsControllerProvider).musicOn) {
        _resumeMusic();
      }
    }
  }

  Future<void> _resumeMusic() async {
    _log.info('Resuming music');

    try {
      await FlameAudio.bgm.resume();
    } catch (e) {
      // Sometimes, resuming fails with an "Unexpected" error.
      _log.severe(e);
      await FlameAudio.bgm.play("music/${_playlist.first.filename}");
    }
  }

  void _startMusic() {
    _log.info('starting music');
    FlameAudio.bgm.play("music/${_playlist.first.filename}");
  }

  void _stopAllSound() {
    FlameAudio.bgm.pause();
  }

  void _stopMusic() {
    _log.info('Stopping music');

    FlameAudio.bgm.pause();
  }
}
