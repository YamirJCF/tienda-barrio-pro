# Documentación de Arquitectura de Dependencias y Auditoría

> **Rol:** @[/architect] & @[/qa]
> **Estado:** ESTÁNDAR APROBADO

> **Última Auditoría:** 2026-01-20
> **Auditor:** @[/qa]
> **Versión:** 1.0

Este documento sirve como fuente única de verdad para las dependencias tecnológicas y el estado de seguridad de la arquitectura.

---

## 1. Frontend (NPM)

Ubicación: `SRC/package.json`

### 📦 Dependencias de Producción

| Paquete | Versión | Licencia | Propósito / Justificación | Nivel de Riesgo |
|---------|---------|----------|---------------------------|-----------------|
| `vue` | `^3.5.25` | MIT | Framework reactivo principal. | 🟢 Bajo |
| `pinia` | `^3.0.4` | MIT | Gestión de estado global. Estándar oficial de Vue. | 🟢 Bajo |
| `pinia-plugin-persistedstate` | `^4.7.1` | MIT | Persistencia de estado en localStorage (Vital para `authStore`). | 🟢 Bajo |
| `vue-router` | `^4.6.4` | MIT | Enrutamiento SPA. | 🟢 Bajo |
| `lucide-vue-next` | `^0.460.0` | ISC | Set de iconos SVG ligeros y consistentes. | 🟢 Bajo |
| `decimal.js` | `^10.6.0` | MIT | **CRÍTICO**. Aritmética de precisión arbitraria para manejo financiero. Evita errores de coma flotante (0.1 + 0.2 != 0.3). | 🟢 Bajo |
| `vue-virtual-scroller` | `^2.0.0-beta.8` | MIT | Optimización de rendimiento para listas largas (Inventario/Transacciones). **Nota:** Versión beta. | 🟡 Medio |

### 🛠️ Dependencias de Desarrollo (DevDeps)

| Paquete | Versión | Notas |
|---------|---------|-------|
| `vite` | `^6.2.0` | Build tool ultra-rápido. |
| `vitest` | `^4.0.17` | Framework de testing unitario compatible con Vite. |
| `typescript` | `~5.8.2` | Tipado estático. |
| `tailwindcss` | `^4.1.18` | Framework CSS utility-first. |
| `happy-dom` | `^20.3.3` | Entorno DOM simulado rápido para pruebas. |

---

## 2. Backend (Supabase / PostgreSQL)

Ubicación: `02_ARCHITECTURE/supabase-schema.sql`

### 🧩 Extensiones de Base de Datos

| Extensión | Estado | Propósito |
|-----------|--------|-----------|
| `pgcrypto` | **ACTIVA** | Funciones criptográficas (`crypt`, `gen_salt`) para hashear PINs. Vital para la seguridad. |
| `uuid-ossp` | Implícita | Generación de UUIDs v4 (`gen_random_uuid()`). |
| `pg_cron` | *Requerida* | Necesaria para limpieza automática de sesiones (`cleanup-expired-sessions`). Ver instrucciones en schema. |

### ⚡ Servicios Críticos Supabase

1.  **Auth (Authentication)**: Integrado pero gestionado custom via `employees` table para soporte de PIN.
2.  **Database (PostgreSQL)**: Motor principal.
3.  **Realtime**: No explícitamente habilitado en schema para tablas específicas todavía.

---

## 3. Variables de Entorno

Archivo: `.env` (No versionado)

```ini
# Conexión a Supabase
VITE_SUPABASE_URL=https://tu-proyecto.supabase.co
VITE_SUPABASE_ANON_KEY=tu-clave-anonima-publica

# Entorno
# VITE_APP_ENV=development # Opcional
```

---

## 4. Reporte de Auditoría QA - Dependencias y Seguridad

### Puntaje de Robustez: 85/100

### Matriz de Riesgos

| # | Severidad | Descripción | Archivo/Contexto |
|---|-----------|-------------|------------------|
| 1 | 🔴 **CRÍTICO** | **Falta RLS en tabla `stores`**. La tabla contiene `owner_pin_hash`. Si no se habilita RLS, un usuario autenticado malicioso podría descargar todos los hashes de PIN de dueños de tiendas. | `supabase-schema.sql` |
| 2 | 🟡 **MEDIO** | Dependencia `vue-virtual-scroller` está en beta (`^2.0.0-beta.8`). Podría tener bugs de renderizado en producción. | `package.json` |
| 3 | 🟡 **MEDIO** | El trigger `cron.schedule` para limpieza de sesiones requiere activación manual de la extensión `pg_cron` en el dashboard, no es automático por SQL. Riesgo operativo. | `supabase-schema.sql` (L1361) |
| 4 | 🔵 **BAJO** | Uso de `TEXT` para `measurement_unit` en lugar de `ENUM` nativo o tabla de referencia (aunque tiene `CHECK`). | `supabase-schema.sql` (L59) |

### Análisis de Resiliencia

1.  **Manejo de Errores SQL**:
    -   Las funciones RPC (`procesar_venta`, etc.) devuelven objetos JSON estandarizados `{ success: false, error: "..." }` en lugar de lanzar excepciones crudas (L818). **Excelente práctica** para desacoplar el frontend de errores de BD.

2.  **Continuidad Operativa (Offline)**:
    -   La tabla `sync_queue_failed` (L995) implementa un patrón **Dead Letter Queue**. Esto es **sobresaliente** para la resiliencia, permitiendo reintentar transacciones que fallaron por conectividad o concurrencia.

3.  **Integridad de Datos**:
    -   Uso sistemático de `DECIMAL(12,2)` para dinero y `DECIMAL(10,3)` para cantidades (L53, L56). Evita errores de redondeo financieros.
    -   Uso de librería `decimal.js` en frontend.

### Plan de Mitigación (Próximos Pasos)

1.  **PARCHE CRÍTICO SEGURIDAD**:
    -   Ejecutar: `ALTER TABLE stores ENABLE ROW LEVEL SECURITY;`
    -   Crear política: `CREATE POLICY "stores_read_own" ON stores FOR SELECT USING (id = (SELECT store_id FROM employees WHERE id = auth.uid()));` (O lógica equivalente para vincular usuario->tienda).
    -   *Mejor aún*: Mover `owner_pin_hash` a una tabla separada `store_secrets` con acceso restringido `SECURITY DEFINER` únicamente.

2.  **Estabilización Frontend**:
    -   Crear test de estrés de scroll en listas largas para validar `vue-virtual-scroller`.

3.  **Documentación**:
    -   Agregar paso de activación de `pg_cron` en el manual de despliegue `README.md`.

---

## 5. Política de Gobernanza de Dependencias (Plan de Austeridad)

> "Cada línea de código es un pasivo. Cada dependencia es un riesgo."

### Regla 1: Justificación Económica
No se instalará ninguna librería ("npm install") a menos que:
1.  **Resolverlo a mano tome > 4 horas:** Si es una utilidad de 10 líneas, cópiala en `utils/`.
2.  **Mantenimiento activo:** El repositorio debe tener commits en los últimos 3 meses.
3.  **Tamaño controlado:** Usar [Bundlephobia](https://bundlephobia.com) para verificar impacto.

### Regla 2: Auditoría Semestral
Se revisarán todas las dependencias cada 6 meses (Enero/Julio) para:
-   Actualizar versiones menores (Patch/Minor).
-   Eliminar librerías no utilizadas ("Dead Code").
-   Reemplazar librerías pesadas por nativas del navegador (e.g., usar `Intl.NumberFormat` en vez de librerías de formato si es posible, aunque `decimal.js` es excepción por precisión).

---

## 6. Análisis de Eficiencia del Stack

| Decisión | Alternativa Descartada | Razón Económica/Técnica |
|----------|------------------------|-------------------------|
| **Supabase (BaaS)** | Backend Propio (NestJS/Laravel) | **Coste Operativo:** $0/mes inicial. Ahorro de ~40h en setup de Auth/DB. PostgreSQL es estándar industrial. |
| **Vue 3 + Vite** | React / Webpack | **Velocidad de Desarrollo:** Curva de aprendizaje menor para el equipo, tooling más rápido (Vite vs Webpack). |
| **TailwindCSS** | CSS Modules / Sass | **Mantenibilidad:** Evita el crecimiento descontrolado de hojas de estilo. Estandariza el diseño sin "inventar" nombres de clases. |
| **Pinia** | Vuex | **Simplicidad:** API más limpia, menos boilerplate, mejor soporte TypeScript. |

