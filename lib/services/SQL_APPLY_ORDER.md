# SQL de Supabase — orden de aplicación

Los archivos de `lib/services/*.sql` **no son una biblioteca**: son migraciones
históricas que se corrían a mano en el SQL Editor. Varias funciones fueron
reescritas por archivos posteriores, y las versiones viejas siguen en el repo.

Regla: **correr en el orden de esta tabla y nunca volver a correr un archivo
superseded**. Correr uno viejo revierte el hardening en silencio, sin error y
sin aviso.

## Orden

| # | Archivo | Qué aporta hoy |
|---|---|---|
| 1 | `supabase_security.sql` | Extensiones (`pgcrypto`) y el trigger `hash_student_password_trigger`. El resto está superseded |
| 2 | `fix_rls.sql` | Nada: superseded |
| 3 | `fix_rls_security.sql` | `search_student_names`, `get_product_catalog`, `get_student_by_token` |
| 4 | `fix_admin_roles.sql` | `create_admin_user` |
| 5 | `qr_token_rpc.sql` | Solo `clear_student_qr_token` |
| 6 | `payment_captures.sql` | Nada: superseded |
| 7 | `hardening_security.sql` | `is_admin` estricta, `_student_token_ok`, `get_student_by_code`, `get_student_sales`, `get_student_debt`, `submit_payment_capture`, `get_student_captures`, bucket de capturas y el cron de TTL |
| 8 | `checkout_hardening.sql` | `student_checkout` con token y cantidades validadas |
| 9 | `payment_captures_private.sql` | Bucket privado + URLs firmadas |
| 10 | `login_rate_limit.sql` | `verify_student` con rate limit y `needs_activation`, `set_student_qr_token` con el mismo contador |
| 11 | `student_activation.sql` | `admin_generate_activation`, `activate_student`, `is_admin` estricta, drop de los RPC viejos, revoke de `upsert_pending` |
| — | `first_login.sql` | Nada: retirado. Correrlo ya no recrea el flujo viejo |
| — | `upsert_pending.sql` | Nada: función revocada |

## Fuente vigente por función

| Función | Archivo vigente | Archivos que la revierten |
|---|---|---|
| `verify_student` | `login_rate_limit.sql` | `supabase_security.sql` (ya removida) |
| `student_checkout` | `checkout_hardening.sql` | `supabase_security.sql`, `fix_student_checkout.sql` |
| `submit_payment_capture`, `get_student_captures` | `hardening_security.sql` | `payment_captures.sql` |
| `set_student_qr_token` | `login_rate_limit.sql` | `qr_token_rpc.sql` |
| `is_admin` | `student_activation.sql` | `fix_rls.sql`, `supabase_security.sql` |
| `create_admin_user` | `fix_admin_roles.sql` | `supabase_security.sql` |
| `get_student_initial_code`, `set_student_password` | no debe existir | `first_login.sql` (ahora dropea en vez de crear) |
| `upsert_pending` | revocada | `upsert_pending.sql` |

## Estado del servidor

Verificado por RPC el 2026-10-26: cada función vigente responde con el
comportamiento endurecido. Este documento es sobre el repo, no sobre la base.
