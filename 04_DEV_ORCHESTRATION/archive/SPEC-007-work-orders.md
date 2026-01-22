# ⚙️ SPEC-007: Órdenes de Trabajo para Ejecución

**Orquestador:** Antigravity  
**Fecha:** 2026-01-16  
**Rama Base:** `feat/spec-007-ui-optimization`

---

## 🔀 Estrategia Git

```bash
# Crear rama principal de feature
git checkout -b feat/spec-007-ui-optimization

# Sub-ramas por fase (opcional para PRs separados)
# feat/spec-007-phase1-critical
# feat/spec-007-phase2-ux
# feat/spec-007-phase3-reorganize
```

---

# FASE 1: Correcciones Críticas

## WO-001: Eliminar Sample Data de Inventory

**Agente:** Antigravity (directo)  
**Tiempo estimado:** 5 min  
**Prioridad:** 🔴 CRÍTICA

### Contexto
El archivo `inventory.ts` contiene una función `initializeSampleData()` que carga productos de ejemplo cada vez que el store está vacío.

### Objetivo
Eliminar completamente la función y sus referencias.

### Archivos a Modificar
- `03_SRC/src/stores/inventory.ts` → Eliminar líneas 137-146 y la exportación

### Restricciones
- ⚠️ NO tocar: `addProduct()`, `updateProduct()`, `deleteProduct()`, `updateStock()`
- NO modificar el serializer

### Definición de Hecho
- [ ] `initializeSampleData` no existe en el código
- [ ] App inicia con inventario vacío

---

## WO-002: Eliminar Sample Data de Employees

**Agente:** Antigravity (directo)  
**Tiempo estimado:** 5 min  
**Prioridad:** 🔴 CRÍTICA

### Contexto
Similar a inventory, `employees.ts` tiene datos de ejemplo.

### Objetivo
Eliminar `initializeSampleData()` del store de empleados.

### Archivos a Modificar
- `03_SRC/src/stores/employees.ts` → Eliminar función sample data

### Restricciones
- ⚠️ NO tocar: `addEmployee()`, `updateEmployee()`, `validatePin()`

### Definición de Hecho
- [ ] App inicia sin empleados pre-cargados (excepto cuenta demo)

---

## WO-003: Eliminar Archivo sampleData.ts

**Agente:** Antigravity (directo)  
**Tiempo estimado:** 2 min  
**Prioridad:** 🟠 ALTA

### Objetivo
Eliminar el archivo que contiene los datos de ejemplo.

### Archivos a Eliminar
- `03_SRC/src/data/sampleData.ts`

### Verificación Previa
Buscar referencias con: `grep -r "sampleData" 03_SRC/src/`

### Definición de Hecho
- [ ] Archivo eliminado
- [ ] No hay errores de importación

---

## WO-004: Integrar Sección Seguridad en AdminHub

**Agente:** Antigravity + @[/ux]  
**Tiempo estimado:** 20 min  
**Prioridad:** 🔴 CRÍTICA

### Contexto
Los modales de PIN (PinSetupModal, PinResetModal) existen pero no están integrados en la UI.

### Objetivo
Agregar sección "Seguridad" en AdminHub con acceso a configuración de PIN.

### Archivos a Modificar
- `03_SRC/src/views/AdminHubView.vue` → Agregar sección

### Template de Código
```vue
<!-- Sección Seguridad (después de Equipo y Tienda) -->
<section v-if="activeTab === 'gestion'">
  <h3 class="text-lg font-bold mb-3 px-1">🔐 Seguridad</h3>
  <div class="flex flex-col rounded-xl bg-white dark:bg-slate-800 shadow-sm border divide-y">
    <button @click="showPinSetupModal = true" class="...">
      Configurar PIN de Caja
    </button>
    <button @click="showPinResetModal = true" class="...">
      Cambiar/Resetear PIN
    </button>
  </div>
</section>

<!-- Importar y usar modales -->
<PinSetupModal v-model="showPinSetupModal" mode="setup" />
<PinResetModal v-model="showPinResetModal" />
```

### Restricciones
- ⚠️ LOCKFILE: NO modificar lógica de `salesStore` ni cálculos de caja

### Definición de Hecho
- [ ] Botón "Configurar PIN" visible en AdminHub
- [ ] Modal abre correctamente
- [ ] PIN se puede guardar

---

## WO-005: Validación de Monto Obligatorio en Modal

**Agente:** Antigravity  
**Tiempo estimado:** 10 min  
**Prioridad:** 🟠 ALTA

### Contexto
El modal de apertura/cierre permite iniciar sin ingresar un monto.

### Objetivo
El botón "Aceptar" debe estar deshabilitado si `amount === 0` y no hay confirmación explícita.

### Archivos a Modificar
- `03_SRC/src/components/CashControlModal.vue`

### Cambio Requerido
Agregar computed y :disabled al botón:
```typescript
const canProceed = computed(() => amount.value > 0 || showZeroConfirm.value);
```

### Definición de Hecho
- [ ] No se puede avanzar con $0 sin confirmación

---

# FASE 2: Mejoras UX

## WO-006: Ocultar Scrollbar en Inventario

**Agente:** Antigravity  
**Tiempo estimado:** 5 min  
**Prioridad:** 🟡 MEDIA

### Objetivo
La barra de scroll visible es fea. Ocultarla manteniendo funcionalidad.

### Archivos a Modificar
- `03_SRC/src/views/InventoryView.vue` → Agregar CSS

### Código CSS
```css
/* Ya existe .no-scrollbar pero aplicarlo al contenedor main */
main {
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE/Edge */
}
main::-webkit-scrollbar {
  display: none; /* Chrome/Safari */
}
```

### Definición de Hecho
- [ ] Scrollbar no visible en Chrome, Firefox, Safari

---

## WO-007: Eliminar Funciones Redundantes de AdminHub

**Agente:** Antigravity + @[/ux]  
**Tiempo estimado:** 10 min  
**Prioridad:** 🟡 MEDIA

### Objetivo
Eliminar "Configuración de Negocio" y "Dispositivos Autorizados" del AdminHub.

### Archivos a Modificar
- `03_SRC/src/views/AdminHubView.vue`

### Definición de Hecho
- [ ] Solo quedan: Empleados, Control de Caja, Gastos, Seguridad

---

## WO-008: Mover Reportes a BottomNav

**Agente:** Antigravity + @[/ux]  
**Tiempo estimado:** 15 min  
**Prioridad:** 🟠 ALTA

### Objetivo
Reportes es el core value de la app. Debe ser accesible desde BottomNav.

### Archivos a Modificar
- `03_SRC/src/components/BottomNav.vue`

### Nuevo orden de tabs:
```
📦 Inventario | 🛒 POS | 🏠 Home | 📊 Reportes | ⚙️ Admin
```

### Definición de Hecho
- [ ] Reportes visible en BottomNav
- [ ] Navegación funciona

---

# FASE 3: Verificación QA

## WO-009: Validar Delete Product

**Agente:** @[/qa]  
**Tiempo estimado:** 10 min

### Test Case
1. Ir a Inventario
2. Crear producto
3. Click en botón eliminar
4. Verificar que desaparece de la lista

### Resultado Esperado
Producto se elimina correctamente.

---

## WO-010: Validar Flujo PIN Completo

**Agente:** @[/qa]  
**Tiempo estimado:** 15 min

### Test Cases
1. Configurar PIN por primera vez
2. Abrir caja con PIN
3. Cerrar caja con PIN
4. Cambiar PIN
5. Rate limiting (5 intentos fallidos)

---

# 📋 Resumen de Asignaciones

| WO | Descripción | Agente | Prioridad |
|----|-------------|--------|-----------|
| WO-001 | Eliminar sample data inventory | Antigravity | 🔴 |
| WO-002 | Eliminar sample data employees | Antigravity | 🔴 |
| WO-003 | Eliminar archivo sampleData.ts | Antigravity | 🟠 |
| WO-004 | Integrar PIN en AdminHub | Antigravity + /ux | 🔴 |
| WO-005 | Validación monto > 0 | Antigravity | 🟠 |
| WO-006 | Ocultar scrollbar | Antigravity | 🟡 |
| WO-007 | Eliminar redundantes | Antigravity + /ux | 🟡 |
| WO-008 | Reportes en BottomNav | Antigravity + /ux | 🟠 |
| WO-009 | Validar delete product | /qa | 🟠 |
| WO-010 | Validar flujo PIN | /qa | 🟠 |

---

## 🚀 Comando de Inicio

```bash
cd "c:\Users\Windows 11\OneDrive\Desktop\prueba"
git checkout -b feat/spec-007-ui-optimization
```
