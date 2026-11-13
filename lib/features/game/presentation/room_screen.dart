import 'dart:async';

import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/services/settings.dart';
import '../../../shared/widgets/backdrop.dart';
import '../../../shared/widgets/controls.dart';
import '../../lobby/create_screen.dart' show friendlyError;
import '../../lobby/lobby_view.dart';
import '../../settings/settings_screen.dart';
import '../application/providers.dart';
import 'game_views.dart';
import 'host_bar.dart';

/// Contenedor de una sala: lobby y todas las fases de la partida.
///
/// Responsabilidades (todas con ciclo de vida atado a esta pantalla):
///  * si este dispositivo es el anfitrión, ejecuta el [HostCoordinator];
///  * latido de presencia de cada jugador (1 escritura por minuto);
///  * detección de anfitrión caído y relevo;
///  * vibración de los eventos de la narración y música ambiental.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.code, this.onLocalExit});
  final String code;

  /// Si no es null, es una partida local con bots (sin Firebase): al salir se
  /// llama a este callback en vez de borrar la sesión guardada.
  final VoidCallback? onLocalExit;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen>
    with WidgetsBindingObserver {
  HostCoordinator? _host;
  Timer? _ticker;
  Timer? _beat;
  Timer? _refresh;
  bool _starting = false;
  String? _hostError;
  final HostWatchdog _watchdog = HostWatchdog();
  String? _lastNarration;
  bool _musicStarted = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<AsyncValue<RoomDoc?>>(roomProvider(widget.code), (
      prev,
      next,
    ) {
      final r = next.valueOrNull;
      if (r != null) _onRoom(r);
    }, fireImmediately: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _heartbeat());
    _beat = Timer.periodic(const Duration(seconds: 60), (_) => _heartbeat());
    _refresh = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _beat?.cancel();
    _refresh?.cancel();
    _ticker?.cancel();
    _host?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _heartbeat();
  }

  Future<void> _heartbeat() async {
    if (!_foreground || _host != null)
      return; // el anfitrión late desde su coordinador
    try {
      await ref.read(backendProvider).heartbeat(widget.code, asHost: false);
    } catch (_) {
      // Presencia aproximada: un latido perdido no es grave.
    }
  }

  // ------------------------------------------------------------------ eventos

  void _onRoom(RoomDoc room) {
    _watchdog.onRoom(room);
    final myUid = ref.read(backendProvider).uid;
    if (room.hostUid == myUid) {
      _ensureHost(room);
    } else if (_host != null) {
      _stopHost();
    }

    final audio = ref.read(audioProvider);
    if (!_musicStarted) {
      _musicStarted = true;
      audio.startMusic();
    }
    final key = '${room.version}|${room.narration.text}';
    if (room.narration.text.isNotEmpty && key != _lastNarration) {
      final first = _lastNarration == null;
      _lastNarration = key;
      if (!first) audio.cue(room.narration.cue); // vibración del evento
    }
  }

  Future<void> _ensureHost(RoomDoc room) async {
    if (_host != null || _starting) return;
    _starting = true;
    try {
      final h = HostCoordinator(
        backend: ref.read(backendProvider),
        roomId: widget.code,
        room: room,
      );
      h.onLost = () {
        if (mounted) setState(_stopHost);
      };
      await h.start();
      if (!mounted) {
        await h.stop();
        return;
      }
      _host = h;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        h.tick().catchError((Object _) {});
      });
      setState(() => _hostError = null);
    } catch (e) {
      if (mounted) setState(() => _hostError = friendlyError(e));
    } finally {
      _starting = false;
    }
  }

  void _stopHost() {
    _ticker?.cancel();
    _ticker = null;
    _host?.stop();
    _host = null;
  }

  // ------------------------------------------------------------------- salida

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: Text(title.toUpperCase(), style: AppText.label(14)),
        content: Text(body, style: AppText.body(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _leave() async {
    final room = ref.read(roomProvider(widget.code)).valueOrNull;
    final body =
        room == null ||
            room.phase == Phase.finished ||
            room.phase == Phase.lobby
        ? '¿Quieres salir de la sala?'
        : 'Si sales, tu personaje quedará eliminado de la partida.';
    if (!await _confirm('Salir', body)) return;
    await _exitRoom();
  }

  Future<void> _close() async {
    if (!await _confirm(
      'Cerrar la sala',
      'Se borrará la sala para todos los jugadores.',
    ))
      return;
    try {
      await ref.read(backendProvider).deleteRoom(widget.code);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    }
    await _exitRoom(skipWrite: true);
  }

  Future<void> _exitRoom({bool skipWrite = false}) async {
    final backend = ref.read(backendProvider);
    final room = ref.read(roomProvider(widget.code)).valueOrNull;
    if (!skipWrite && room != null) {
      try {
        if (room.phase == Phase.finished) {
          // Nada que escribir: la partida terminó.
        } else if (room.phase == Phase.lobby && room.hostUid == backend.uid) {
          await backend.deleteRoom(
            widget.code,
          ); // el anfitrión se va del lobby: se cierra
        } else {
          await backend.leaveRoom(
            widget.code,
            inGame: room.phase != Phase.lobby,
          );
        }
      } catch (_) {
        // Si no se puede escribir, igualmente se abandona localmente.
      }
    }
    _stopHost();
    await ref.read(audioProvider).stopMusic();
    if (widget.onLocalExit != null) {
      widget.onLocalExit!();
    } else {
      ref.read(sessionProvider.notifier).leave();
    }
  }

  // --------------------------------------------------------------------- UI

  Scene _sceneFor(RoomDoc r) => switch (r.phase) {
    Phase.lobby => Scene.night,
    Phase.roleReveal ||
    Phase.night ||
    Phase.victoryCheck ||
    Phase.nextRound => Scene.night,
    Phase.dawn => Scene.dawn,
    Phase.discussion || Phase.voting || Phase.voteResult => Scene.day,
    Phase.finished => r.winner == Winner.assassins ? Scene.night : Scene.dawn,
  };

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.code));
    final membersAsync = ref.watch(membersProvider(widget.code));
    final me = ref.watch(privateProvider(widget.code)).valueOrNull;
    final myUid = ref.watch(backendProvider).uid;

    Widget body;
    if (roomAsync.hasError || membersAsync.hasError) {
      final err = roomAsync.error ?? membersAsync.error;
      body = _message(
        err is PermissionDeniedException
            ? 'Ya no formas parte de esta sala.'
            : friendlyError(err ?? ''),
      );
    } else if (!roomAsync.hasValue || !membersAsync.hasValue) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    } else if (roomAsync.value == null) {
      body = _message('Esta sala ya no existe.');
    } else {
      final room = roomAsync.value!;
      final members = membersAsync.value!;
      if (findMember(members, myUid) == null && members.isNotEmpty) {
        body = _message('Ya no formas parte de esta sala.');
      } else {
        return _gameScaffold(room, members, me, myUid);
      }
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Backdrop(
          scene: Scene.night,
          child: SafeArea(child: body),
        ),
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.title(20, spacing: 1),
          ),
          const SizedBox(height: 24),
          GoldButton(
            label: 'Volver al menú',
            onPressed: () => _exitRoom(skipWrite: true),
          ),
        ],
      ),
    ),
  );

  Widget _gameScaffold(
    RoomDoc room,
    List<MemberDoc> members,
    PrivateDoc? me,
    String myUid,
  ) {
    final isHost = room.hostUid == myUid;
    final staleBanner =
        !isHost && room.phase != Phase.finished && _watchdog.hostStale;
    final inGame = room.phase != Phase.lobby && room.phase != Phase.finished;
    final scene = _sceneFor(room);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              child: Backdrop(
                key: ValueKey(scene),
                scene: scene,
                child: const SizedBox.expand(),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  if (staleBanner) _staleBanner(),
                  if (_hostError != null) _hostErrorBanner(room),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: KeyedSubtree(
                              key: ValueKey(
                                '${room.phase.name}_${room.round}_${room.voteSeq}',
                              ),
                              child: _phaseView(room, members, me, myUid),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (inGame && _host != null && isHost)
                    HostBar(host: _host!, myUid: myUid),
                ],
              ),
            ),
            if (widget.onLocalExit != null)
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 0, 0),
                    child: Text(
                      'MODO BOTS · LOCAL',
                      style: AppText.label(10, color: AppColors.text2),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: PopupMenuButton<String>(
                  tooltip: 'Menú',
                  icon: const Icon(Icons.more_vert, color: AppColors.text2),
                  color: AppColors.bg2,
                  onSelected: (v) {
                    switch (v) {
                      case 'settings':
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      case 'leave':
                        _leave();
                      case 'close':
                        _close();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'settings',
                      child: Text('Ajustes'),
                    ),
                    const PopupMenuItem(
                      value: 'leave',
                      child: Text('Salir de la sala'),
                    ),
                    if (isHost)
                      const PopupMenuItem(
                        value: 'close',
                        child: Text('Cerrar la sala'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phaseView(
    RoomDoc room,
    List<MemberDoc> members,
    PrivateDoc? me,
    String myUid,
  ) {
    switch (room.phase) {
      case Phase.lobby:
        return LobbyView(
          room: room,
          members: members,
          host: _host,
          myUid: myUid,
          onLeave: _leave,
        );
      case Phase.roleReveal:
        return RoleRevealView(
          room: room,
          members: members,
          me: me,
          myUid: myUid,
        );
      case Phase.night:
        return NightView(room: room, members: members, me: me, myUid: myUid);
      case Phase.dawn:
        return DawnView(room: room, members: members, me: me);
      case Phase.discussion:
        return DiscussionView(
          room: room,
          members: members,
          me: me,
          myUid: myUid,
        );
      case Phase.voting:
        return VotingView(room: room, members: members, myUid: myUid);
      case Phase.voteResult:
        return VoteResultView(room: room, members: members);
      case Phase.finished:
        return FinalView(
          room: room,
          members: members,
          me: me,
          myUid: myUid,
          host: _host,
          onLeave: () => _exitRoom(),
          onClose: _close,
        );
      case Phase.victoryCheck:
      case Phase.nextRound:
        return const SizedBox.shrink();
    }
  }

  Widget _staleBanner() => Material(
    color: AppColors.burgundy,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El anfitrión parece desconectado. La partida está en pausa.',
              style: AppText.body(13),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                final ok = await ref
                    .read(backendProvider)
                    .claimHost(widget.code);
                if (!ok && mounted) {
                  showMessage(
                    context,
                    'Todavía no se puede: el anfitrión aún podría volver.',
                  );
                }
              } catch (e) {
                if (mounted) showMessage(context, friendlyError(e));
              }
            },
            child: Text(
              'Tomar el control',
              style: AppText.body(13, color: AppColors.gold, bold: true),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _hostErrorBanner(RoomDoc room) => Material(
    color: AppColors.danger.withValues(alpha: 0.9),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(_hostError!, style: AppText.body(13))),
          TextButton(
            onPressed: () {
              setState(() => _hostError = null);
              _ensureHost(room);
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}
