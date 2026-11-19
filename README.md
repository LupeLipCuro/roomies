# Roomies

App Android (Flutter + Firebase) para que un grupo de roomies reparta las cuentas del depa (luz, agua, internet…).

## Qué hace

- **Registro e inicio de sesión** con **Google**, **Facebook** o correo y contraseña (nombre, correo, celular opcional).
- **Grupo de roomies**: se crea un grupo y se invita por correo. La persona invitada ve la invitación al iniciar sesión con ese correo y se une.
- **Cuentas del mes**: quien paga la factura la registra con monto, vencimiento y foto. El reparto es en **partes iguales por defecto** o por **porcentajes** definidos por quien registra (deben sumar 100%).
- **Pagos**: cada roomie ve su parte y los datos para transferir (Yape/Plin/cuenta), sube la **foto del comprobante** y queda "Por validar". Quien registró la cuenta lo **confirma o rechaza**.
- Resumen mensual: cuánto debes y cuánto te deben.

Los montos se manejan en céntimos (enteros) y el reparto siempre suma exactamente el total (ver `lib/utils/split.dart` y `test/split_test.dart`).

> La app **no mueve dinero**: solo registra y valida comprobantes de transferencias hechas fuera de la app.

## Puesta en marcha

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install) estable, un proyecto en [Firebase](https://console.firebase.google.com) y cuenta de desarrollador en [Facebook](https://developers.facebook.com).

### 1. Generar la carpeta `android/`

El repo trae solo `lib/`, `test/` y `pubspec.yaml`. Dentro de esta carpeta ejecuta:

```bash
flutter create . --platforms=android --org com.roomies --project-name roomies
flutter pub get
```

En `android/app/build.gradle(.kts)` cambia `minSdk` a `23` (lo exige Firebase).

### 2. Firebase

1. En la consola de Firebase crea un proyecto y activa **Authentication** (métodos: Correo/contraseña, **Google** y **Facebook**), **Firestore** y **Storage**.
2. Ejecuta `dart pub global activate flutterfire_cli` y luego `flutterfire configure`. Esto **reemplaza `lib/firebase_options.dart`** con tus claves reales.
3. Publica las reglas: `firebase deploy --only firestore:rules,storage` (usa `firestore.rules` y `storage.rules`).

### 3. Google Sign-In

En Firebase → Configuración del proyecto → tu app Android, agrega la huella **SHA-1** (y SHA-256) de tu keystore:

```bash
cd android && ./gradlew signingReport
```

Descarga de nuevo la configuración si Firebase te lo pide (`flutterfire configure` otra vez).

### 4. Facebook Login

1. En Facebook Developers crea una app (tipo Consumidor) y agrega el producto **Inicio de sesión con Facebook**. Copia el **App ID** y el **Client Token**.
2. En Firebase → Authentication → Google/Facebook pega el App ID y el *App Secret*, y copia la **URI de redirección OAuth** que Firebase te da a la configuración de Facebook.
3. Crea `android/app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="facebook_app_id">TU_APP_ID</string>
    <string name="facebook_client_token">TU_CLIENT_TOKEN</string>
</resources>
```

4. En `android/app/src/main/AndroidManifest.xml`, dentro de `<application>`:

```xml
<meta-data android:name="com.facebook.sdk.ApplicationId" android:value="@string/facebook_app_id"/>
<meta-data android:name="com.facebook.sdk.ClientToken" android:value="@string/facebook_client_token"/>
```

5. En Facebook Developers → Configuración → Android, registra el **nombre de paquete** (`com.roomies.roomies`) y el **hash de claves** de tu keystore.

> Mientras la app de Facebook esté en modo desarrollo, solo pueden entrar los usuarios agregados como probadores/administradores. Para uso público hay que pasar la app a modo "Live" (puede exigir verificación).

### 5. Ejecutar y compilar

```bash
flutter run
flutter test
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
```

### Compilar el APK desde GitHub

`.github/workflows/build-apk.yml` compila el APK en cada push a `main` y lo deja como artefacto descargable (pestaña **Actions**). Para que el APK funcione, primero haz los pasos 1 a 4 y **sube a git** `android/` y `lib/firebase_options.dart`.

## Estructura

```
lib/
  main.dart                 # tema y puerta de acceso (sesión -> grupo -> inicio)
  firebase_options.dart     # se genera con flutterfire configure
  models/models.dart
  services/auth_service.dart  # correo, Google, Facebook
  services/data_service.dart  # Firestore + Storage
  screens/                  # auth, grupo, inicio, nueva cuenta, detalle/pago
  utils/split.dart          # reparto en céntimos
test/split_test.dart
firestore.rules  storage.rules
```

## Pendiente / limitaciones conocidas

- Las invitaciones **no envían un correo**: quedan registradas y la persona las ve al entrar con ese correo. Para enviar correos o enlaces hace falta una Cloud Function (plan Blaze de Firebase) o un deep link.
- Un usuario pertenece a **un solo grupo**.
- Las reglas permiten que cualquier miembro actualice el estado de pagos de las cuentas del grupo; para más rigor, limita la confirmación a quien registró la cuenta (con Cloud Functions).
- Sin notificaciones push ni recordatorios automáticos todavía.
- Los botones de Google/Facebook usan íconos genéricos; para publicar en Play Store usa los logos y guías de marca oficiales.
- Este código **no se compiló ni se probó** al generarlo (no había Flutter disponible): puede requerir pequeños ajustes de versiones de paquetes.
