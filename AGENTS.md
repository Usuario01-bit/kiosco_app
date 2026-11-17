# kiosco_app — AGENTS.md

Proyecto Flutter: gestión de kiosco escolar. Sin state management, sin router, sin codegen.

## Stack

- Flutter + Dart (Material 3)
- **Supabase** (`supabase_flutter`) — backend, auth, BD en la nube
- `shared_preferences` para tema oscuro y lockout de login
- `fl_chart` para gráficos
- `crypto` (SHA-256) para hash de contraseñas
- `mobile_scanner` + `qr_flutter` para QR
- `excel` + `share_plus` + `file_picker` para import/export

## Arquitectura

- **Sin state management framework** — todo es `StatefulWidget` + `setState`.
- `SupabaseService.instance` — singleton. Toda la lógica de BD (CRUD, streams, auth) vive ahí.
- `StoreConfig.instance` — singleton que lee la config del kiosco desde Supabase (tabla `store_config`).
- `ThemeProvider.instance` — singleton `ChangeNotifier` escuchado con `ListenableBuilder` en `main.dart`.
- UI en español (rioplatense con voseo). No mezclar con inglés.
- Sin `go_router` ni navegación declarativa — usa `Navigator.pushReplacement` directo.

## Entrypoints

- `lib/main.dart` → `LoginScreen` → `HomeScreen` (NavigationBar con 6 tabs)
- 6 tabs: Dashboard, Ventas, Estudiantes, Productos, Reportes, Pendientes

## Comandos

```sh
# Compilar el APK release (target real: se instala a mano en el celular)
flutter build apk --release

# Correr en Chrome (solo para chequear UI rápido)
flutter run -d chrome

# Análisis estático
flutter analyze

# Tests
flutter test
```

No usar `flutter build windows`: no hay toolchain de Visual Studio en la máquina y el target real es Android.

## Publicar una versión

Ver `RELEASE.md`. Resumen: subir `version` en `pubspec.yaml` (versionCode +1) → `flutter build apk --release` → commit/tag/push → crear el release con la API y el asset `app-release.apk` → llevar `docs/index.html` a `master` (Pages sirve `master`/`docs`).

## Database

- Supabase PostgreSQL. Sin migraciones locales — el schema se maneja en la consola de Supabase.
- `SupabaseService.instance` singleton para toda interacción con BD.
- Fecha en formato ISO `yyyy-MM-dd` en `sales`/`pending` (helper `toISODate()`). La `dd/mm/yyyy` es solo de presentación.
- Admin por defecto: `admin` / `admin123`.

## Gotchas

- **Tests**: `test/` tiene tests reales de lógica (`recreo_schedule_test.dart`, `date_utils_test.dart`, `product_image_picker_test.dart`). No hay tests de widgets de pantallas.
- **`print(bestProduct)`**: leftover de debug en `reports_screen.dart:123`. Sacar si se toca ese archivo.
- **Login lockout**: 3 intentos → 30 seg, 5+ → 2 min. Persiste en SharedPreferences.
- **Recreo**: hora 10 → Recreo 1, hora 12:20+ → Recreo 2.
- **Iconos de productos**: mapeo string → IconData en `services/product_icons.dart`. Usar `getIcon()`.
- **`ListenableBuilder`** en main.dart — **no usar** `Consumer`/`Provider`/`context.watch` para el theme.
- **Sin `build_runner`**, sin generación de código, sin inyección de dependencias.
- **`toISODate()`**: helper en `services/date_utils.dart`. Usar para fechas ISO (`yyyy-MM-dd`) en queries a Supabase.
- **`streamActiveOrdersCount`**: filtra por `prepared_at.isNull`, NO por `paid_at`. Una orden "Pendiente" (fiado) queda con `prepared_at` seteado solo cuando el kiosco la marca como preparada.
- **`store_config`**: tabla en Supabase con config del kiosco. Leída por `StoreConfig.instance`.

## Recordatorio post-sesión

Al finalizar cada sesión de trabajo, recordar al usuario hacer:
```bash
git add .
git commit -m "tipo: descripción del cambio"
git push
```
