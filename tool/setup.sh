#!/usr/bin/env bash
# Prepara las carpetas de plataforma que Flutter genera (web, android, ios) sin
# tocar lib/ ni pubspec.yaml. Ejecutar UNA vez, tras instalar Flutter.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --platforms=web,android,ios --project-name el_asesino --org com.elasesino .
# La plantilla genera una prueba de ejemplo que referencia `MyApp` (no existe aquí).
rm -f test/widget_test.dart
flutter pub get
# Título y descripción de la web
if [ -f web/index.html ]; then
  sed -i.bak 's#<title>.*</title>#<title>El Asesino — El Pueblo Duerme</title>#' web/index.html && rm -f web/index.html.bak
fi
echo "Listo. Ejecuta: flutter run -d chrome"
