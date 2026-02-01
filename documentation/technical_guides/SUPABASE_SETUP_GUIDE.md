# 🦅 Manual de Vuelo: Despliegue en Supabase

Este documento es una guía paso a paso para configurar su infraestructura de backend desde cero, asumiendo **cero experiencia previa** con Supabase.

> **¿Qué es Supabase?**
> Es una plataforma "Backend como Servicio". Nos da una base de datos real (PostgreSQL), autenticación y APIs instantáneas sin tener que configurar servidores.

---

## FASE 1: Creación del Proyecto

1.  **Registro**: Vaya a [supabase.com](https://supabase.com) y haga clic en "Start your project". Puede iniciar sesión con GitHub.
2.  **Nuevo Proyecto**:
    *   Haga clic en **"New Project"**.
    *   Seleccione una organización (cree una si no tiene).
    *   **Name**: `tienda-barrio-pro`
    *   **Database Password**: **IMPORTANTE**. Genere una contraseña segura y **GUÁRDELA** en su gestor de contraseñas. La necesitaremos después para conectar la App.
    *   **Region**: Seleccione la más cercana a sus usuarios (ej: `South America (São Paulo)` o `US East (N. Virginia)`).
    *   **Plan**: Free (Gratis).
3.  **Esperar**: Tardará unos 2 minutos en provisionar la base de datos.

---

## FASE 2: Preparación del Entorno

Antes de pegar nuestro código, necesitamos habilitar herramientas especiales (Extensiones).

1.  En el menú lateral izquierdo, busque el ícono de **Database** (parecen discos apilados).
2.  En el submenú, clic en **Extensions**.
3.  Busque y habilite las siguientes extensiones (active el interruptor):
    *   `pgcrypto`: (Generalmente activa por defecto) Para encriptar PINs y contraseñas.
    *   `pg_cron`: Para tareas programadas (como limpiar sesiones viejas automáticamente).

---

## FASE 3: El Editor SQL (Tu Centro de Mando)

Aquí es donde ocurre la magia. Ejecutaremos los scripts que hemos preparado.

1.  En el menú lateral izquierdo, clic en **SQL Editor** (ícono de terminal `>_`).
2.  Clic en **"New Query"** (arriba a la izquierda). Esto abre una hoja en blanco.

### Paso 3.1: Desplegar la Arquitectura (El Plano)
1.  Abra en su computadora el archivo: `02_ARCHITECTURE/supabase-schema.sql`.
2.  Copie **TODO** el contenido (Ctrl+A, Ctrl+C).
3.  Péguelo en el editor de Supabase.
4.  Clic en el botón **"Run"** (abajo a la derecha).
5.  **Resultado Esperado**: Debería ver un mensaje `Success. No rows returned` en la parte inferior.
    *   *Nota: Si ve errores de "relation already exists", es seguro ignorarlos si está re-ejecutando.*

### Paso 3.2: Sembrar Datos (La Vida)
1.  Borre el editor de Supabase o cree una nueva query.
2.  Abra en su computadora: `tests/sql/00_seed_data.sql`.
3.  Copie y Pegue.
4.  Clic en **"Run"**.
5.  **Resultado**: Ahora su base de datos tiene 1 tienda, 3 empleados y 50 productos.

---

## FASE 4: Verificación (El Check-Up)

Vamos a confirmar que todo funciona como un reloj suizo.

1.  Nueva Query en Supabase.
2.  Abra: `tests/sql/03_stress_rpc.sql` (Prueba de Venta).
3.  Copie, Pegue y **Run**.
4.  **Busque en la salida**: Debería leer mensajes que comienzan con `NOTICE:`. Busque `=== TEST RPC VENTA EXITOSO ===`.

---

## FASE 5: Conexión con la App (El Puente)

Para que su código Frontend (`03_SRC`) "hable" con Supabase, necesita 2 llaves.

1.  Vaya a **Project Settings** (ícono de engranaje ⚙️, abajo a la izquierda).
2.  Clic en **API**.
3.  Copie estos dos valores y téngalos a mano:
    *   **Project URL**: (Algo como `https://xyzxyz.supabase.co`)
    *   **anon public**: (Una cadena larga de caracteres `eyJ...`).

¡Listo! Su backend ("Headless") está vivo, seguro y operando.
