import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'backdrop.dart';

/// Estructura común de pantallas: fondo, cabecera sobria y contenido centrado
/// con ancho máximo (móvil primero, cómodo también en tablet y escritorio).
class AsesinoPage extends StatelessWidget {
  const AsesinoPage({
    super.key,
    required this.child,
    this.title,
    this.scene = Scene.plain,
    this.village = false,
    this.maxWidth = 520,
    this.scroll = true,
    this.back = true,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  final Widget child;
  final String? title;
  final Scene scene;
  final bool village;
  final double maxWidth;
  final bool scroll;
  final bool back;
  final List<Widget> actions;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: title == null && actions.isEmpty && !back
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: back,
              foregroundColor: AppColors.text,
              centerTitle: true,
              title: title == null
                  ? null
                  : Text(title!.toUpperCase(), style: AppText.label(14)),
              actions: actions,
            ),
      extendBodyBehindAppBar: true,
      body: Backdrop(
        scene: scene,
        village: village,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: scroll ? SingleChildScrollView(child: body) : body,
            ),
          ),
        ),
      ),
    );
  }
}
