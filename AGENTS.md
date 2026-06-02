# kiosco_app — AGENTS.md

Proyecto Flutter: gestión de kiosco escolar. Sin state management, sin router, sin codegen.

## Stack

- Flutter + Dart (Material 3)
- SQLite (`sqflite` + `sqflite_common_ffi` en Windows)
- `shared_preferences` para tema oscuro y lockout de login
- `fl_chart` para gráficos
- `crypto` (SHA-256) para hash de contraseñas

## Arquitectura

- **Sin state management framework** — todo es `StatefulWidget` + `setState`.
- `DatabaseHelper.instance` — singleton que extiende `ChangeNotifier` (pero no se usa como tal, solo como singleton). Toda la lógica de BD vive ahí.
- `ThemeProvider.instance` — singleton `ChangeNotifier` escuchado con `ListenableBuilder` en `main.dart`.
- UI en español (rioplatense con voseo). No mezclar con inglés.
- Sin `go_router` ni navegación declarativa — usa `Navigator.pushReplacement` directo.

## Entrypoints

- `lib/main.dart` → `LoginScreen` → `HomeScreen` (NavigationBar con 6 tabs)
- 6 tabs: Dashboard, Ventas, Estudiantes, Productos, Reportes, Pendientes

## Comandos

```sh
# Correr en Windows
flutter run -d windows

# Correr en Chrome
flutter run -d chrome

# Análisis estático
flutter analyze

# Tests existentes (son stale — ver abajo)
flutter test
```

## Database

- Versión actual: **5**. Si se agregan columnas/tablas, incrementar versión y agregar caso en `_onUpgrade`.
- En Windows requiere `sqfliteFfiInit()` + `databaseFactory = databaseFactoryFfi` (ya resuelto en `_initDB`).
- Fecha en formato `dd/mm/yyyy` (no ISO) en sales/pending.
- Admin por defecto: `admin` / `admin123`.

## Gotchas

- **Tests stale**: `widget_test.dart` es el default counter test de Flutter, no testea nada del proyecto real.
- **`print(bestProduct)`**: leftover de debug en `reports_screen.dart:123`. Sacar si se toca ese archivo.
- **Login lockout**: 3 intentos → 30 seg, 5+ → 2 min. Persiste en SharedPreferences.
- **Recreo**: hora 10 → Recreo 1, hora 12:20+ → Recreo 2.
- **Iconos de productos**: mapeo string → IconData en `services/product_icons.dart`. Usar `getIcon()`.
- **`ListenableBuilder`** en main.dart — **no usar** `Consumer`/`Provider`/`context.watch` para el theme.
- **Sin `build_runner`**, sin generación de código, sin inyección de dependencias.

## Recordatorio post-sesión

Al finalizar cada sesión de trabajo, recordar al usuario hacer:
```bash
git add .
git commit -m "tipo: descripción del cambio"
git push
```
