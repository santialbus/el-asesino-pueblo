# App Check (para cuando despleguemos)

**Qué es.** Hoy cualquiera con la dirección de tu web puede obtener una sesión anónima y
llamar a Firestore. App Check añade una prueba de que la petición procede de **tu app
desplegada** (en web, mediante reCAPTCHA v3, gratuito). Sin esa prueba, Firebase rechaza la
petición. Evita que un script ajeno agote la cuota diaria de Spark y deje sin servicio el juego.
No sustituye a las reglas de Firestore: es una capa adicional.

**Cómo activarlo.**
1. Consola de Firebase → **App Check** → registra la app web con **reCAPTCHA v3** (genera una
   clave de sitio en https://www.google.com/recaptcha/admin y añade tu dominio).
2. Añade el paquete `firebase_app_check` y, en `main()`, antes de usar Firestore:
   ```dart
   await FirebaseAppCheck.instance.activate(
     webProvider: ReCaptchaV3Provider('TU_CLAVE_DE_SITIO'),
   );
   ```
3. Despliega y comprueba en App Check → **Solicitudes** que se ven como verificadas.
4. Sólo entonces, en App Check → Firestore y Authentication, pulsa **Aplicar** (enforce).
   Hacerlo antes bloquearía tu propia app.

Para desarrollo local usa un *debug token* (la consola lo explica) en lugar de reCAPTCHA.
