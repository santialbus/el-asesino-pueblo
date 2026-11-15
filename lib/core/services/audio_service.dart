import 'dart:async';

import 'package:asesino_core/asesino_core.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'settings.dart';

/// Pistas de música. `lobby` es el ambiente original (también para la noche).
enum Track { menu, lobby, day, tension }

String _trackAsset(Track t) => switch (t) {
  Track.menu => 'audio/menu.wav',
  Track.lobby => 'audio/ambient.wav',
  Track.day => 'audio/day.wav',
  Track.tension => 'audio/tension.wav',
};

/// Música (varias pistas con fundido) y retroalimentación háptica (vibración).
///
/// * Una sola pista suena a la vez; al cambiar de fase se hace fundido cruzado.
/// * Los efectos de los eventos se expresan con vibración: sólo funciona en
///   Android/iOS nativos (en web no hay vibración y simplemente no ocurre).
/// * Todo es opcional y a prueba de fallos: si el dispositivo no puede, el
///   juego sigue en silencio.
class AudioService {
  AudioService();

  AppSettings _s = const AppSettings();
  AudioPlayer? _music;
  Track? _wanted; // pista que debería sonar
  Track? _playing; // pista que está sonando
  int _gen = 0; // invalida fundidos en curso al cambiar de pista

  double get _targetVolume => _s.musicVolume * 0.6;

  void applySettings(AppSettings s) {
    final was = _s;
    _s = s;
    if (s.music != was.music) {
      if (!s.music) {
        _safe(() async => _music?.pause());
      } else if (_wanted != null) {
        if (_playing == _wanted) {
          _safe(() async {
            await _music?.setVolume(_targetVolume);
            await _music?.resume();
          });
        } else {
          setTrack(_wanted!);
        }
      }
    } else if (s.musicVolume != was.musicVolume && _playing != null) {
      _safe(() async => _music?.setVolume(_targetVolume));
    }
  }

  /// Cambia la pista con fundido. Idempotente: si ya suena, no hace nada.
  /// Llamar tras un gesto del usuario (el navegador lo exige para el audio).
  Future<void> setTrack(Track t) => _safe(() async {
    _wanted = t;
    if (!_s.music || _playing == t) return;
    final gen = ++_gen;
    final p = _music ??= AudioPlayer();
    if (_playing != null) {
      await _fade(p, to: 0, ms: 500, gen: gen);
      if (gen != _gen) return;
    }
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setVolume(0);
    await p.play(AssetSource(_trackAsset(t)));
    _playing = t;
    await _fade(p, to: _targetVolume, ms: 800, gen: gen);
  });

  Future<void> stopMusic() => _safe(() async {
    _gen++;
    _wanted = null;
    _playing = null;
    await _music?.stop();
  });

  Future<void> _fade(
    AudioPlayer p, {
    required double to,
    required int ms,
    required int gen,
  }) async {
    const steps = 10;
    var from = to == 0 ? _targetVolume : 0.0;
    if (to != 0 && ms == 0) from = to;
    for (var i = 1; i <= steps; i++) {
      if (gen != _gen) return;
      await p.setVolume(from + (to - from) * i / steps);
      await Future<void>.delayed(Duration(milliseconds: ms ~/ steps));
    }
  }

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
    _gen++;
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
