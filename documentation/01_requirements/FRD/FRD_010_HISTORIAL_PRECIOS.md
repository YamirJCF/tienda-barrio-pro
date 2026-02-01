# FRD_010: Historial de Precios

> **Módulo:** Inventario  
> **Versión:** 1.0  
> **Fecha:** 2026-01-27  
> **Estado:** Aprobado

---

## Descripción

El sistema registra automáticamente cada cambio de precio en los productos, almacenando un historial completo que permite al tendero analizar la evolución de costos y tomar decisiones informadas sobre precios de venta y márgenes.

---

## Reglas de Negocio

### RN-010-01: Registro Automático
Cada vez que se modifica el precio de venta o costo de un producto, el sistema crea un registro en el historial **sin intervención del usuario**.

### RN-010-02: Datos del Registro

| Campo | Obligatorio | Descripción |
|-------|-------------|-------------|
| `productId` | ✅ | Referencia al producto |
| `previousPrice` | ✅ | Precio antes del cambio |
| `newPrice` | ✅ | Precio después del cambio |
| `changedAt` | ✅ | Fecha y hora exacta del cambio |
| `changedBy` | ✅ | ID del usuario que realizó el cambio |
| `reason` | ❌ | Motivo del cambio (opcional) |

### RN-010-03: Control de Acceso
El historial de precios **solo es visible** para usuarios con permiso de inventario (`canViewInventory = true`).

| Rol | Acceso |
|-----|--------|
| Admin | ✅ Siempre |
| Empleado con permiso inventario | ✅ Sí |
| Empleado sin permiso inventario | ❌ No |

### RN-010-04: Retención de Datos
Se almacena el **historial completo** de todos los cambios de precio. No hay límite de registros por producto. Esto permite futuros análisis y reportes.

### RN-010-05: Inmutabilidad
Los registros del historial **NO pueden ser editados ni eliminados**. Son un log de auditoría.

---

## Visualización

El historial de precios se muestra en **dos ubicaciones**:

### 1. Ficha del Producto (Sección)
Dentro del detalle del producto, una sección colapsable muestra los últimos cambios de precio.

### 2. Vista Dedicada de Historial
Una vista separada (opcional para v2) permite consultar todos los cambios de precio con filtros.

---

## Casos de Uso

### Caso A: Ver Historial desde Producto

- **Actor:** Admin o Empleado con permiso de inventario
- **Precondición:** Producto existente con al menos 1 cambio de precio
- **Flujo Principal:**
    1. Usuario navega a Inventario → Selecciona producto.
    2. Sistema muestra ficha del producto.
    3. Usuario expande sección "Historial de Precios".
    4. Sistema muestra lista cronológica: fecha, precio anterior → precio nuevo, quién cambió.
- **Postcondición:** Usuario informado sobre evolución del precio.

### Caso B: Cambio de Precio con Motivo

- **Actor:** Admin
- **Precondición:** Producto existente
- **Flujo Principal:**
    1. Admin edita precio de venta de $3,500 → $4,200.
    2. Sistema muestra campo opcional "Motivo del cambio".
    3. Admin ingresa: "Aumento proveedor".
    4. Sistema guarda nuevo precio + crea registro en historial con motivo.
- **Postcondición:** Producto actualizado, historial registrado con contexto.

### Caso C: Usuario sin Permiso

- **Actor:** Empleado sin permiso de inventario
- **Precondición:** Empleado tiene `canViewInventory = false`
- **Flujo Principal:**
    1. Empleado intenta acceder a detalle de producto.
    2. Sistema bloquea acceso o no muestra sección de historial.
- **Postcondición:** Historial protegido.

---

## Requisitos de Datos (Para Equipo Data)

**Nueva Entidad: PriceChangeLog**

| Campo | Tipo | Requerido | Notas |
|-------|------|-----------|-------|
| `id` | UUID | ✅ | PK |
| `productId` | UUID | ✅ | FK → products |
| `previousPrice` | Decimal | ✅ | Precio antes del cambio |
| `newPrice` | Decimal | ✅ | Precio después del cambio |
| `changedAt` | Timestamp | ✅ | Autogenerado |
| `changedBy` | UUID | ✅ | FK → employees |
| `reason` | String(200) | ❌ | Opcional |

**Índices sugeridos:**
- `productId` + `changedAt DESC` (para consulta rápida del historial)

---

## Criterios de Aceptación

### Funcionalidad
- [ ] Cada cambio de precio crea registro automático en historial.
- [ ] El registro incluye: precio anterior, nuevo, fecha/hora, usuario.
- [ ] Campo "motivo" es opcional y acepta hasta 200 caracteres.
- [ ] Historial NO puede ser editado ni eliminado.

### Control de Acceso
- [ ] Solo usuarios con `canViewInventory = true` ven el historial.
- [ ] Admin siempre tiene acceso.

### UX
- [ ] Historial visible como sección colapsable en ficha de producto.
- [ ] Formato de fecha legible (ej: "15 Ene 2026, 3:45 PM").
- [ ] Indicador visual de aumento (↑ rojo) o disminución (↓ verde).

### Datos
- [ ] Tabla `price_change_logs` creada con estructura definida.
- [ ] Trigger o lógica que registra cambios automáticamente.
- [ ] Sin límite de registros (historial completo).

---

## Impacto en el Sistema

| Componente | Modificación |
|------------|--------------|
| **Backend/Supabase** | Nueva tabla `price_change_logs` |
| **Backend/Supabase** | RLS policy basada en permiso inventario |
| **Backend/Supabase** | Trigger en `products.price` para auto-log |
| **Frontend/Store** | Extender `inventoryStore` para cargar historial |
| **Frontend/Vista** | Agregar sección en `ProductDetailView` |
| **Frontend/Modelo** | Nuevo tipo `PriceChangeLog` en types |

---

## Trazabilidad

| Documento | Referencia |
|-----------|------------|
| PRD | Sección: Gestión de Inventario |
| FRD_003 | Inventario - Gestión de Productos |
| SYSTEM_BOUNDARIES | Confirmado como funcionalidad incluida |
