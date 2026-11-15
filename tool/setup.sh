#!/usr/bin/env bash
# Prepara las carpetas de plataforma que Flutter genera (web, android, ios) sin
# tocar lib/ ni pubspec.yaml. Ejecutar UNA vez, tras instalar Flutter.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --platforms=web,android,ios --project-name el_asesino --org com.elasesino .
# La plantilla genera una prueba de ejemplo que referencia `MyApp` (no existe aquí).
rm -f test/widget_test.dart
flutter pub get
# Página web: fondo oscuro (evita franjas blancas en iOS), theme-color y manifiesto de la PWA.
cp web_template/index.html web/index.html
cp web_template/manifest.json web/manifest.json
echo "Listo. Ejecuta: flutter run -d chrome"
