# Órdenes de Trabajo - Fase 4: Finalización Empresarial y Handover

> **Fase**: 4 (Finalización de Interfaz y Estandarización)  
> **Fecha**: 2026-01-21  
> **Estado**: 📋 En Planificación  
> **Meta**: Cumplir los 3 pilares de aceptación (Data Handover, Deployment Ready, Enterprise UX).

---

## Pillar A: Autonomía Empresarial (Enterprise Grade)

### WO-PHASE4-001: Módulo de Configuración de Tienda
**Objetivo**: Que el dueño pueda personalizar su negocio sin tocar código.

| Campo | Valor |
|-------|-------|
| **Prioridad** | 🔴 Crítica |
| **Persistencia** | `configStore` (localStorage) |

- [ ] **T1.1**: Crear `stores/configStore.ts` con persistencia.
- [ ] **T1.2**: Implementar UI de Configuración en `AdminHubView`.
- [ ] **T1.3**: Reflejar configuración (Logo/Nombre) en `CheckoutModal` (Ticket).

### WO-PHASE4-002: Reportes Inteligentes (BI)
**Objetivo**: Transformar "datos" en "información" para la toma de decisiones.

| Campo | Valor |
|-------|-------|
| **Prioridad** | 🟠 Alta |

- [ ] **T2.1**: Filtros de Fecha en `ReportsContent.vue` (Hoy, Ayer, Semana).
- [ ] **T2.2**: Implementar lógica de comparación (Variación %).

---

## Pillar B: Validación para Equipo de Data (Data Handover)

### WO-PHASE4-003: Estandarización de Tipos Frontend-Backend
**Objetivo**: Que `src/types` sea un espejo exacto de `architecture-supabase.md`.

| Campo | Valor |
|-------|-------|
| **Prioridad** | 🔴 Crítica |
| **Referencia** | `architecture-supabase.md` |

- [ ] **T3.1**: Crear `src/types/supabase.ts`
  - Definir interfaces exactas para RPCs (`LoginResponse`, `SalePayload`).
  - Definir tablas Core (`InventoryMovement`, `AuditLog`).
- [ ] **T3.2**: Alinear `src/types/index.ts`
  - Mapear camelCase (Frontend) <-> snake_case (Backend).
  - Asegurar que `Employee` tenga los campos `permissions` del RPC.

---

## Pillar C: Despliegue sin Complicaciones (Deployment)

### WO-PHASE4-004: Verificación Final de Build
**Objetivo**: Entregar un artefacto limpio.

- [ ] **T4.1**: Ejecutar `npm run type-check`.
- [ ] **T4.2**: Verificar assets en build de producción (Iconos/Fuentes).
- [ ] **T4.3**: Generar `DEPLOYMENT_CHECKLIST.md`.

---

## Criterios de Aceptación Global (Definition of Done)
1. [ ] **Data Ready**: Tipos de TypeScript coinciden 100% con Schema SQL.
2. [ ] **Deploy Ready**: `npm run build` exitoso y assets verificados.
3. [ ] **Enterprise Ready**: App configurable y con reportes útiles.
