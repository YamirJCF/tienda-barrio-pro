# Observación UX/UI: Sistema de Notificaciones

> **Autor:** Agente UX/UI Designer  
> **Fecha:** 2026-01-15  
> **Referencia:** [notifications.md](../notifications.md)  
> **Estado:** ✅ Resuelto - Incorporado en FRD Final

---

## Resumen Ejecutivo

El sistema de notificaciones propuesto está **bien fundamentado** con prácticas sólidas (sistema dual toast/centro, persistencia limitada, estados claros). Las siguientes observaciones son **recomendaciones evolutivas**, no bloqueantes para la implementación.

---

## ✅ Aspectos Positivos

| Aspecto | Evaluación |
|---------|------------|
| Sistema Dual | Excelente separación toast (inmediato) vs Centro (persistente) |
| Categorización | 4 tipos claros: `security`, `inventory`, `finance`, `general` |
| Badge Condicional | Ocultar badge sin notificaciones reduce ruido visual |
| Estados Visuales | Diferenciación no leída/leída con borde + fondo es patrón probado |
| Límite 50 items | Previene degradación de UX por acumulación |

---

## ⚠️ Recomendaciones de Mejora

### 1. Iconografía por Categoría (Prioridad Alta)

Agregar iconos diferenciados para facilitar escaneo visual:

| Tipo | Icono | Color |
|------|-------|-------|
| `security` | 🔐 / `shield` | Rojo |
| `inventory` | 📦 / `inventory` | Naranja |
| `finance` | 💰 / `payments` | Verde |
| `general` | 🏪 / `store` | Azul |

### 2. Timestamps Relativos (Prioridad Alta)

Mostrar tiempos legibles en lugar de ISO:
- `Hace 5 min`, `Hace 2h`, `Ayer`, `15 Ene`

### 3. Agrupación por Día (Prioridad Media)

```
── Hoy ──────────────────────
[notificaciones de hoy]

── Ayer ─────────────────────
[notificaciones de ayer]
```

### 4. Swipe-to-Dismiss Mobile (Prioridad Baja)

Gesto de deslizar para eliminar items en móvil.

### 5. Filtros por Categoría (Prioridad Baja)

Tabs: `[Todas] [🔐] [📦] [💰]`

Útil cuando el volumen de notificaciones sea alto.

---

## 🔴 Puntos de Atención

| Issue | Impacto | Sugerencia |
|-------|---------|------------|
| Sin deep-linking | Click en "Stock Bajo" no navega al producto | Agregar `href` o `onClick` en items accionables |
| Empty State básico | Solo texto no es memorable | Agregar ilustración (campana con checkmark) |
| Sin feedback háptico | Notificaciones de seguridad pasan desapercibidas | Vibración para tipo `security` en móvil |

---

## 📐 Wireframe Sugerido

```
┌─────────────────────────────────────┐
│ [←] Notificaciones    [Marcar todo] │
├─────────────────────────────────────┤
│ [Todas] [🔐] [📦] [💰]              │
├─────────────────────────────────────┤
│ ── Hoy ─────────────────────────    │
│ ┌───────────────────────────────┐   │
│ │[📦] Stock Bajo: Leche         │   │
│ █    Quedan 3 unidades    • 2h  │   │
│ └───────────────────────────────┘   │
│ ── Ayer ────────────────────────    │
│ ┌───────────────────────────────┐   │
│ │[💰] Cierre de Caja            │   │
│ │     Balance: +$500      • 1d  │   │
│ └───────────────────────────────┘   │
└─────────────────────────────────────┘

Leyenda:
█ = Borde azul (no leída)
```

---

## 📊 Priorización Sugerida

| Feature | Prioridad | Fase |
|---------|-----------|------|
| Store + Badge dinámico | 🔴 Alta | MVP |
| Timestamps relativos | 🔴 Alta | MVP |
| Iconos por tipo | 🟠 Media | v1.1 |
| Agrupación por día | 🟡 Baja | v1.2 |
| Filtros por categoría | 🟡 Baja | v1.2 |
| Swipe-to-dismiss | 🟡 Baja | v1.2 |

---

## ✅ Veredicto

**Aprobado para implementación** con timestamps relativos e iconos por tipo como mejoras prioritarias.

---

## Acciones Sugeridas

- [ ] Agregar campo `icon` a interface `SystemNotification`
- [ ] Implementar helper `formatRelativeTime(date)` en composables
- [ ] Actualizar wireframe en `03_UI_UX_DESIGN/03_WIREFRAMES_DESCRIPTIVOS.md`
