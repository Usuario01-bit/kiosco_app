# 📱 Manual de Usuario — Kioscoapp v1.0.0

**Fecha:** Junio 2026  
**Versión:** 1.0.0  
**Páginas:** 16

---

## 📑 Índice
1. [Introducción](#1-introducción)
2. [Acceso a la App](#2-acceso-a-la-app)
3. [Panel Principal (Dashboard)](#3-panel-principal-dashboard)
4. [Ventas — Proceso de Venta](#4-ventas--proceso-de-venta)
5. [Pedidos del Día](#5-pedidos-del-día)
6. [Estudiantes — Gestión](#6-estudiantes--gestión)
7. [Productos — Catálogo](#7-productos--catálogo)
8. [Reportes](#8-reportes)
9. [Pendientes — Gestión de Deudas](#9-pendientes--gestión-de-deudas)
10. [Portal del Estudiante](#10-portal-del-estudiante)
11. [Administración — Usuarios y Roles](#11-administración--usuarios-y-roles)
12. [Descargar la App (QR)](#12-descargar-la-app-qr)
13. [Preguntas Frecuentes](#13-preguntas-frecuentes)

---

## 1. Introducción

Kioscoapp es un sistema de gestión para kioscos escolares. Permite:
- Administrar ventas y productos
- Registrar pedidos de estudiantes con múltiples métodos de pago
- Gestionar deudas pendientes (fiado)
- Generar reportes y exportar a Excel
- Acceso para estudiantes vía QR

**Roles del sistema:**
| Rol | Permisos |
|-----|----------|
| **Super Admin** | Acceso total: ventas, productos, estudiantes, reportes, pendientes, gestionar administradores |
| **Administrador** | Igual que Super Admin, puede gestionar otros admins |
| **Vendedor** | Acceso limitado a ventas y pedidos del día |

---

## 2. Acceso a la App

### 2.1 Login de Administrador

1. Abrí la app. Verás la pantalla de inicio.
2. Ingresá tu **usuario** y **contraseña**.
3. Presioná **Ingresar**.

> ⚠️ **Importante:** Cambiá la contraseña en tu primer inicio de sesión (Configuración → Cambiar contraseña).

### 2.2 Portal del Alumno

Los estudiantes tienen dos formas de acceder:

**Opción A — Nombre y Contraseña:**
1. En la pantalla principal, tocá **Portal del Alumno**.
2. Empezá a escribir tu nombre (autocompletado).
3. Ingresá tu **contraseña temporal** (dada por el administrador).
4. Tocá **Ingresar**.

**Opción B — Escanear QR (más rápido):**
1. Tocá **Escanear QR para entrar**.
2. Apuntá la cámara al QR que te muestra el administrador.
3. Entrás directo a la tienda.

---

## 3. Panel Principal (Dashboard)

Al iniciar sesión como administrador, verás:
- **Ventas totales** del día
- **Deuda pendiente** acumulada
- **Ventas semanales** (gráfico de barras)
- **Últimas ventas** realizadas
- **Productos más vendidos**

El botón flotante 🧾 muestra los **pedidos del día sin entregar**. Podés arrastrarlo a cualquier parte de la pantalla.

---

## 4. Ventas — Proceso de Venta

### 4.1 Registrar una Venta

1. Andá a la pestaña **Ventas**.
2. Buscá al estudiante escribiendo su nombre.
3. Seleccioná los productos y cantidades.
4. Elegí el **método de pago**:
   - 💵 **Efectivo**
   - 📱 **Yappy**
   - ⏳ **Pendiente (fiado)**
5. Tocá **Registrar Venta**.

### 4.2 Notificación de Pedido Nuevo

Cuando un estudiante hace un pedido desde el portal, tu celular **vibra** y el badge rojo del botón flotante se actualiza con la cantidad de estudiantes que tienen pedidos pendientes.

---

## 5. Pedidos del Día

### 5.1 Ver Pedidos

Tocá el botón flotante 🧾 para ver todos los pedidos del día, agrupados por recreo:
- **Recreo 1** (10:00 AM)
- **Recreo 2** (12:20 PM)
- **Salida** (2:00 PM)

### 5.2 Entregar y Cobrar

1. Buscá al estudiante en su recreo correspondiente.
2. Tocá **Entregar y cobrar**.
3. Seleccioná cómo pagó:
   - 💵 **Efectivo**
   - 📱 **Yappy**
   - 🟠 **Pendiente (fiado)** — se registra como deuda
4. El pedido se marca como entregado y desaparece del badge.

### 5.3 Badge de Método de Pago

Cada estudiante muestra badges de colores según su método de pago:
- 🟢 **Efectivo**
- 🔵 **Yappy**
- 🟠 **Pendiente**

---

## 6. Estudiantes — Gestión

### 6.1 Ver Estudiantes

Andá a la pestaña **Estudiantes**. Aparecen agrupados por **grado** (1° a 12°). Los estudiantes sin grado asignado aparecen al final.

### 6.2 Agregar Estudiante

1. Tocá el botón **+** (esquina inferior derecha).
2. Completá:
   - **Nombre y apellido**
   - **Rol** (Alumno / Profesor / Otro)
   - **Grado** (solo para alumnos)
3. El sistema genera una **contraseña temporal** automática.
4. Tocá **Agregar**.

### 6.3 Importar desde Excel

1. Tocá el botón de **importar** 📥.
2. Seleccioná el archivo Excel con las columnas: Nombre, Grado, Rol.
3. Los estudiantes se agregan automáticamente.

### 6.4 Generar QR del Estudiante

1. Buscá al estudiante en la lista.
2. Tocá el ícono **QR** junto a su nombre.
3. Se muestra el QR que el estudiante puede escanear para ingresar a la app.

---

## 7. Productos — Catálogo

### 7.1 Ver Productos

Andá a la pestaña **Productos**. Se muestran agrupados por categoría:
- ☕ Café
- 🥤 Bebidas
- 🍞 Emparedados
- 🥟 Empanadas
- 🍦 Duros
- 🍽️ Especiales

### 7.2 Agregar Producto

1. Tocá el botón **+**.
2. Completá: **Nombre**, **Precio**, **Stock**, **Categoría**, **Ícono**.
3. Tocá **Guardar**.

### 7.3 Editar / Eliminar

Deslizá un producto hacia la izquierda para ver opciones de **editar** o **eliminar**.

---

## 8. Reportes

### 8.1 Panel de Reportes

En la pestaña **Reportes** podés ver:
- **Ventas del día** — comparativo Recreo 1 vs Recreo 2
- **Top productos** más vendidos
- **Deudores** — estudiantes con saldo pendiente
- **Últimas ventas** registradas

### 8.2 Exportar a Excel

1. Tocá el botón **Exportar** 📤.
2. Elegí qué exportar: Ventas, Productos, Pendientes, o Estudiantes.
3. Se genera un archivo Excel que podés compartir por WhatsApp, correo, etc.

---

## 9. Pendientes — Gestión de Deudas

### 9.1 Ver Deudas

Andá a la pestaña **Pendientes**. Muestra todos los estudiantes con saldo pendiente (deuda > 0).

### 9.2 Abonar (Pago Parcial)

1. Tocá **Abonar** en el estudiante.
2. Ingresá el monto que está pagando.
3. La deuda se reduce automáticamente.

### 9.3 Pagar Deuda Completa

1. Tocá **Pagar**.
2. La deuda se marca como saldada y desaparece de la lista.

### 9.4 ¿Cómo se genera una deuda?

Cuando un administrador selecciona **"Pendiente (fiado)"** al entregar un pedido, el monto se registra como deuda del estudiante. El estudiante puede ir pagando de a poco (abonar) hasta saldar el total.

---

## 10. Portal del Estudiante

### 10.1 Iniciar Sesión

Desde la pantalla principal, tocá **Portal del Alumno** y elegí tu método de acceso (nombre/contraseña o QR).

### 10.2 Comprar Productos

1. Navegá por las categorías de productos.
2. Tocá **+** para agregar al carrito.
3. Tocá el ícono del **carrito** 🛒 para ir al checkout.

### 10.3 Confirmar Pedido

1. Seleccioná en qué **recreo** retirás.
2. Elegí cómo vas a pagar: **Efectivo**, **Yappy**, o **Pendiente**.
3. Tocá **Confirmar pedido**.

### 10.4 Ver Mi QR

Tocá el ícono QR en la esquina superior para mostrar tu código QR personal.

### 10.5 Cerrar Sesión

Tocá el ícono 🚪 en la esquina superior derecha para cerrar sesión.

---

## 11. Administración — Usuarios y Roles

### 11.1 Gestionar Administradores

1. Andá a **Configuración** ⚙️ (esquina inferior derecha del panel principal).
2. Seleccioná **Gestionar administradores**.

### 11.2 Agregar Usuario

1. Tocá el botón **+**.
2. Ingresá: **Usuario**, **Contraseña**, y **Rol**.
3. Roles disponibles:
   - **Administrador** — acceso completo
   - **Vendedor** — acceso a ventas y pedidos del día
4. Tocá **Agregar**.

### 11.3 Eliminar Usuario

Deslizá un usuario hacia la izquierda y tocá **Eliminar**.  
> ⚠️ No se puede eliminar al Super Admin.

### 11.4 Cambiar Contraseña

1. Andá a **Configuración** → **Cambiar contraseña**.
2. Ingresá tu contraseña actual y la nueva.
3. La nueva debe tener mínimo 8 caracteres.

---

## 12. Descargar la App (QR)

### 12.1 Para Administradores

En la pantalla de login principal, abajo verás un QR pequeño con el texto "¿No tenés la app?".

1. **Tocá el QR** para verlo en pantalla completa (más grande y fácil de escanear).
2. Mostrale este QR a los estudiantes para que lo escaneen.
3. Al escanear, se abre una página con dos botones:
   - 🤖 **Descargar para Android**
   - 🍎 **Descargar para iOS** (próximamente)

### 12.2 Actualizar la App

Cuando haya una versión nueva:
1. El administrador compila el APK nuevo.
2. Lo sube a GitHub Releases.
3. Los estudiantes escanean el mismo QR y descargan la versión actualizada.

---

## 13. Preguntas Frecuentes

**P: ¿Qué hago si un estudiante olvidó su contraseña?**  
R: Andá a la pantalla de Estudiantes, buscá al alumno, y tocá el botón de generar nueva contraseña temporal.

**P: ¿Puedo usar la app sin internet?**  
R: El catálogo de productos se guarda localmente. Pero para hacer ventas y sincronizar necesitás conexión.

**P: ¿Qué pasa si cierro la app sin guardar?**  
R: Las ventas se guardan automáticamente al confirmar. Si estás en medio de una venta y cerrás, se pierde.

**P: ¿Cómo agrego un nuevo recreo?**  
R: Andá a Configuración → Ajustes del kiosco → Recreos. Podés modificar horarios y nombres.

**P: ¿Puedo ver las ventas de días anteriores?**  
R: Sí, en la pestaña Reportes podés filtrar por fecha o exportar todo a Excel.
