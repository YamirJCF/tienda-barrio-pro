# Diccionario de Datos

> **Documento:** Definición de campos y tipos  
> **Generado desde:** FRDs en `01_REQUIREMENTS/FRD/`  
> **Fecha:** 2026-01-28

---

## Tabla: `stores`

> **FRD Origen:** FRD_002_REGISTRO_ADMIN.md

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único de la tienda |
| `name` | TEXT | NOT NULL | Nombre comercial de la tienda |
| `slug` | TEXT | NOT NULL, UNIQUE | Identificador amigable único (ej: "tienda-don-pepe") |
| `subscription_plan` | TEXT | DEFAULT 'free', CHECK (IN 'free','pro','enterprise') | Plan de suscripción actual |
| `store_pin_hash` | TEXT | NULL | Hash del PIN de caja (bcrypt via crypt()) |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Fecha de registro de la tienda |
| `updated_at` | TIMESTAMPTZ | DEFAULT now() | Última modificación |

---

## Tabla: `admin_profiles`

> **FRD Origen:** FRD_002_REGISTRO_ADMIN.md

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, REFERENCES auth.users(id) | Vinculado al proveedor de autenticación |
| `store_id` | UUID | NOT NULL, FK → stores(id) | Tienda a la que pertenece el admin |
| `role` | TEXT | NOT NULL, CHECK (IN 'owner','manager') | Rol del administrador |
| `is_verified` | BOOLEAN | DEFAULT false | Estado de verificación del email |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Fecha de creación del perfil |

---

## Tabla: `employees`

> **FRD Origen:** FRD_003_GESTION_EMPLEADOS.md

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único del empleado |
| `store_id` | UUID | NOT NULL, FK → stores(id) | Tienda a la que pertenece (multitenant) |
| `name` | TEXT | NOT NULL | Nombre completo del empleado |
| `username` | TEXT | NOT NULL, UNIQUE (global) | Alias numérico único (cédula/teléfono) |
| `pin_hash` | TEXT | NOT NULL | Hash del PIN de 4 dígitos (bcrypt) |
| `is_active` | BOOLEAN | DEFAULT true | Estado activo/inactivo |
| `permissions` | JSONB | DEFAULT '{}' | Permisos adicionales (ver estructura) |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Fecha de creación |
| `updated_at` | TIMESTAMPTZ | DEFAULT now() | Última modificación |

### Estructura de `permissions` (JSONB)

```json
{
  "canViewInventory": true,
  "canFiar": false,
  "canOpenCloseCash": false,
  "canViewReports": false
}
```

> **Nota:** Todos los empleados pueden vender por defecto (FRD_003 §4).

---

## Tabla: `products`

> **FRD Origen:** FRD_006_INVENTARIO.md

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único del producto |
| `store_id` | UUID | NOT NULL, FK → stores(id) | Tienda (multitenant) |
| `name` | TEXT | NOT NULL, MIN 2 chars | Nombre del producto |
| `plu` | TEXT | UNIQUE per store | Código rápido 4 dígitos |
| `price` | DECIMAL(12,0) | NOT NULL, > 0 | Precio venta (redondeado $50) |
| `cost_price` | DECIMAL(12,0) | NULL | Costo (visible solo Admin) |
| `current_stock` | DECIMAL(10,2) | DEFAULT 0, >= 0 | Stock actual |
| `min_stock` | DECIMAL(10,2) | DEFAULT 5 | Umbral alerta stock bajo |
| `category` | TEXT | NULL | Categoría libre |
| `measurement_unit` | TEXT | CHECK (IN 'unidad','kg','lb','g') | Unidad de medida |
| `is_weighable` | BOOLEAN | DEFAULT false | Si requiere peso en POS |
| `low_stock_alerted` | BOOLEAN | DEFAULT false | True si alerta ya disparada |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Fecha de creación |
| `updated_at` | TIMESTAMPTZ | DEFAULT now() | Última modificación |

---

## Tabla: `inventory_movements`

> **FRD Origen:** FRD_006_INVENTARIO.md  
> **Tipo:** IMMUTABLE (INSERT-only según QA_ADDENDUM §4.2)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único |
| `product_id` | UUID | NOT NULL, FK → products(id) | Producto afectado |
| `movement_type` | TEXT | CHECK (IN tipos) | entrada, salida, ajuste, venta, devolucion |
| `quantity` | DECIMAL(10,2) | NOT NULL | Cantidad movida (+ o -) |
| `reason` | TEXT | NULL | Razón del movimiento |
| `created_by` | UUID | FK → employees(id) | Empleado que registró |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Timestamp inmutable |

---

## Tabla: `sales`

> **FRD Origen:** FRD_007_VENTAS.md  
> **Tipo:** IMMUTABLE (no UPDATE/DELETE según QA_ADDENDUM)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único |
| `store_id` | UUID | NOT NULL, FK → stores(id) | Tienda (multitenant) |
| `ticket_number` | INTEGER | NOT NULL | Número secuencial para UI |
| `employee_id` | UUID | NOT NULL, FK → employees(id) | Empleado que procesó la venta |
| `client_id` | UUID | FK → clients(id) | Cliente (solo si es fiado) |
| `total` | DECIMAL(12,0) | NOT NULL | Total redondeado al $50 |
| `rounding_difference` | DECIMAL(10,2) | DEFAULT 0 | Diferencia total exacto vs redondeado |
| `payment_method` | TEXT | CHECK (IN tipos) | efectivo, nequi, daviplata, fiado |
| `amount_received` | DECIMAL(12,0) | NULL | Monto recibido (solo efectivo) |
| `change_given` | DECIMAL(12,0) | NULL | Vueltas (solo efectivo) |
| `sync_status` | TEXT | DEFAULT 'pending' | synced, pending, failed |
| `local_id` | TEXT | NULL | ID local para offline sync |
| `is_voided` | BOOLEAN | DEFAULT false | Si fue anulada |
| `voided_by` | UUID | FK → employees(id) | Quien anuló (solo Admin) |
| `void_reason` | TEXT | NULL | Razón obligatoria si anulada |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Fecha/hora de venta |

---

## Tabla: `sale_items`

> **FRD Origen:** FRD_007_VENTAS.md  
> **Tipo:** IMMUTABLE (INSERT-only)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único |
| `sale_id` | UUID | NOT NULL, FK → sales(id) | Venta padre |
| `product_id` | UUID | NOT NULL, FK → products(id) | Producto vendido |
| `quantity` | DECIMAL(10,2) | NOT NULL | Cantidad vendida |
| `unit_price` | DECIMAL(12,0) | NOT NULL | Precio unitario al momento |
| `subtotal` | DECIMAL(12,0) | NOT NULL | Subtotal redondeado |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Timestamp |

---

## Tabla: `clients`

> **FRD Origen:** FRD_009_CLIENTES.md  
> **Soft Delete:** Campo `is_deleted` + `deleted_at`

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único |
| `store_id` | UUID | NOT NULL, FK → stores(id) | Tienda (multitenant) |
| `name` | TEXT | NOT NULL, MIN 3 chars | Nombre completo |
| `id_number` | TEXT | NOT NULL, UNIQUE per store | Cédula (única por tienda) |
| `phone` | TEXT | NULL | Teléfono contacto |
| `credit_limit` | DECIMAL(12,0) | NOT NULL | Cupo de crédito |
| `balance` | DECIMAL(12,0) | DEFAULT 0, >= 0 | Balance (nunca negativo) |
| `is_deleted` | BOOLEAN | DEFAULT false | Soft delete flag |
| `deleted_at` | TIMESTAMPTZ | NULL | Timestamp de borrado |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Fecha creación |
| `updated_at` | TIMESTAMPTZ | DEFAULT now() | Última modificación |

---

## Tabla: `client_transactions`

> **FRD Origen:** FRD_009_CLIENTES.md  
> **Tipo:** IMMUTABLE (INSERT-only)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único |
| `client_id` | UUID | NOT NULL, FK → clients(id) | Cliente |
| `transaction_type` | TEXT | CHECK (IN 'compra','pago') | Tipo de transacción |
| `amount` | DECIMAL(12,0) | NOT NULL, > 0 | Monto (siempre positivo) |
| `description` | TEXT | NULL | Descripción (ej: "Venta #45") |
| `sale_id` | UUID | FK → sales(id) | Ref venta (solo compras) |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Timestamp inmutable |

---

## Tabla: `cash_sessions`

> **FRD Origen:** FRD_004_CONTROL_DE_CAJA.md  
> **Invariante:** Solo 1 sesión abierta por tienda

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único |
| `store_id` | UUID | NOT NULL, FK → stores(id) | Tienda (multitenant) |
| `opened_by` | UUID | NOT NULL, FK → employees(id) | Empleado que abrió |
| `closed_by` | UUID | FK → employees(id) | Empleado que cerró |
| `opening_balance` | DECIMAL(12,0) | NOT NULL | Fondo de cambio inicial |
| `expected_balance` | DECIMAL(12,0) | NULL | Calculado al cerrar |
| `actual_balance` | DECIMAL(12,0) | NULL | Declarado por usuario |
| `difference` | DECIMAL(12,0) | NULL | expected - actual |
| `status` | TEXT | CHECK (IN 'open','closed') | Estado de sesión |
| `opened_at` | TIMESTAMPTZ | DEFAULT now() | Timestamp apertura |
| `closed_at` | TIMESTAMPTZ | NULL | Timestamp cierre |

---

## Tabla: `cash_movements`

> **FRD Origen:** FRD_004_CONTROL_DE_CAJA.md  
> **Tipo:** IMMUTABLE (INSERT-only)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único |
| `session_id` | UUID | NOT NULL, FK → cash_sessions(id) | Sesión de caja |
| `movement_type` | TEXT | CHECK (IN 'ingreso','gasto') | Tipo movimiento |
| `amount` | DECIMAL(12,0) | NOT NULL, > 0 | Monto |
| `description` | TEXT | NOT NULL | Descripción obligatoria |
| `sale_id` | UUID | FK → sales(id) | Ref venta (solo ingresos) |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Timestamp inmutable |

---

## Tabla: `daily_passes`

> **FRD Origen:** FRD_001_SEGURIDAD_DIARIA.md  
> **Expiración:** Al cerrar caja, todos expiran

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único |
| `employee_id` | UUID | NOT NULL, FK → employees(id) | Empleado solicitante |
| `pass_date` | DATE | NOT NULL | Fecha del pase |
| `status` | TEXT | CHECK (IN tipos) | pending, approved, rejected, expired |
| `device_fingerprint` | TEXT | NULL | Huella dispositivo (informativo) |
| `retry_count` | INTEGER | DEFAULT 0, MAX 3 | Reintentos sin respuesta |
| `requested_at` | TIMESTAMPTZ | DEFAULT now() | Timestamp solicitud |
| `resolved_at` | TIMESTAMPTZ | NULL | Timestamp resolución |
| `resolved_by` | UUID | FK → employees(id) | Admin que aprobó/rechazó |

---

## Tabla: `audit_logs`

> **FRD Origen:** QA_ADDENDUM §4.3  
> **Tipo:** IMMUTABLE (INSERT-only, sin UPDATE ni DELETE)

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PK, DEFAULT gen_random_uuid() | Identificador único |
| `store_id` | UUID | NOT NULL, FK → stores(id) | Tienda (multitenant) |
| `event_type` | TEXT | NOT NULL | login_success, login_failed, pin_change, etc. |
| `severity` | TEXT | CHECK (IN tipos) | info, warning, critical |
| `actor_id` | UUID | NULL | Usuario que generó el evento |
| `actor_role` | TEXT | NULL | admin o employee |
| `metadata` | JSONB | DEFAULT '{}' | Datos adicionales del evento |
| `ip_address` | TEXT | NULL | Dirección IP del cliente |
| `user_agent` | TEXT | NULL | Navegador/dispositivo |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | Timestamp inmutable |

**Eventos registrados (QA_ADDENDUM §4.3):**
- `login_success` (info)
- `login_failed` (warning)
- `login_blocked` (critical) - Múltiples intentos fallidos
- `pin_change` (warning)
- `employee_deactivated` (warning)
- `remote_logout` (info)

---

## Campos de Auditoría (Estándar QA)

Según QA_ADDENDUM §4.1, toda tabla modificable DEBE incluir:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `created_at` | TIMESTAMPTZ | Fecha de creación (DEFAULT now()) |
| `created_by` | UUID | Referencia al usuario que creó el registro |
| `updated_at` | TIMESTAMPTZ | Fecha de última modificación |
