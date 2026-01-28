# Hoja de Ruta: Despliegue e Integración del Sistema

> **Documento:** Roadmap Técnico de Despliegue  
> **Versión:** 1.0  
> **Fecha:** 2026-01-28  
> **Arquitecto:** @[/architect]

---

## Filosofía de Despliegue

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRINCIPIO DE AISLAMIENTO                     │
│                                                                 │
│   Backend (Supabase)    ←── NO CONECTAR ──→    Frontend (Vue)   │
│          ↓                                          ↓           │
│   Pruebas Aisladas                         Pruebas Aisladas     │
│          ↓                                          ↓           │
│       ✅ PASS                                   ✅ PASS          │
│          ↓                                          ↓           │
│          └──────────────→ INTEGRACIÓN ←─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

**Regla de Oro:** No se intenta conectar frontend ↔ backend hasta que AMBOS pasen sus pruebas aisladas.

---

## Visión General de Fases

| Fase | Nombre | Objetivo | Duración Est. |
|------|--------|----------|---------------|
| **1** | Preparación Supabase | Crear proyecto y configurar entorno | 30 min |
| **2** | Despliegue Backend | Ejecutar schema y verificar | 1-2 hrs |
| **3** | Pruebas Backend Aisladas | Validar RPCs y seguridad | 2-3 hrs |
| **4** | Preparación Frontend | Actualizar tipos y adaptar stores | 2-3 hrs |
| **5** | Pruebas Frontend Aisladas | Validar con mocks | 2-3 hrs |
| **6** | Integración | Conectar frontend ↔ backend | 2-4 hrs |
| **7** | Pruebas E2E | Validar flujos completos | 2-3 hrs |
| **8** | Go-Live | Producción | 1 hr |

**Total estimado:** 12-20 horas de trabajo efectivo

---

## FASE 1: Preparación Supabase

### Objetivo
Crear y configurar el proyecto Supabase en modo staging.

### Pasos

1. **Crear proyecto en Supabase Dashboard**
   - Nombre: `tienda-barrio-staging`
   - Región: Más cercana (ej: `us-east-1`)
   - Plan: Free tier

2. **Obtener credenciales**
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_KEY` (para pruebas admin)

3. **Configurar archivo `.env.staging`**
   ```
   VITE_SUPABASE_URL=https://xxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJxxx...
   ```

### Verificables para Pasar a Fase 2

| # | Verificable | Método |
|---|-------------|--------|
| ✅ | Proyecto creado en dashboard | Visual |
| ✅ | URL y keys copiadas | Manual |
| ✅ | `.env.staging` creado | `cat .env.staging` |
| ✅ | Extensión pgcrypto existe | SQL Editor: `SELECT * FROM pg_extension` |

### Rollback
Si algo falla: Eliminar proyecto y recrear (datos vacíos, sin impacto).

---

## FASE 2: Despliegue Backend

### Objetivo
Ejecutar `supabase-schema-v2.sql` y verificar que todas las tablas, políticas y funciones existen.

### Pasos

1. **Ejecutar schema completo**
   - Ir a SQL Editor en Supabase Dashboard
   - Pegar contenido de `supabase-schema-v2.sql`
   - Ejecutar (puede tomar 1-2 minutos)

2. **Verificar creación de objetos**
   - Tablas: 17 esperadas
   - Funciones: ~15 RPCs
   - Políticas RLS: ~40

### Verificables para Pasar a Fase 3

| # | Verificable | Query de Verificación |
|---|-------------|----------------------|
| ✅ | 17 tablas creadas | `SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'` |
| ✅ | RLS habilitado | `SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' AND rowsecurity = true` |
| ✅ | Funciones RPC existen | `SELECT proname FROM pg_proc WHERE pronamespace = 'public'::regnamespace` |
| ✅ | pgcrypto activo | `SELECT crypt('test', gen_salt('bf'))` retorna hash |

### Rollback
```sql
-- Si falla, ejecutar en SQL Editor:
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
-- Luego volver a intentar el schema
```

---

## FASE 3: Pruebas Backend Aisladas

### Objetivo
Validar que las RPCs funcionan correctamente SIN frontend, usando solo SQL Editor.

### Batería de Pruebas

#### Test 3.1: Crear Tienda y Admin
```sql
-- 1. Crear usuario via auth.users (simulado)
INSERT INTO auth.users (id, email) 
VALUES ('11111111-1111-1111-1111-111111111111', 'admin@test.com');

-- 2. Crear tienda
INSERT INTO public.stores (id, name, slug)
VALUES ('22222222-2222-2222-2222-222222222222', 'Tienda Test', 'tienda-test');

-- 3. Crear perfil admin
INSERT INTO public.admin_profiles (id, store_id, role)
VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'owner');
```
**Esperado:** Inserts exitosos, sin errores.

#### Test 3.2: Crear Empleado con Límite
```sql
-- Crear 6 empleados (el 6to debe fallar)
SELECT public.crear_empleado(
  '22222222-2222-2222-2222-222222222222',
  'Empleado 1', '1000000001', '1234', '{}'::jsonb
);
-- Repetir para 2, 3, 4, 5
-- El 6to debe retornar: {"success": false, "code": "EMPLOYEE_LIMIT_REACHED"}
```
**Esperado:** 5 exitosos, 1 rechazado con código correcto.

#### Test 3.3: Validar PIN
```sql
SELECT public.validar_pin_empleado('1000000001', '1234');
-- Esperado: {"success": true, "employee": {...}}

SELECT public.validar_pin_empleado('1000000001', '9999');
-- Esperado: {"success": false, "code": "INVALID_PIN"}
```

#### Test 3.4: Procesar Venta
```sql
-- Primero crear un producto
INSERT INTO public.products (id, store_id, name, price, current_stock)
VALUES ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'Producto Test', 5000, 100);

-- Procesar venta
SELECT public.procesar_venta(
  '22222222-2222-2222-2222-222222222222',
  (SELECT id FROM public.employees LIMIT 1),
  '[{"product_id": "33333333-3333-3333-3333-333333333333", "quantity": 2, "unit_price": 5000, "subtotal": 10000}]'::jsonb,
  10000,
  'efectivo',
  10000
);
```
**Esperado:** `{"success": true, "sale_id": "...", "ticket_number": 1}`

#### Test 3.5: Verificar Stock Actualizado
```sql
SELECT current_stock FROM public.products WHERE id = '33333333-3333-3333-3333-333333333333';
-- Esperado: 98 (era 100, vendimos 2)
```

### Verificables para Pasar a Fase 4

| # | Verificable | Estado |
|---|-------------|--------|
| ✅ | Test 3.1 pasó | |
| ✅ | Test 3.2 pasó (límite funciona) | |
| ✅ | Test 3.3 pasó (PIN válido/inválido) | |
| ✅ | Test 3.4 pasó (venta procesada) | |
| ✅ | Test 3.5 pasó (stock decrementó) | |
| ✅ | RLS: Usuario A no ve datos de Usuario B | |

### Rollback
Si una RPC falla: Corregir SQL, dropear función, recrear.
Si estructura falla: Volver a Fase 2 rollback.

---

## FASE 4: Preparación Frontend

### Objetivo
Generar tipos TypeScript y adaptar stores/repositorios al nuevo schema.

### Pasos

1. **Generar tipos desde Supabase**
   ```bash
   npx supabase gen types typescript --project-id <id> > src/types/database.types.ts
   ```

2. **Actualizar cliente Supabase**
   ```typescript
   // src/lib/supabase.ts
   import { createClient } from '@supabase/supabase-js'
   import type { Database } from '@/types/database.types'
   
   export const supabase = createClient<Database>(
     import.meta.env.VITE_SUPABASE_URL,
     import.meta.env.VITE_SUPABASE_ANON_KEY
   )
   ```

3. **Adaptar repositorios**
   - Verificar nombres de tablas
   - Verificar nombres de columnas
   - Verificar llamadas a RPCs

4. **Crear mocks para pruebas**
   - Mock de `supabase.from().select()`
   - Mock de `supabase.rpc()`

### Verificables para Pasar a Fase 5

| # | Verificable | Método |
|---|-------------|--------|
| ✅ | `database.types.ts` generado | Archivo existe |
| ✅ | Sin errores TypeScript | `npm run build` sin errores |
| ✅ | Mocks creados | Archivos en `src/__mocks__/` |

### Rollback
Git: `git stash` o `git checkout .` para revertir cambios.

---

## FASE 5: Pruebas Frontend Aisladas

### Objetivo
Validar lógica de stores/repos con mocks, SIN conexión real a Supabase.

### Batería de Pruebas

1. **Unit Tests de Stores**
   ```bash
   npm run test:unit -- --filter "stores"
   ```

2. **Tests de Repositorios con Mocks**
   - `ProductRepository.getAll()` retorna array tipado
   - `SaleRepository.create()` llama RPC correctamente

3. **Tests de Componentes**
   - Renderizado sin errores
   - Interacciones disparan acciones correctas

### Verificables para Pasar a Fase 6

| # | Verificable | Método |
|---|-------------|--------|
| ✅ | `npm run test` pasa | CI/Terminal |
| ✅ | `npm run build` exitoso | CI/Terminal |
| ✅ | 0 errores TypeScript | Linter |
| ✅ | Cobertura > 60% en stores críticos | Coverage report |

### Rollback
Si tests fallan: Corregir código, no avanzar hasta que pasen.

---

## FASE 6: Integración

### Objetivo
Conectar frontend con backend real en staging.

### Pasos

1. **Configurar `.env` con staging**
   ```
   VITE_SUPABASE_URL=https://xxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJxxx...
   ```

2. **Ejecutar app en modo dev**
   ```bash
   npm run dev
   ```

3. **Pruebas manuales de flujos**
   - Login Admin
   - Crear empleado
   - Login empleado
   - Crear producto
   - Procesar venta

### Verificables para Pasar a Fase 7

| # | Verificable | Método |
|---|-------------|--------|
| ✅ | Login Admin funciona | Manual |
| ✅ | CRUD empleados funciona | Manual |
| ✅ | CRUD productos funciona | Manual |
| ✅ | Venta se procesa | Manual |
| ✅ | Stock decrementa | Verificar en DB |
| ✅ | Sin errores en consola | DevTools |

### Rollback
Si integración falla:
1. Identificar si es bug de frontend o backend
2. Volver a Fase 3 o Fase 5 según corresponda
3. Corregir y re-probar aisladamente

---

## FASE 7: Pruebas E2E

### Objetivo
Validar flujos completos end-to-end.

### Flujos a Probar

| # | Flujo | Pasos |
|---|-------|-------|
| E2E-1 | Registro completo | Registro Admin → Crear Tienda → Login |
| E2E-2 | Gestión empleados | Login Admin → Crear Empleado → Login Empleado |
| E2E-3 | Venta completa | Abrir caja → Crear venta → Verificar stock |
| E2E-4 | Fiado cliente | Crear cliente → Venta fiado → Verificar balance |
| E2E-5 | Cierre de caja | Registrar ventas → Cerrar caja → Verificar reporte |
| E2E-6 | Offline sync | Desconectar → Vender → Reconectar → Sincronizar |

### Verificables para Pasar a Fase 8

| # | Verificable | Estado |
|---|-------------|--------|
| ✅ | E2E-1 pasó | |
| ✅ | E2E-2 pasó | |
| ✅ | E2E-3 pasó | |
| ✅ | E2E-4 pasó | |
| ✅ | E2E-5 pasó | |
| ✅ | E2E-6 pasó | |
| ✅ | Logs de auditoría registrados | |
| ✅ | Ningún error crítico | |

### Rollback
Si E2E falla: Identificar punto de falla, volver a fase correspondiente.

---

## FASE 8: Go-Live (Producción)

### Objetivo
Desplegar a producción con confianza.

### Pasos

1. **Crear proyecto Supabase producción**
   - Nombre: `tienda-barrio-pro`
   - Configurar con datos limpios

2. **Ejecutar schema en producción**
   - Mismo `supabase-schema-v2.sql`

3. **Configurar variables de entorno producción**

4. **Desplegar frontend**
   ```bash
   npm run build
   # Deploy a Vercel/Netlify/etc
   ```

5. **Smoke tests en producción**

### Verificables de Producción

| # | Verificable | Método |
|---|-------------|--------|
| ✅ | App accesible | URL funciona |
| ✅ | Registro funciona | Prueba manual |
| ✅ | Sin errores 500 | Monitoreo |
| ✅ | SSL activo | HTTPS válido |

---

## Diagrama de Dependencias

```
FASE 1 ──→ FASE 2 ──→ FASE 3 ──┐
                               │
                               ├──→ FASE 6 ──→ FASE 7 ──→ FASE 8
                               │
           FASE 4 ──→ FASE 5 ──┘
```

**Nota:** Fases 2-3 (Backend) y Fases 4-5 (Frontend) pueden ejecutarse en paralelo.

---

## Checklist de Progreso

| Fase | Estado | Fecha | Notas |
|------|--------|-------|-------|
| 1. Preparación Supabase | ✅ Completado | 2026-01-28 | Project ID: zolanvecewgdcmfwzqdb |
| 2. Despliegue Backend | ⬜ Pendiente | | |
| 3. Pruebas Backend | ⬜ Pendiente | | |
| 4. Preparación Frontend | ⬜ Pendiente | | |
| 5. Pruebas Frontend | ⬜ Pendiente | | |
| 6. Integración | ⬜ Pendiente | | |
| 7. Pruebas E2E | ⬜ Pendiente | | |
| 8. Go-Live | ⬜ Pendiente | | |

---

## Contactos y Escalación

| Problema | Escalar a |
|----------|-----------|
| Errores SQL | @[/data] |
| Errores TypeScript | @[/orchestrator] |
| Fallas de seguridad | @[/qa] |
| Cambios de requisitos | @[/architect] |
| Problemas de UI/UX | @[/ux] |
