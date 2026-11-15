import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../game/application/providers.dart';
import '../lobby/create_screen.dart' show friendlyError;

/// Abre el chat de la sala en una hoja inferior.
Future<void> showChatSheet(BuildContext context, String code) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => ChatSheet(code: code),
  );
}

class ChatSheet extends ConsumerStatefulWidget {
  const ChatSheet({super.key, required this.code});
  final String code;

  @override
  ConsumerState<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<ChatSheet> {
  final TextEditingController _text = TextEditingController();
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _text.text.trim();
    if (msg.isEmpty || _sending) return;
    // Límite anti-spam en el cliente (las reglas no pueden limitar la frecuencia).
    if (DateTime.now().difference(_lastSent) <
        const Duration(milliseconds: 1200))
      return;
    setState(() => _sending = true);
    try {
      await ref.read(backendProvider).sendChat(widget.code, msg);
      _lastSent = DateTime.now();
      _text.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider(widget.code)).valueOrNull;
    final members =
        ref.watch(membersProvider(widget.code)).valueOrNull ??
        const <MemberDoc>[];
    final msgs =
        ref.watch(chatProvider(widget.code)).valueOrNull ??
        const <ChatMessage>[];
    final myUid = ref.watch(backendProvider).uid;
    MemberDoc? me;
    for (final m in members) {
      if (m.uid == myUid) me = m;
    }
    final canWrite =
        room != null &&
        me != null &&
        ChatMessage.canWrite(room.phase, alive: me.alive);
    String? why;
    if (!canWrite && room != null) {
      why = (room.phase == Phase.night || room.phase == Phase.roleReveal)
          ? 'El chat está cerrado mientras el pueblo duerme.'
          : 'Estás eliminado: sólo puedes leer el chat.';
    }
    final h = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: h * 0.72,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('CHAT DE LA SALA', style: AppText.label(13)),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close, color: AppColors.text2),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: msgs.isEmpty
                    ? Center(
                        child: Text(
                          'Todavía no hay mensajes.',
                          style: AppText.body(14, color: AppColors.text2),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: msgs.length,
                        itemBuilder: (_, i) {
                          final m = msgs[msgs.length - 1 - i];
                          return _Bubble(msg: m, mine: m.uid == myUid);
                        },
                      ),
              ),
              if (why != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    why,
                    textAlign: TextAlign.center,
                    style: AppText.body(13, color: AppColors.text2),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          maxLength: ChatMessage.maxLength,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          cursorColor: AppColors.gold,
                          style: AppText.body(15),
                          decoration: InputDecoration(
                            hintText: 'Escribe un mensaje…',
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.bg,
                            hintStyle: AppText.body(14, color: AppColors.text2),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: AppColors.gold.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Enviar',
                        onPressed: _sending ? null : _send,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.mine});
  final ChatMessage msg;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mine
              ? AppColors.burgundy.withValues(alpha: 0.7)
              : AppColors.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: mine ? 0.5 : 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine) Text(msg.name, style: AppText.label(10)),
            Text(msg.text, style: AppText.body(15)),
          ],
        ),
      ),
    );
  }
}
