# Reporte de Pre-Auditoría Contextual: PAC-UXD (SDD-006-03)

> **Componente Auditado:** `frontend/src/components/ProductSearchModal.vue` (y componentes auxiliares `frontend/src/components/ProductFormModal.vue`, `frontend/src/views/InventoryView.vue`, store `frontend/src/stores/inventory.ts`)  
> **SDD Fuente:** [`documentation/01_requirements/SDD/SDD_006_03_CODIGO_PRODUCTO.md`](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/documentation/01_requirements/SDD/SDD_006_03_CODIGO_PRODUCTO.md)  
> **Fecha:** 2026-10-17  
> **Carácter:** Cartografía consultiva no bloqueante.

---

## Bloque 1 — Identificación

### B1.1 Componente Objetivo
- **Ruta Principal:** `frontend/src/components/ProductSearchModal.vue`
- **Componentes Auxiliares:**
  - `frontend/src/components/ProductFormModal.vue`
  - `frontend/src/views/InventoryView.vue`
- **Capa de Datos:** `frontend/src/stores/inventory.ts`

### B1.2 Cita Textual de la Sección 5 (Contrato de Interfaz) del SDD Fuente
```markdown
## 5. Contrato de Interfaz

### 5.1 Operación: Búsqueda Unificada de Productos en POS (`buscar_producto_pos`)
- **Tipo:** RPC Postgres / Lectura (READ) — *Ejecutable transitoriamente como consulta PostgREST indexada*
- **Entradas:**
  ```json
  {
    "p_store_id": "UUID (Obligatorio, resuelto por sesión)",
    "p_term": "TEXT (Obligatorio, código PLU o texto alfabético)",
    "p_limit": "INTEGER (Opcional, default: 10, máx: 50)",
    "p_offset": "INTEGER (Opcional, default: 0)"
  }
  ```
- **Reglas de Transformación del Backend:**
  1. Si `p_term` coincide exactamente con un PLU activo (`plu = p_term AND is_active = true`), retorna la tupla única con `match_type = 'exact_plu'`.
  2. Si `p_term` contiene caracteres alfabéticos y `length(p_term) >= 2`, ejecuta búsqueda parcial `name ILIKE ('%' || p_term || '%')`, filtrando estrictamente `is_active = true AND current_stock > 0`, ordenada por coincidencia de texto, retornando `match_type = 'partial_name'`.
  3. Si `p_term` tiene longitud < 2 y no es numérico, aborta con `TERM_TOO_SHORT`.
  4. Los campos de costo (`cost_price`) quedan estrictamente omitidos del payload.

- **Salida Exitosa (Formato Unidireccional de Lista Enriquecida):**
  ```json
  {
    "data": [
      {
        "id": "UUID",
        "name": "Arroz Diana 1kg",
        "plu": "1001",
        "price": 4200.00,
        "current_stock": 45.00,
        "measurement_unit": "unidad",
        "is_weighable": false
      }
    ],
    "count": 1,
    "match_type": "exact_plu"
  }
  ```
```

### B1.3 CHECKPOINT Bloque 1
Cierre del Bloque 1 formalizado. Componente identificado y Sección 5 citada textualmente.

---

## Bloque 2 — Verificación Mecánica del Contrato de Payload

### Operación: Búsqueda Unificada en POS (`buscar_producto_pos`)
- **Parámetros `p_term`, `p_limit`, `p_offset`:**
  - Código real: En `ProductSearchModal.vue:27-32`:
    ```typescript
    const filteredProducts = computed(() => {
      if (!searchQuery.value.trim()) {
        return inventoryStore.products.slice(0, 20); // Show first 20 if no search
      }
      return inventoryStore.searchProducts(searchQuery.value);
    });
    ```
  - La búsqueda se ejecuta de manera local en JavaScript sobre la matriz de productos en memoria de Pinia (`inventoryStore.products`), sin invocar la operación unificada `buscar_producto_pos` ni consultar el backend con los parámetros contractuales.
  - Resultado: **Ausente en llamada al backend (Búsqueda Client-Side en memoria)**.
- **Asignación y Validación de PLU en Catálogo:**
  - Código real: En `ProductFormModal.vue:142-143`:
    ```typescript
    // PLU requerido y ESTRICTAMENTE 3 dígitos numéricos
    const isPluValid = plu !== '' && plu.length === 3 && /^\d+$/.test(plu);
    ```
  - Contrato SDD-006-03: Permite códigos numéricos de hasta 10 dígitos (ej. "1001"), y en el Caso E autoriza explícitamente dejar el campo de PLU en blanco para autogenerar el siguiente número consecutivo disponible.
  - Resultado: **Discrepancia Rígida en Validación Frontend (Bloquea Caso E y PLUs > 3 dígitos)**.

### B2.5 CHECKPOINT Bloque 2
Se confirman fallas de contrato: el modal de búsqueda opera en memoria sin backend authority, y el modal de productos bloquea la autogeneración de PLU exigiendo exactamente 3 dígitos.

---

## Bloque 2b — Verificación de Backend Authority

- **B2.6 Búsqueda de Cálculos en Cliente:**
  - En `inventoryStore.ts:306-316`, `searchProducts` realiza el filtrado de texto, PLU y categoría en cliente.
- **B2.7 CHECKPOINT Bloque 2b:**
  - La búsqueda de inventario y resolución de PLU se delega a JavaScript en el cliente en vez de al motor indexado de Postgres.

---

## Bloque 3 — Matriz de Estados vs. Manejo Real

### B3.8 Estados del Diagrama de Estados (SDD-006-03 §3)
1. `LookupPLU` -> Coincidencia exacta (retorna tupla única).
2. `LookupTexto` -> Búsqueda alfabética (>= 2 caracteres).
3. `ErrorNoEncontrado` -> "No se encontraron productos".
4. `AutogenerarSecuencial` -> Asignación de código consecutivo si el campo está vacío.

### B3.9 Búsqueda en Código
- **Estado 1 y 2:** Unificados en un `filter` de array en `inventoryStore.ts:306-316`. No diferencia la inyección directa en ticket en < 1s vs menú de sugerencias.
- **Estado 3:** `ProductSearchModal.vue:94-100` (`v-if="filteredProducts.length === 0"` muestra icono `SearchX` y mensaje "No se encontraron productos"). **Conforme**.
- **Estado 4:** Inexistente en `ProductFormModal.vue` debido a la validación rígida `plu !== ''`. **Ausente en UI**.

### B3.10 Cruce Explícito
- Estado 1: Parcial (resuelto en memoria).
- Estado 2: Parcial (resuelto en memoria).
- Estado 3: Sí.
- Estado 4: No (bloqueado por validación client-side).

### B3.11 CHECKPOINT Bloque 3
3 de los 4 estados funcionales presentan omisiones o desviaciones respecto a la especificación.

---

## Bloque 4 — Verificación contra SPEC-011

- **B4.12 Formateo:**
  - En `ProductSearchModal.vue:47-58`:
    ```typescript
    const formatCurrency = (price: Decimal | number | string) => {
      let value: number;
      if (typeof price === 'object' && 'toNumber' in price) {
        value = price.toNumber();
      } else {
        value = typeof price === 'string' ? parseFloat(price) : price;
      }
      return `$ ${Math.round(value)
        .toString()
        .replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
    };
    ```
  - Contraviene el uso del composable estándar centralizado `useCurrencyFormat`.
- **B4.13 CHECKPOINT Bloque 4:**
  - Falla menor por formateo monetario manual en lugar del composable oficial del proyecto.

---

## Bloque 5 — Verificación de Permisos / Rol

- **B5.14 Restricciones:**
  - Búsqueda en POS: Permitida a cualquier cajero o administrador con turno abierto.
  - Creación de producto / PLU: Restringida a personal con permiso `canManageInventory`.
- **B5.15 Implementación:**
  - `ProductFormModal.vue` solo es accesible si `canManageInventory` está activo en `InventoryView.vue:227, 308`.
- **B5.16 CHECKPOINT Bloque 5:**
  - Conforme en control de permisos de creación.

---

## 📋 Resumen de Hallazgos

| ID | Hallazgo | Bloque de Origen | Severidad |
|---|---|---|---|
| UX-1 | Validación client-side rígida en `ProductFormModal.vue:143` que exige PLU obligatorio y estrictamente de 3 dígitos (`plu !== '' && plu.length === 3`), bloqueando la autogeneración secuencial (Caso E de SDD-006-03) y rechazando PLUs de 1, 2, o 4 dígitos (como el ejemplo '1001' del SDD). | Bloque 2 (B2.4) | 🔴 Alta |
| UX-2 | Búsqueda unificada en POS ejecutada en memoria local en `ProductSearchModal.vue:27-32` (`inventoryStore.searchProducts`) sobre el array local en vez de consumir la operación `buscar_producto_pos` de SDD-006-03 §5.1 con filtro de stock activo (`current_stock > 0`). | Bloque 2 (B2.4) | 🔴 Alta |
| UX-3 | Implementación de formateo monetario manual en `ProductSearchModal.vue:47-58` en lugar de utilizar el composable centralizado `useCurrencyFormat` (SPEC-011). | Bloque 4 (B4.12) | 🟡 Media |

---

## 🚦 Dimensión Frontend para Estado Compuesto

- **Evaluación Frontend:** `🔴 Fallas Críticas / Incompleto`
- **Impacto en Estado Compuesto:**
  - Al identificarse 2 hallazgos de severidad ALTA (UX-1, UX-2), el frontend aporta `🔴` (Estado general: `🟡 Backend Listo / Frontend Incompleto`).

---

## 📌 Instrucción para el Orquestador (/orchestrator)
1. Flexibilizar la validación de PLU en `ProductFormModal.vue` para aceptar entre 1 y 10 dígitos numéricos y permitir que permanezca en blanco para disparar la autogeneración del siguiente consecutivo disponible.
2. Migrar `ProductSearchModal.vue` para consumir la búsqueda indexada del backend (`buscar_producto_pos`), garantizando filtro de productos activos con stock positivo.
3. Reemplazar la función `formatCurrency` manual de `ProductSearchModal.vue` por el composable `useCurrencyFormat`.
