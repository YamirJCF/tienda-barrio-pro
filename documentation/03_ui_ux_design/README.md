# 📐 Diseño UX/UI - Tienda de Barrio Pro

> **Última actualización:** 2026-01-15  
> **Autor:** Agente UX/UI Designer  
> **Stack:** Vue 3 + Pinia + TailwindCSS 4 | Mobile-First

---

## 📋 Índice de Documentos

| # | Documento | Descripción |
|---|-----------|-------------|
| 01 | [User Flows](./01_USER_FLOWS.md) | Flujos de usuario paso a paso |
| 02 | [Arquitectura de Información](./02_INFORMATION_ARCHITECTURE.md) | Mapa de navegación y taxonomía |
| 03 | [Wireframes Descriptivos](./03_WIREFRAMES_DESCRIPTIVOS.md) | Descripción detallada de pantallas |
| 04 | [Design System](./04_DESIGN_SYSTEM.md) | Guía de estilo funcional |
| 05 | [Lógica de Componentes](./05_COMPONENT_LOGIC.md) | Comportamiento e interacciones |

### 📂 Documentación Modular
| Directorio | Descripción |
|------------|-------------|
| `UXD/` | Documentos de diseño UX específicos por módulo (ej. `UXD_008_SMART_SUPPLY.md`) |

---

## 🎯 Principios de Diseño

1. **Mobile-First** - Diseño primario para viewport 375px
2. **Reducción de Carga Cognitiva** - Tareas en mínimos toques
3. **Consistencia** - Componentes reutilizables
4. **Accesibilidad** - Contrastes WCAG AA, fuentes legibles

---

## 👥 User Personas

| Persona | Autenticación | Permisos |
|---------|---------------|----------|
| **Dueño (Admin)** | Email + Contraseña | Acceso total |
| **Empleado** | Username + PIN 4 dígitos | Según configuración |

---

## 🔗 Referencias

- [PRD](../01_REQUIREMENTS/prd_tienda_de_barrio.md)
- [Esquema DB](../02_ARCHITECTURE/supabase-schema.sql)
- [Mapa de Lógica](../04_DEV_ORCHESTRATION/MAPA_LOGICA_GLOBAL.md)
