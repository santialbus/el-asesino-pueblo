import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:el_asesino/core/services/settings.dart';
import 'package:el_asesino/shared/widgets/game_widgets.dart';
import 'package:el_asesino/shared/widgets/role_card.dart';

Future<Widget> app(Widget child) async {
  SharedPreferences.setMockInitialValues({'reduceMotion': true});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  testWidgets('cada rol se dibuja boca arriba y boca abajo sin errores', (tester) async {
    for (final role in RoleId.values) {
      for (final up in [false, true]) {
        await tester.pumpWidget(
          await app(RoleCard(role: role, team: RoleInfo.of(role).defaultTeam, faceUp: up, width: 220)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('la carta muestra el nombre del rol al darle la vuelta', (tester) async {
    await tester.pumpWidget(
      await app(RoleCard(role: RoleId.police, team: Team.town, faceUp: true, width: 220)),
    );
    await tester.pumpAndSettle();
    expect(find.text('EL POLICÍA'), findsOneWidget);
  });

  testWidgets('PlayerTile muestra nombre y reacciona al toque', (tester) async {
    var taps = 0;
    await tester.pumpWidget(await app(PlayerTile(
      member: const MemberDoc(uid: 'a', name: 'Ana', joinedAtMs: 0),
      onTap: () => taps++,
    )));
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.byType(PlayerTile));
    expect(taps, 1);
  });
}
