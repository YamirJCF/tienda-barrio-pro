# Documentación de Arquitectura de Dependencias

> **Rol:** Arquitecto  
> **Estado:** VIGENTE  
> **Última Actualización:** 2026-01-28  
> **Versión:** 2.0

Este documento sirve como fuente única de verdad para las dependencias tecnológicas del proyecto.

---

## 1. Frontend (NPM)

Ubicación: `SRC/package.json`

### 📦 Dependencias de Producción

| Paquete | Versión | Licencia | Propósito / Justificación | Nivel de Riesgo |
|---------|---------|----------|---------------------------|-----------------|
| `vue` | `^3.5.25` | MIT | Framework reactivo principal. | 🟢 Bajo |
| `pinia` | `^3.0.4` | MIT | Gestión de estado global. Estándar oficial de Vue. | 🟢 Bajo |
| `pinia-plugin-persistedstate` | `^4.7.1` | MIT | Persistencia de estado en almacenamiento local. | 🟢 Bajo |
| `vue-router` | `^4.6.4` | MIT | Enrutamiento SPA. | 🟢 Bajo |
| `lucide-vue-next` | `^0.460.0` | ISC | Set de iconos SVG ligeros y consistentes. | 🟢 Bajo |
| `decimal.js` | `^10.6.0` | MIT | **CRÍTICO**. Aritmética de precisión arbitraria para manejo financiero. | 🟢 Bajo |
| `@supabase/supabase-js` | `^2.91.0` | MIT | Cliente oficial de Supabase para autenticación y base de datos. | 🟢 Bajo |
| `idb` | `^8.0.3` | ISC | Wrapper para IndexedDB. Soporte offline y caché local. | 🟢 Bajo |
| `vue-virtual-scroller` | `^2.0.0-beta.8` | MIT | Optimización de rendimiento para listas largas. **Nota:** Versión beta. | 🟡 Medio |

### 🛠️ Dependencias de Desarrollo

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `vite` | `^6.2.0` | Build tool ultra-rápido. |
| `vitest` | `^4.0.17` | Framework de testing unitario. |
| `typescript` | `~5.8.2` | Tipado estático. |
| `tailwindcss` | `^4.1.18` | Framework CSS utility-first. |
| `@tailwindcss/postcss` | `^4.1.18` | Integración PostCSS para Tailwind. |
| `happy-dom` | `^20.3.3` | Entorno DOM simulado para pruebas. |
| `@vue/test-utils` | `^2.4.6` | Utilidades de testing para Vue. |
| `eslint` | `^9.39.2` | Linter de código. |
| `prettier` | `^3.8.0` | Formateador de código. |
| `@vitejs/plugin-vue` | `^5.0.0` | Plugin Vue para Vite. |

---

## 2. Backend (Supabase / PostgreSQL)

### 🏗️ Arquitectura

| Componente | Estado | Propósito |
|------------|--------|-----------|
| **Auth** | Activo | Autenticación de Admin (email + contraseña) |
| **Database** | Activo | PostgreSQL - Motor principal |
| **Storage** | Disponible | Para futuras imágenes de productos |
| **Realtime** | Pendiente | Para notificaciones en tiempo real |

### 🧩 Extensiones Requeridas

| Extensión | Propósito |
|-----------|-----------|
| `pgcrypto` | Funciones criptográficas para hashear PINs |
| `uuid-ossp` | Generación de identificadores únicos |

> **Nota:** El esquema de base de datos se define en documentos DSD (Data Specification Document) basados en los FRDs vigentes. Ver sección de Trazabilidad.

---

## 3. Variables de Entorno

Archivo: `.env` (No versionado)

| Variable | Descripción | Requerida |
|----------|-------------|-----------|
| `VITE_SUPABASE_URL` | URL del proyecto Supabase | ✅ Sí |
| `VITE_SUPABASE_ANON_KEY` | Clave pública anónima | ✅ Sí |

---

## 4. Política de Gobernanza de Dependencias

> "Cada línea de código es un pasivo. Cada dependencia es un riesgo."

### Regla 1: Justificación Económica

No se instalará ninguna librería a menos que:
1. **Resolverlo a mano tome > 4 horas:** Si es una utilidad simple, colocarla en carpeta de utilidades.
2. **Mantenimiento activo:** El repositorio debe tener commits en los últimos 3 meses.
3. **Tamaño controlado:** Verificar impacto en tamaño del bundle.

### Regla 2: Auditoría Semestral

Se revisarán todas las dependencias cada 6 meses (Enero/Julio) para:
- Actualizar versiones menores
- Eliminar librerías no utilizadas
- Reemplazar librerías pesadas por alternativas nativas

---

## 5. Análisis de Eficiencia del Stack

| Decisión | Alternativa Descartada | Razón |
|----------|------------------------|-------|
| **Supabase (BaaS)** | Backend Propio | Costo $0/mes inicial. Ahorro de ~40h en setup. PostgreSQL estándar. |
| **Vue 3 + Vite** | React / Webpack | Curva de aprendizaje menor, tooling más rápido. |
| **TailwindCSS** | CSS Modules / Sass | Estandariza diseño, evita crecimiento descontrolado de estilos. |
| **Pinia** | Vuex | API más limpia, menos boilerplate, mejor soporte TypeScript. |
| **IndexedDB (idb)** | LocalStorage | Soporte para datos estructurados y mayor capacidad offline. |

---

## 6. Trazabilidad

### Documentos de Referencia

| Tipo | Ubicación | Descripción |
|------|-----------|-------------|
| **FRDs** | `01_REQUIREMENTS/FRD/` | Requisitos funcionales (Fuente de Verdad) |
| **TECH_SPECS** | `01_REQUIREMENTS/TECH_SPECS/` | Especificaciones técnicas de implementación |
| **DSDs** | Pendiente de creación | Especificaciones de datos basadas en FRDs |

### Estado de Sincronización

| Artefacto | Estado | Acción Requerida |
|-----------|--------|------------------|
| `supabase-schema.sql` | ⚠️ DESACTUALIZADO | Regenerar desde FRDs actualizados |
| `data_models/*.md` | ⚠️ DESACTUALIZADO | Regenerar desde FRDs actualizados |
| FRDs (14 documentos) | ✅ VIGENTE | Fuente de verdad actual |

---

## Changelog

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 2.0 | 2026-01-28 | Actualización completa: versiones NPM, eliminación de referencias a schema obsoleto, nueva sección de trazabilidad |
| 1.0 | 2026-01-20 | Versión inicial con auditoría QA |
