# SPEC-012: Estrategia de Verificación de Backend (Supabase)

> **Documento de Requisitos Funcionales (FRD)**  
> Versión: 2.0 (Consolidada)  
> Fecha: 2026-01-20  
> Estado: ✅ **Aprobado por Data y QA**

---

## Descripción

Este documento define la estrategia para configurar, desplegar y verificar el correcto funcionamiento del backend en Supabase **antes de conectar el frontend**. El objetivo es asegurar que:

1. El proyecto de Supabase esté correctamente configurado
2. El schema de base de datos esté desplegado
3. Los triggers, RPCs y RLS funcionen según lo documentado
4. Existan datos de prueba para validar flujos

---

## Prerrequisitos (Antes de Ejecutar)

### Estado del Schema Actual

| Componente | Estado | Notas |
|------------|--------|-------|
| Tablas base | ✅ Definidas | 13+ tablas en schema |
| Triggers | ✅ Definidos | `update_product_stock`, `update_timestamp` |
| RLS Policies | ✅ Definidas | Aislamiento por `store_id` |
| RPCs Autenticación | ⚠️ Parcial | Ver tabla abajo |
| RPCs Operaciones | ⚠️ Parcial | Ver tabla abajo |

### Funciones RPC: Estado de Completitud

| Función | Estado | Prerrequisito |
|---------|--------|---------------|
| `login_empleado_unificado()` | ✅ Existe | - |
| `crear_empleado()` | ✅ Existe | - |
| `cambiar_pin()` | ✅ Existe | - |
| `get_server_timestamp()` | ✅ Existe | SPEC-011 |
| `retry_failed_sync()` | ✅ Existe | SPEC-011 |
| `procesar_venta()` | ❌ Faltante | Crear antes de Fase 3 |
| `establecer_pin_admin()` | ❌ Faltante | Crear antes de Fase 3 |
| `validar_pin_admin()` | ❌ Faltante | Crear antes de Fase 3 |
| `registrar_evento_caja()` | ❌ Faltante | Crear antes de Fase 3 |

> **Acción requerida:** Completar las 4 funciones faltantes en `supabase-schema.sql` antes de ejecutar la Fase 3.

---

## Fases de Implementación

```
┌─────────────────────────────────────────────────────────────┐
│                    ESTRATEGIA DE BACKEND                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  FASE 1          FASE 2          FASE 3          FASE 4    │
│  ┌──────┐        ┌──────┐        ┌──────┐        ┌──────┐  │
│  │SETUP │  ───▶  │DEPLOY│  ───▶  │VERIFY│  ───▶  │ SEED │  │
│  │      │        │      │        │      │        │      │  │
│  └──────┘        └──────┘        └──────┘        └──────┘  │
│                                                             │
│  Crear           Ejecutar        Probar          Crear     │
│  proyecto        schema          cada            datos     │
│  Supabase        SQL             componente      demo      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Fase 1: Setup del Proyecto Supabase

### Objetivo
Crear el proyecto en Supabase y obtener las credenciales necesarias.

### Pasos

| # | Acción | Resultado Esperado |
|---|--------|-------------------|
| 1.1 | Ir a [supabase.com](https://supabase.com) | Página de inicio |
| 1.2 | Crear cuenta o iniciar sesión | Dashboard de Supabase |
| 1.3 | Click "New Project" | Formulario de creación |
| 1.4 | Elegir organización | - |
| 1.5 | Nombre: `tienda-barrio-pro` | - |
| 1.6 | Contraseña de DB: (guardar en lugar seguro) | - |
| 1.7 | Región: Más cercana (ej: `South America - São Paulo`) | - |
| 1.8 | Plan: Free tier | Proyecto creándose (~2 min) |

### Credenciales a Obtener

| Credencial | Ubicación en Dashboard | Para qué sirve |
|------------|------------------------|----------------|
| **Project URL** | Settings → API | URL base para peticiones |
| **anon key** | Settings → API | Clave pública (frontend) |
| **service_role key** | Settings → API | Clave privada (solo backend/testing) |
| **Database Password** | La que elegiste | Conexión directa a PostgreSQL |

> ⚠️ **SEGURIDAD:** La `service_role key` tiene **acceso total** a la base de datos, ignorando RLS. **Nunca** commitear en repositorio. Usar `.env.local` y agregar a `.gitignore`.

### Criterio de Éxito Fase 1
- [ ] Proyecto creado y activo (status verde)
- [ ] Las 4 credenciales guardadas en archivo seguro
- [ ] SQL Editor accesible desde el Dashboard

---

## Fase 2: Deploy del Schema

### Objetivo
Ejecutar el script `supabase-schema.sql` para crear toda la estructura de la base de datos.

### Pasos

| # | Acción | Resultado Esperado |
|---|--------|-------------------|
| 2.1 | Abrir SQL Editor en Dashboard | Editor listo |
| 2.2 | Copiar contenido de `02_ARCHITECTURE/supabase-schema.sql` | - |
| 2.3 | Pegar en SQL Editor | Código visible |
| 2.4 | Click "Run" | "Success. No rows returned" (OK) |
| 2.5 | Si hay error, leer mensaje y corregir | - |

### Verificación Post-Deploy

| Verificación | Cómo hacerlo | Resultado Esperado |
|--------------|--------------|-------------------|
| Tablas creadas | Table Editor → Ver lista | 13+ tablas visibles |
| Triggers activos | Database → Triggers | `trg_inventory_movement`, etc. |
| Funciones/RPCs | Database → Functions | `login_empleado_unificado`, `crear_empleado`, etc. |
| RLS habilitado | Authentication → Policies | Políticas por tabla |

### Criterio de Éxito Fase 2
- [ ] Schema ejecutado sin errores
- [ ] Todas las tablas visibles en Table Editor
- [ ] Triggers y funciones listados en Database

---

## Fase 3: Verificación de Componentes

### Objetivo
Probar que cada componente del backend funciona correctamente usando el SQL Editor.

### 3.1 Prueba de Tablas (Estructura)

**Query de verificación:**
```sql
-- Listar todas las tablas del proyecto
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_name;
```

**Resultado esperado:** Lista de tablas incluyendo:
- `stores`, `employees`, `products`, `sales`, `sale_items`
- `clients`, `expenses`, `cash_register`, `inventory_movements`
- `access_requests`, `sync_queue_failed`

---

### 3.2 Prueba de Triggers (Actualización de Stock)

**Insertar movimiento y verificar que trigger actualiza stock:**

```sql
-- 1. Crear tienda de prueba
INSERT INTO stores (id, name) VALUES 
  ('00000000-0000-0000-0000-000000000001', 'Tienda Test');

-- 2. Crear producto con stock inicial 0
INSERT INTO products (id, store_id, name, plu, price, current_stock) VALUES 
  ('00000000-0000-0000-0000-000000000002', 
   '00000000-0000-0000-0000-000000000001', 
   'Producto Test', '0001', 1000, 0);

-- 3. Insertar entrada de inventario (10 unidades)
INSERT INTO inventory_movements (product_id, movement_type, quantity) VALUES 
  ('00000000-0000-0000-0000-000000000002', 'entrada', 10);

-- 4. Verificar que stock se actualizó automáticamente
SELECT name, current_stock FROM products 
WHERE id = '00000000-0000-0000-0000-000000000002';
```

**Resultado esperado:** `current_stock = 10`

---

### 3.3 Prueba de RPC: Login Empleado

**Crear empleado y probar login:**

```sql
-- 1. Crear empleado con PIN hasheado
SELECT crear_empleado(
  '00000000-0000-0000-0000-000000000001',  -- store_id
  'Juan Vendedor',                          -- name
  'juan',                                   -- username
  '1234',                                   -- pin
  '{"canSell": true}'::jsonb                -- permissions
);

-- 2. Probar login con credenciales correctas
SELECT login_empleado_unificado(
  'juan',                    -- username
  '1234',                    -- pin
  null,                      -- device_fingerprint (null para test)
  'SQL Editor Test'          -- user_agent
);

-- 3. Probar login con PIN incorrecto
SELECT login_empleado_unificado('juan', '0000', null, 'Test');
```

**Resultado esperado:**
- Creación: `{"success": true, "employee_id": "..."}`
- Login correcto: `{"success": true, "employee": {...}}`
- Login incorrecto: `{"success": false, "error": "Credenciales inválidas..."}`

---

### 3.4 Prueba de RPC: Procesar Venta

**Simular una venta completa:**

```sql
-- Procesar venta (requiere producto con stock)
SELECT procesar_venta(
  '00000000-0000-0000-0000-000000000001',  -- store_id
  '[{"product_id": "00000000-0000-0000-0000-000000000002", "quantity": 2, "price": 1000, "subtotal": 2000}]'::json,
  'cash',                                   -- payment_method
  2500,                                     -- amount_received
  null,                                     -- client_id
  null                                      -- employee_id (puede ser null en test)
);

-- Verificar que stock bajó
SELECT name, current_stock FROM products 
WHERE id = '00000000-0000-0000-0000-000000000002';
```

**Resultado esperado:**
- Venta: `{"success": true, ...}` o error de stock si no hay suficiente
- Stock: Debería haber bajado de 10 a 8

---

### 3.5 Prueba de RLS (Seguridad)

**Verificar que RLS está activo:**

```sql
-- Ver qué tablas tienen RLS habilitado
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND rowsecurity = true;
```

**Resultado esperado:** Lista de tablas con RLS activo

**Prueba de aislamiento (RLS Negativo):**

```sql
-- 1. Crear segunda tienda para probar aislamiento
INSERT INTO stores (id, name) VALUES 
  ('00000000-0000-0000-0000-000000000099', 'Tienda Ajena');

-- 2. Intentar ver productos de la Tienda Test desde contexto de Tienda Ajena
-- (En producción, RLS bloqueará esto automáticamente)
-- Aquí verificamos que las políticas están configuradas correctamente:
SELECT COUNT(*) FROM products 
WHERE store_id = '00000000-0000-0000-0000-000000000001';
-- Debe retornar registros solo si ejecutas como service_role (bypass RLS)
-- Con usuario normal, debería retornar 0 o error de permisos
```

**Resultado esperado:** RLS bloquea acceso entre tiendas

---

### 3.6 Prueba de Control de Caja

**Probar apertura y cierre de caja:**

```sql
-- 1. Primero crear PIN de admin (si no existe)
SELECT establecer_pin_admin(
  '00000000-0000-0000-0000-000000000001', 
  '123456'
);

-- 2. Validar PIN
SELECT validar_pin_admin(
  '00000000-0000-0000-0000-000000000001', 
  '123456'
);

-- 3. Registrar apertura de caja
SELECT registrar_evento_caja(
  '00000000-0000-0000-0000-000000000001',
  'open',
  50000,
  'Admin Test',
  'admin'
);
```

**Resultado esperado:** `{"success": true, ...}`

---

### Criterio de Éxito Fase 3
- [ ] Tablas: Query lista 13+ tablas
- [ ] Trigger: Stock se actualiza automáticamente
- [ ] Login: RPC responde correctamente a credenciales válidas/inválidas
- [ ] Venta: RPC procesa venta y actualiza stock
- [ ] RLS: Tablas principales tienen seguridad activa
- [ ] Caja: RPCs de PIN y eventos funcionan

---

## Fase 4: Seed Data (Datos de Demostración)

### Objetivo
Crear un conjunto de datos realistas para pruebas manuales y demos.

### Datos a Crear

| Entidad | Cantidad | Propósito |
|---------|----------|-----------|
| Tienda | 1 | Tienda demo principal |
| Empleados | 2 | Admin + Vendedor con diferentes permisos |
| Productos | 5 | Variedad: pesables y por unidad |
| Clientes | 2 | Para probar fiado |
| Ventas | 3 | Historial inicial |

### Script de Seed

```sql
-- ===== SEED DATA PARA PRUEBAS =====

-- Tienda Demo
INSERT INTO stores (id, name, address, owner_name) VALUES 
  ('11111111-1111-1111-1111-111111111111', 
   'Mi Tiendita Demo', 
   'Calle Falsa 123', 
   'Don Pedro');

-- Establecer PIN de admin
SELECT establecer_pin_admin('11111111-1111-1111-1111-111111111111', '123456');

-- Empleados
SELECT crear_empleado(
  '11111111-1111-1111-1111-111111111111',
  'María Vendedora', 'maria', '1234',
  '{"canSell": true, "canViewInventory": true, "canViewReports": false, "canFiar": false}'::jsonb
);

SELECT crear_empleado(
  '11111111-1111-1111-1111-111111111111',
  'Carlos Cajero', 'carlos', '5678',
  '{"canSell": true, "canViewInventory": true, "canViewReports": true, "canFiar": true, "canOpenCloseCash": true}'::jsonb
);

-- Productos
INSERT INTO products (store_id, name, plu, price, current_stock, is_weighable, measurement_unit, min_stock) VALUES 
  ('11111111-1111-1111-1111-111111111111', 'Arroz Diana 1kg', '0001', 3500, 50, false, 'un', 10),
  ('11111111-1111-1111-1111-111111111111', 'Aceite Oleocali 1L', '0002', 12000, 20, false, 'un', 5),
  ('11111111-1111-1111-1111-111111111111', 'Queso Costeño', '0003', 18000, 5.5, true, 'kg', 2),
  ('11111111-1111-1111-1111-111111111111', 'Tomate', '0004', 3000, 10.0, true, 'kg', 3),
  ('11111111-1111-1111-1111-111111111111', 'Gaseosa 2L', '0005', 5500, 30, false, 'un', 10);

-- Clientes
INSERT INTO clients (store_id, name, cedula, phone, credit_limit) VALUES 
  ('11111111-1111-1111-1111-111111111111', 'Ana García', '123456789', '3001234567', 100000),
  ('11111111-1111-1111-1111-111111111111', 'Luis Pérez', '987654321', '3009876543', 50000);
```

### Criterio de Éxito Fase 4
- [ ] Tienda demo creada con PIN
- [ ] 2 empleados con diferentes permisos
- [ ] 5 productos (2 pesables, 3 por unidad)
- [ ] 2 clientes con límite de crédito

### Script de Cleanup (Post-Testing)

> Ejecutar **solo** cuando se desee limpiar datos de prueba.

```sql
-- ===== CLEANUP: Eliminar datos de prueba =====

-- Eliminar en orden inverso por dependencias
DELETE FROM client_transactions WHERE client_id IN (
  SELECT id FROM clients WHERE store_id IN (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000099',
    '11111111-1111-1111-1111-111111111111'
  )
);

DELETE FROM sale_items WHERE sale_id IN (
  SELECT id FROM sales WHERE store_id IN (
    '00000000-0000-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111'
  )
);

DELETE FROM inventory_movements WHERE product_id IN (
  SELECT id FROM products WHERE store_id IN (
    '00000000-0000-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111'
  )
);

DELETE FROM clients WHERE store_id IN (
  '00000000-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111'
);

DELETE FROM products WHERE store_id IN (
  '00000000-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111'
);

DELETE FROM employees WHERE store_id IN (
  '00000000-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111'
);

DELETE FROM stores WHERE id IN (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000099',
  '11111111-1111-1111-1111-111111111111'
);
```

---

## Checklist de Verificación Final

### Infraestructura
- [ ] Proyecto Supabase activo
- [ ] Credenciales guardadas de forma segura
- [ ] Schema SQL ejecutado sin errores

### Tablas
- [ ] `stores` - Tiendas
- [ ] `employees` - Empleados
- [ ] `products` - Productos
- [ ] `sales` / `sale_items` - Ventas
- [ ] `clients` - Clientes
- [ ] `expenses` - Gastos
- [ ] `cash_register` - Control de caja
- [ ] `inventory_movements` - Kardex
- [ ] `access_requests` - IAM
- [ ] `sync_queue_failed` - Dead Letter Queue

### Triggers
- [ ] `trg_inventory_movement` - Actualiza stock automáticamente
- [ ] `trg_products_updated` - Actualiza timestamp
- [ ] `trg_employees_updated` - Actualiza timestamp
- [ ] `trg_clients_updated` - Actualiza timestamp

### RPCs (Existentes ✅)
- [ ] `login_empleado_unificado()` - Login con IAM
- [ ] `crear_empleado()` - Crear empleado con PIN
- [ ] `cambiar_pin()` - Cambiar PIN
- [ ] `get_server_timestamp()` - Timestamp del servidor
- [ ] `retry_failed_sync()` - Reintentar sync fallida

### RPCs (Pendientes de Crear ❌)
- [ ] `procesar_venta()` - Procesar venta completa
- [ ] `validar_pin_admin()` - Validar PIN de admin
- [ ] `establecer_pin_admin()` - Crear/cambiar PIN admin
- [ ] `registrar_evento_caja()` - Abrir/cerrar caja
- [ ] `retry_failed_sync()` - Reintentar sync fallida

### Seguridad
- [ ] RLS activo en tablas principales
- [ ] Políticas de aislamiento por `store_id`
- [ ] Rate limiting en login (bloqueo tras 5 intentos)

---

## Herramientas de Verificación

| Herramienta | Cuándo Usar | Cómo Acceder |
|-------------|-------------|--------------|
| **SQL Editor** | Ejecutar queries, probar RPCs | Dashboard → SQL Editor |
| **Table Editor** | Ver datos visualmente | Dashboard → Table Editor |
| **Logs** | Debugging de errores | Dashboard → Logs |
| **API Docs** | Ver endpoints generados | Dashboard → API → API Docs |

---

## Próximos Pasos Después de Verificación

1. **Documentar credenciales** en archivo `.env.local` para frontend
2. **Configurar Realtime** para tablas que lo requieren
3. **Probar desde REST API** con cURL antes de conectar Vue
4. **Conectar frontend** una vez todo verificado

---

## Referencias

- [Supabase Dashboard](https://app.supabase.com)
- [supabase-schema.sql](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/02_ARCHITECTURE/supabase-schema.sql)
- [architecture-supabase.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/02_ARCHITECTURE/architecture-supabase.md)

---

## Historial de Revisiones

| Fecha | Versión | Autor | Cambios |
|-------|---------|-------|---------|
| 2026-01-20 | v1.0 | Arquitecto | Documento inicial con 4 fases |
| 2026-01-20 | v1.1 | Data | Prerrequisitos, estado de funciones, corrección a `login_empleado_unificado` |
| 2026-01-20 | v1.2 | QA | Advertencia seguridad, prueba RLS negativa, script cleanup, checklist corregido |
| 2026-01-20 | v2.0 | Arquitecto | **Consolidación final aprobada** - Puntaje QA 85/100 |


