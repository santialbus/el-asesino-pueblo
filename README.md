# EL ASESINO — EL PUEBLO DUERME  ·  0.9.0 beta 1

Juego social de deducción multijugador (Flutter + Firebase Spark). Cada jugador
usa su dispositivo; un anfitrión modera la partida. Sin Cloud Functions, sin
servidor propio, sin servicios de pago.

> **Lee antes `docs/BETA_STATUS.md`**: explica qué está verificado con pruebas
> ejecutadas y qué falta por probar en tu máquina.

## Requisitos
* Flutter estable ≥ 3.27 (incluye Dart ≥ 3.6). <https://docs.flutter.dev/get-started/install>
* Node 18+ y Java 17+ (sólo para probar las reglas con el emulador).
* Firebase CLI (`npm i -g firebase-tools`) para publicar reglas y desplegar la web.

## 1. Preparar Firebase (proyecto `el-asesino-f0e55`)
1. Consola de Firebase → **Authentication → Método de acceso → Anónimo → Activar**.
2. **Firestore Database → Crear base de datos** (modo producción, la región que prefieras).
3. Publica las reglas (no uses el modo de prueba):
   ```bash
   firebase login
   firebase deploy --only firestore:rules
   ```
4. **Authentication → Configuración → Dominios autorizados**: añade el dominio donde
   alojes la web (y `localhost` para desarrollo).
5. (Recomendado) Activa **App Check** y restringe la clave de API por dominio.

La configuración web ya está en `lib/firebase_options.dart`. Android/iOS: registra
las apps en la consola y ejecuta `flutterfire configure` (sobrescribe ese archivo).

## 2. Preparar el proyecto
```bash
./tool/setup.sh        # flutter create (plataformas) + pub get
flutter analyze
flutter run -d chrome  # abre dos pestañas / navegadores para probar con 2+ jugadores
```
Para una partida real hacen falta 5 jugadores como mínimo: abre 5 ventanas de
navegador (una en incógnito por cada sesión anónima distinta) o usa varios dispositivos.

## 3. Pruebas
```bash
# Motor de reglas y simulaciones de partidas completas (Dart puro)
cd packages/asesino_core && dart pub get && dart test

# Reglas de seguridad de Firestore (emulador; requiere Java)
cd rules_test && npm install && npm test

# Widgets
flutter test
```

## 4. Compilar y publicar
```bash
# Web (alojable gratis en Firebase Hosting, Netlify, GitHub Pages…)
flutter build web --release
firebase deploy --only hosting

# Android
flutter build apk --release          # APK de pruebas
flutter build appbundle --release    # AAB para Google Play (necesita firma: docs de Flutter)

# iOS (en macOS con Xcode)
flutter build ipa
```
Publicar en Google Play o App Store tiene tarifas de registro **independientes de Firebase**.
Nada de esto se hace automáticamente.

## Probar sin otros jugadores
En el inicio, **«Partida con bots (pruebas)»** crea una partida local (sin Firebase) contra
bots que usan el mismo motor. Útil para ver todas las fases y probar la interfaz.

## Audio y fuentes
* Música original sintetizada por `tool/gen_music.py` (sin licencias). Los efectos de los eventos son **vibración** (sólo Android/iOS nativos; en web no vibra).
* Fuentes Cinzel y Lora (SIL Open Font License; ver `assets/fonts/OFL-Cinzel.txt`).

## Estructura
Ver `docs/ARCHITECTURE.md`. Seguridad y limitaciones: `docs/SECURITY.md`.
