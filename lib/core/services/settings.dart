import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales del dispositivo (no se sincronizan con Firebase).
class AppSettings {
  const AppSettings({
    this.music = true,
    this.haptics = true,
    this.musicVolume = 0.5,
    this.reduceMotion = false,
    this.playerName = '',
  });

  final bool music;

  /// Vibración como efecto de los eventos de la partida (sólo móvil nativo).
  final bool haptics;
  final double musicVolume;
  final bool reduceMotion;
  final String playerName;

  AppSettings copyWith({
    bool? music,
    bool? haptics,
    double? musicVolume,
    bool? reduceMotion,
    String? playerName,
  }) => AppSettings(
    music: music ?? this.music,
    haptics: haptics ?? this.haptics,
    musicVolume: musicVolume ?? this.musicVolume,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    playerName: playerName ?? this.playerName,
  );
}

final prefsProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('prefsProvider debe sobrescribirse en main()'),
);

class SettingsNotifier extends Notifier<AppSettings> {
  late SharedPreferences _p;

  @override
  AppSettings build() {
    _p = ref.watch(prefsProvider);
    return AppSettings(
      music: _p.getBool('music') ?? true,
      haptics: _p.getBool('haptics') ?? true,
      musicVolume: _p.getDouble('musicVolume') ?? 0.5,
      reduceMotion: _p.getBool('reduceMotion') ?? false,
      playerName: _p.getString('playerName') ?? '',
    );
  }

  void update(AppSettings s) {
    state = s;
    _p.setBool('music', s.music);
    _p.setBool('haptics', s.haptics);
    _p.setDouble('musicVolume', s.musicVolume);
    _p.setBool('reduceMotion', s.reduceMotion);
    _p.setString('playerName', s.playerName);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// Código de la sala en la que está el usuario (para recuperar la sesión).
class SessionNotifier extends Notifier<String?> {
  late SharedPreferences _p;

  @override
  String? build() {
    _p = ref.watch(prefsProvider);
    return _p.getString('roomId');
  }

  void enter(String code) {
    state = code;
    _p.setString('roomId', code);
  }

  void leave() {
    state = null;
    _p.remove('roomId');
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, String?>(
  SessionNotifier.new,
);
