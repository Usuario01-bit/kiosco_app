# Activación de alumnos — cierre de la cadena de toma de cuenta

Branch: `feat/activacion-alumnos` · Delivery: single-pr · Test runner: `flutter analyze` (no hay runner de integración contra Supabase)

Objetivo: que el primer ingreso pruebe identidad sin romper el flujo de compras, historial ni deuda.

## Specs

- **S1** El código de activación se guarda hasheado (bcrypt) y vence a los 15 minutos. Nunca en texto plano.
- **S2** Solo un admin puede generar un código. El código se devuelve una única vez, en la respuesta del RPC.
- **S3** El alumno activa con `nombre + código + contraseña nueva` (mínimo 8 caracteres). 5 intentos fallidos queman el código.
- **S4** Los errores no distinguen "alumno inexistente" de "código inválido" (mismo mensaje para ambos).
- **S5** `get_student_initial_code` y `set_student_password` dejan de existir. La app no puede obtener el código en ningún caso.
- **S6** La pantalla de primer ingreso pide el código tipeado. El login normal (nombre + contraseña) queda igual.
- **S7** El panel de alumnos tiene un botón "Activar" que muestra el código en 6 dígitos y su QR.
- **S8** Compra, historial, deuda y comprobantes de pago no cambian de comportamiento.

## Tasks

- [ ] T1 — `lib/services/student_activation.sql`: columnas hash/vencimiento/intentos, `admin_generate_activation`, `activate_student`, drop de los RPC viejos (S1-S5)
- [ ] T2 — `supabase_service.dart`: `activateStudent`, `adminGenerateActivation`, `ActivationException`; fuera `getStudentInitialCode` e `initial_code` del import (S3, S5)
- [ ] T3 — `student_login_screen.dart`: campo de código + entrada a primer ingreso (S6)
- [ ] T4 — `students_screen.dart`: botón Activar con código + QR (S7)
- [ ] T5 — `flutter analyze` y commit

## Log

- **L1** (usuario): "si vamos a solucionar sin dañar la app"
- **L2** (usuario): "ok y si el estudiante recien descarga la app ejemplo Senastian antonio le sale primer ingeso crea tu contraseña para entrar el crea su propia contraseña"
- **L3** (usuario): "me parece mejor" — se elige activación única en el kiosco, código de 6 dígitos + QR, vencimiento 15 min.
- **L4** (orquestador): se descarta el auto-fetch del código porque cualquier secreto entregado por un canal anónimo no es secreto. El flujo de auto-registro por nombre deja la cuenta al primero que llega.
- **L5** (2026-10-26, producción): se aplicaron `student_activation.sql`, `checkout_hardening.sql`, `payment_captures_private.sql` y `login_rate_limit.sql`. Verificado por RPC: `activate_student` consume el código, hashea la contraseña, baja `must_change_password` y registra `activation_claimed_at`. Rate limit bloquea a los 5 intentos.
- **L6** (2026-10-26, bug propio): `SET search_path = 'public, extensions'` se interpreta como un único esquema literal, así que `crypt`/`gen_salt` no resolvían y dejaron login y activación rotos. Corregido a `'public'` y además calificado como `public.crypt` / `public.gen_salt`.
- **L7** (2026-10-26, abierto): en la app 1.4.4 el usuario reporta que el login no lo deja llegar al formulario de primer ingreso ("Nombre o contraseña incorrectos" en vez de los campos de código). El backend está validado por RPC, así que el problema está en la navegación de `student_login_screen`. Sin confirmar si el botón "¿Primer ingreso?" renderiza.
- **L8** (2026-10-26): L7 diagnosticado. El link azul sí renderiza y sí está en el APK 1.4.4 (verificado leyendo los strings del `libapp.so` del release), así que el alumno simplemente aprieta "Ingresar" y cae en el error genérico. Fix: `verify_student` devuelve `{"status":"needs_activation"}` y la app cambia sola al formulario de activación. La señal correcta NO es `temp_password IS NULL` (toda alta escribe un `temp_password` aleatorio que nadie conoce) sino `must_change_password IS TRUE`, el mismo flag que usa el badge "Sin configurar" del panel.
- **L9** (2026-10-26, producción): `login_rate_limit.sql` aplicado y release v1.4.6 publicado con el APK. Verificado en dispositivo con los dos casos: Arminda (sin contraseña) cae en el formulario de activación; Carlos Viveros (ya activo) entra normal. Incluye además el fix del botón "Volver" del portal (quedaba en negro tras Cerrar sesión) y el modo oscuro del login de admin.

## Estado al 2026-10-26

Cerrado y verificado en producción:

| Hallazgo | Estado |
|---|---|
| Toma de cuenta por código en texto plano | cerrado, RPC verificado |
| `student_checkout` sin token | cerrado |
| Cantidades negativas en checkout | cerrado |
| `upsert_pending` expuesto a anon | revocado |
| Bucket de comprobantes público | privado + URLs firmadas |
| Fuerza bruta en login y en QR | rate limit activo |

Pendiente:

- **UI de primer ingreso**: verificada en dispositivo (Arminda) y regresión de login normal (Carlos Viveros) OK.
- Probar compra con QR, badge de comprobantes y carga de imágenes firmadas.
- Decisión de negocio: `p_payment_method` y `p_date` los manda el alumno.
- Contraste del botón "Portal del Alumno" sobre la tarjeta oscura (`Color(0xFF2563EB)` fijo; candidato a `colorScheme.primary`).

