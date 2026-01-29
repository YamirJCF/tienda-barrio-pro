# Solicitud de Trabajo: Auditoría e Implementación UX/UI

> **De:** Arquitecto de Producto y Requisitos
> **Para:** Equipo UX/UI (@[/ux])
> **Fecha:** 2026-01-28
> **Prioridad:** Alta
> **Estado:** 🚧 EN BORRADOR

---

## 1. Contexto

La fase de Backend (Arquitectura de Datos) ha concluido exitosamente con la validación de 14 FRDs y un esquema de base de datos robusto.
Actualmente, el Frontend existente fue desarrollado en fases previas y **no está alineado** con los últimos documentos de requisitos funcionales (FRDs). Existen discrepancias en flujos, campos de datos faltantes y reglas de negocio no implementadas visualmente.

## 2. Objetivo

El Equipo UX/UI DEBE realizar una **Auditoría Integral** del frontend actual comparándolo contra los FRDs vigentes. No se trata de reconstruir desde cero, sino de:
1.  **Identificar la brecha** (Gap Analysis) entre lo que hay y lo que piden los FRDs.
2.  **Documentar las discrepancias** en una lista de tareas priorizada.
3.  **Ejecutar las correcciones** necesarias para alcanzar la conformidad total.

---

## 3. Documentos de Entrada (La Verdad)

El Equipo UX/UI debe contrastar la interfaz actual visual (`src/views`, `src/components`) contra:

| Módulo | FRD de Referencia | Foco de la Auditoría |
|--------|-------------------|----------------------|
| **Auth** | `FRD_001`, `FRD_002`, `FRD_013` | Flujos de login, pines, registro tienda/empleado. |
| **Personal** | `FRD_003` | Gestión de empleados, permisos visuales, modales. |
| **Caja (POS)** | `FRD_004`, `FRD_004.1` | Apertura/Cierre, manejo de dinero, control de PINs. |
| **Inventario** | `FRD_006` | Catálogo, stock, movimientos, visualización de alertas. |
| **Ventas** | `FRD_007` | Carrito, cálculos (visuales), ticket, métodos de pago. |
| **Clientes** | `FRD_009` | Fiados, abonos, historial de cliente. |
| **Reportes** | `FRD_008` | Visualización de cortes, gráficas, totales. |
| **Offline** | `FRD_012` | Indicadores de estado, bloqueo de acciones críticas. |
| **Errores** | `FRD_011` | Feedback al usuario, toasts, estados de error. |
| **General** | `FRONTEND_STANDARDS.md` | Uso de componentes base, colores, tipografía. |

---

## 4. Entregables Esperados

### 4.1 Reporte de Auditoría (Gap Analysis)
Un documento vivo que liste cada discrepancia encontrada.
- **Ubicación:** `02_ARCHITECTURE/UX_AUDIT_REPORT.md`
- **Formato:**
  ```markdown
  | ID | Módulo | Discrepancia | Severidad | Estado |
  |----|--------|--------------|-----------|--------|
  | UX-001 | POS | Falta botón de "Retiro Parcial" | Alta | 🔴 Pendiente |
  | UX-002 | Login | Input de PIN no está enmascarado | Media | 🟢 Resuelto |
  ```

### 4.2 Ejecución de Cambios (Código)
Modificación directa del código fuente Vue.js para resolver los hallazgos.
- Refactorización de vistas.
- Creación de componentes faltantes.
- Conexión simulada (mocks) si el backend no está integrado aún.

### 4.3 Actualización Documental
Si durante la auditoría se descubren mejoras de UX "obvias" que contradicen o mejoran el FRD, se debe solicitar la actualización del FRD mediante un comentario.

---

## 5. Proceso de Trabajo (Iterativo)

Recomendamos abordar la auditoría por módulo funcional:

1.  **Auditar Módulo X**: Leer FRD vs. Ver Código. Anotar hallazgos.
2.  **Planificar Correcciones**: Agrupar tareas.
3.  **Ejecutar Refactor**: Codificar soluciones.
4.  **Verificar**: Confirmar que cumple el FRD.
5.  *Siguiente Módulo*.

---

## 6. Criterios de Aceptación de la Fase

- [ ] Existe un `UX_AUDIT_REPORT.md` completo.
- [ ] Todas las discrepancias de Severidad "Alta" y "Media" están resueltas.
- [ ] El frontend utiliza los tipos de datos generados por Supabase (o compatibles).
- [ ] La UI maneja correctamente los estados de carga y error definidos en el estándar.
- [ ] **Aprobación Visual**: El usuario final (User) da el visto bueno a la estética y flujo.

---

## Firma

**Arquitecto de Producto**
2026-01-28
