import 'dart:async';

import 'package:asesino_core/asesino_core.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'settings.dart';

/// Música ambiental y retroalimentación háptica (vibración).
///
/// * La música es un único bucle (`ambient.wav`).
/// * Los efectos de los eventos se expresan con vibración: sólo funciona en
///   Android/iOS nativos (en web no hay vibración y simplemente no ocurre).
/// * Todo es opcional y a prueba de fallos: si el dispositivo no puede, el
///   juego sigue en silencio.
class AudioService {
  AudioService();

  AppSettings _s = const AppSettings();
  AudioPlayer? _music;
  bool _musicOn = false;

  void applySettings(AppSettings s) {
    final musicChanged = s.music != _s.music || s.musicVolume != _s.musicVolume;
    _s = s;
    if (musicChanged && _musicOn) {
      if (!s.music) {
        _safe(() async => _music?.pause());
      } else {
        _safe(() async {
          await _music?.setVolume(s.musicVolume * 0.6);
          await _music?.resume();
        });
      }
    }
  }

  /// Empieza el ambiente (llamar tras un gesto del usuario; el navegador lo exige).
  Future<void> startMusic() => _safe(() async {
    _musicOn = true;
    if (!_s.music) return;
    _music ??= AudioPlayer();
    await _music!.setReleaseMode(ReleaseMode.loop);
    await _music!.setVolume(_s.musicVolume * 0.6);
    await _music!.play(AssetSource('audio/ambient.wav'));
  });

  Future<void> stopMusic() => _safe(() async {
    _musicOn = false;
    await _music?.stop();
  });

  // ---------------------------------------------------------------- vibración

  /// Interacciones del propio jugador: 'card', 'confirm', 'vote'.
  Future<void> haptic(String name) {
    switch (name) {
      case 'card':
        return _pattern([_Pulse.select]);
      case 'confirm':
        return _pattern([_Pulse.light]);
      case 'vote':
        return _pattern([_Pulse.medium]);
      default:
        return Future.value();
    }
  }

  /// Vibración asociada a una línea de narración (evento de la partida).
  Future<void> cue(Cue cue) {
    switch (cue) {
      case Cue.reveal:
        return _pattern([_Pulse.select]);
      case Cue.nightStart:
        return _pattern([_Pulse.heavy, _Pulse.gap(220), _Pulse.medium]);
      case Cue.wake:
        return _pattern([_Pulse.light]);
      case Cue.sleep:
        return _pattern([_Pulse.select]);
      case Cue.dawn:
        return _pattern([
          _Pulse.light,
          _Pulse.gap(160),
          _Pulse.medium,
          _Pulse.gap(160),
          _Pulse.heavy,
        ]);
      case Cue.death:
        return _pattern([
          _Pulse.heavy,
          _Pulse.gap(180),
          _Pulse.heavy,
          _Pulse.gap(180),
          _Pulse.heavy,
        ]);
      case Cue.vote:
        return _pattern([_Pulse.medium]);
      case Cue.victory:
        return _pattern([
          _Pulse.light,
          _Pulse.gap(140),
          _Pulse.medium,
          _Pulse.gap(140),
          _Pulse.heavy,
          _Pulse.gap(140),
          _Pulse.heavy,
        ]);
      case Cue.defeat:
        return _pattern([
          _Pulse.heavy,
          _Pulse.gap(260),
          _Pulse.medium,
          _Pulse.gap(260),
          _Pulse.light,
        ]);
      case Cue.none:
        return Future.value();
    }
  }

  Future<void> _pattern(List<_Pulse> pulses) => _safe(() async {
    if (!_s.haptics) return;
    for (final p in pulses) {
      switch (p.kind) {
        case _Kind.select:
          await HapticFeedback.selectionClick();
        case _Kind.light:
          await HapticFeedback.lightImpact();
        case _Kind.medium:
          await HapticFeedback.mediumImpact();
        case _Kind.heavy:
          await HapticFeedback.heavyImpact();
        case _Kind.gap:
          await Future<void>.delayed(Duration(milliseconds: p.ms));
      }
    }
  });

  Future<void> dispose() async {
    await _safe(() async => _music?.dispose());
  }

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      // Sin audio o vibración no pasa nada: la partida continúa.
    }
  }
}

enum _Kind { select, light, medium, heavy, gap }

class _Pulse {
  const _Pulse._(this.kind, [this.ms = 0]);
  final _Kind kind;
  final int ms;

  static const select = _Pulse._(_Kind.select);
  static const light = _Pulse._(_Kind.light);
  static const medium = _Pulse._(_Kind.medium);
  static const heavy = _Pulse._(_Kind.heavy);
  static _Pulse gap(int ms) => _Pulse._(_Kind.gap, ms);
}
