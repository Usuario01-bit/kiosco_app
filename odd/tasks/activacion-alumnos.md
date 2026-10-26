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
