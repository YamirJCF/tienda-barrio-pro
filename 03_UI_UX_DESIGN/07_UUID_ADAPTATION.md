# 🎨 Diseño UX/UI - Adaptación a Identificadores Globales (UUID)

> **Fecha**: 2026-01-21 (Actualizado: Post-Auditoría)  
> **Rol**: Estratega de UX/UI  
> **Contexto**: Definición de la migración de IDs numéricos locales (Legacy) a UUIDs (Cloud Native).

---

## 📋 Resumen Ejecutivo

El sistema actualmente opera con **IDs numéricos locales** en memoria (`nextId`). La migración a Supabase introduce **UUIDs** (36 caracteres) como claves primarias.

Este documento define la estrategia para **ocultar esta complejidad técnica** al usuario, estableciendo "Identificadores Funcionales" amigables.

> [!IMPORTANT]
> **Estado de Migración**: 
> - **Backend**: Ya preparado para UUIDs.
> - **Frontend**: Requiere refactorización crítica para dejar de usar `number` en rutas y stores.
> - **Regla de Oro**: El usuario NUNCA debe ver, escribir ni buscar por UUID.

---

## 1️⃣ Ventas y Recibos (/pos)

### Diagnóstico
- **Estado Frontend**: Genera IDs locales secuenciales (ej: 1, 2, 3) que se reinician o desincronizan.
- **Estado Backend**: Tabla `sales` tiene `ticket_number` pero es global (`SERIAL`), no por tienda.

### Definición UX (El Objetivo)

| Aspecto | Identificador Visual | Requisito Técnico |
|---------|----------------------|-------------------|
| **Historial** | `Ticket #0045` | Frontend debe leer `ticket_number` del backend, NO el ID de la fila. |
| **Recibo** | `Ticket #0045` | El número debe ser correlativo **por tienda** (ej: Tienda A #1, Tienda B #1). |
| **Búsqueda** | "Buscar por ticket" | Input numérico que mapea internamente a consulta SQL. |

### Mapa de Navegación
```
[POS] → [Cobrar] → [Backend genera UUID + Ticket # único]
                           ↓
                  [Confirmación: "Venta #0045 Exitosa"]
                           ↓
                  [Historial: Muestra #0045, Link a /sales/uuid-largo]
```

### Instrucción para el Orquestador
1. **Modelado**: Implementar `unique_ticket_per_store` en SQL (evitar colisiones globales).
2. **Frontend**: Refactorizar tipos `Sale.id` de `number` a `string` (UUID).
3. **Store**: Eliminar lógica `nextId++`.

---

## 2️⃣ Listado de Productos (/inventory)

### Diagnóstico
El inventario visualmente ya depende del PLU, lo cual es correcto.

### Definición UX

| Aspecto | Decisión |
|---------|----------|
| **Identificador Principal** | **PLU** (Código Rápido, ej: 105). |
| **Identificador Secundario** | **SKU / Código de Barras** (si aplica). |
| **UUID (products.id)** | **INVISIBLE**. Solo usado para operaciones CRUD. |

### Detalle de Pantalla
Las tarjetas de producto mantendrán su diseño actual.
- **Correcto**: `Leche Colanta | PLU: 50`
- **Prohibido**: Mostrar el hash UUID en la tarjeta o tooltips.

---

## 3️⃣ URLs y Navegación

### Análisis de Impacto (Breaking Change)

Esta es la zona de mayor impacto en la refactorización.

```
ANTES (Actual):   /clients/15
DESPUÉS (Deseado): /clients/550e8400-e29b-41d4-a716-446655440000
```

### Decisión UX

| Escenario | Decisión |
|-----------|----------|
| **Estética URL** | **Se acepta URL larga**. No se usarán "slugs" numéricos para evitar consultas extra a DB. |
| **Router Vue** | Debe actualizarse para aceptar `string` en lugar de `number` en params. |
| **Compartir Links** | El título de la página (`document.title`) debe ser descriptivo ("Cliente: Juana") para compensar la URL ilegible. |

---

## 4️⃣ Buscadores y Filtros

### Principio UX Fundamental
> [!CAUTION]
> Los placeholders actuales ("Buscar...") son ambiguos. Deben ser explícitos para evitar que el usuario intente buscar códigos de sistema.

### Estandarización de Placeholders

| Módulo | Placeholder Aprobado | Criterios Backend |
|--------|----------------------|-------------------|
| **POS** | "Buscar por nombre o PLU..." | `name ILIKE` OR `plu =` |
| **Inventario** | "Nombre, marca o PLU..." | `name`, `brand`, `plu` |
| **Clientes** | "Nombre, cédula o teléfono..." | `name`, `cedula`, `phone` |
| **Ventas** | "Buscar N° de Ticket..." | `ticket_number` |

---

## 5️⃣ Matriz de Identificadores (Target State)

| Entidad | Clave Primaria (Invisible) | Identificador Funcional (Visible) | Formato Visual |
|---------|----------------------------|-----------------------------------|----------------|
| **Venta** | `UUID` | `ticket_number` | `#0001` (4 dígitos padding) |
| **Producto** | `UUID` | `plu` | `PLU: 101` |
| **Cliente** | `UUID` | `cedula` | `CC 71.234.567` |
| **Empleado** | `UUID` | `username` | `@juanp` |
| **Tienda** | `UUID` | `name` | Nombre Fantasía |

---

## 6️⃣ Guía de Implementación Técnica

### 🚩 Banderas Rojas (Code Audit)
Si ves esto en el código, **ESTÁ MAL**:
```typescript
// MAL: Uso de contadores en memoria
const nextId = ref(1);
function add() { id: nextId.value++ } 

// MAL: Asumir que ID es número en rutas
route.params.id as number
```

### ✅ Patrón Correcto
```typescript
// BIEN: IDs generados por Base de Datos o crypto.randomUUID()
interface Sale {
  id: string; // UUID
  ticketNumber: number; // Secuencial humano
}
```

### checklist de Migración (Dev)
1. [ ] Actualizar interfaces TypeScript (`number` -> `string`).
2. [ ] Eliminar toda referencia a `nextId` en Pinia stores.
3. [ ] Actualizar `vue-router` para manejar UUIDs.
4. [ ] Implementar trigger SQL para `ticket_number` por tienda.
