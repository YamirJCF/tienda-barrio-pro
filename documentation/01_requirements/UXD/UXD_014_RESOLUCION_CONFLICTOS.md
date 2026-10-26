# UXD-014: Resolución de Conflictos y Auditoría (Protocolo de Excepción)

> **Basado en:** FRD-014 V1.4 (Protocolo de Excepción)
> **Referencia:** FRD-007 (Flujo Estándar de Ventas)

### Mapa de Navegación del Protocolo de Excepción

```mermaid
graph TD
    A[POS: Intento de Venta] --> B{¿Hay Stock Suficiente?}
    B -->|Sí (Cumple FRD-007)| C[Procesar Venta Normal]
    B -->|No (Viola FRD-007)| D{¿Rol del Usuario?}
    
    D -->|Empleado| E[❌ ERROR BLOQUEANTE]
    E --> F(Toast Error: "Stock Insuficiente")
    
    D -->|Administrador| G[⚠️ FLUJO DE EXCEPCIÓN]
    G --> H[Modal de Fuerza Mayor]
    H -->|Confirmar + Justificar| I[Ejecutar RPC Excepción]
    I --> C
```

---

## Pantallas / Componentes

### 1. Interceptación en POS (`POSView`)
El POS actúa como el primer filtro de seguridad.

#### Escenario A: Usuario es Empleado (Cumplimiento FRD-007)
SI `stock < cantidad` Y `!isAdmin`:
- **Acción:** Bloquear intento de venta.
- **Feedback Visual (Toast Error):**
    - **Icono:** ⛔ (`XCircle`)
    - **Título:** "Operación Bloqueada"
    - **Mensaje:** "No hay suficiente stock para realizar esta venta. Solicite ayuda a un administrador."
    - **Duración:** 5000ms.

#### Escenario B: Usuario es Admin (Inicio FRD-014)
SI `stock < cantidad` Y `isAdmin`:
- **Acción:** Abrir `ForceSaleModal`.
- **Feedback Visual:** No se muestra error, se presenta la solución de excepción.

---

### 2. Componente: `ForceSaleModal` (Reutilizable)
Este componente es crítico. Debe comunicar que se está realizando una "cirugía" al inventario.

- **Estilo:** `Warning` (Bordes y acentos en Ámbar/Naranja). NO usar rojo (Rojo es error/bloqueo).
- **Iconografía:** `ShieldAlert` o `AlertTriangle`.

#### Estructura del Modal
| Sección | Contenido / Comportamiento |
|---------|----------------------------|
| **Encabezado** | Título: "Protocolo de Excepción Administrativa" <br> Subtítulo: "Detectamos inconsistencia entre físico y sistema." |
| **Cuerpo** | **Alerta:** "Se inyectará inventario de corrección para permitir esta venta." <br> **Tabla Resumen:** Lista de items afectados (Producto, Stock Actual, Cantidad Solicitada, Diferencia). |
| **Formulario** | **Label:** "Justificación de Auditoría (Obligatorio)" <br> **Input:** Textarea. <br> **Validación:** Mínimo 10 caracteres. Muestra contador `0/10`. |
| **Footer** | **Botón Cancelar:** "Regresar" (Cierra modal, no hace nada). <br> **Botón Acción:** "Autorizar Excepción y Vender". Deshabilitado si justificación < 10 chars. |

---

### 3. Panel de Conflictos Offline (`ConflictResolver`)
- **Visualización:** Lista de ventas fallidas en la cola.
- **Estado 'Falta de Stock':**
    - **Para Empleado:** Muestra badge "Requiere Admin" y botón "Forzar" deshabilitado.
    - **Para Admin:** Muestra botón "Forzar Venta" (Color Warning). Al pulsar, abre `ForceSaleModal`.

---

### 4. Bloqueo de Cierre (`CashClose`)
- **Regla:** Si `SyncQueue.DLQ.length > 0`, el cierre se deshabilita.
- **Banner de Bloqueo:**
    - **Color:** Rojo Intenso (`bg-red-600`).
    - **Mensaje:** "CRÍTICO: Existen conflictos de inventario pendientes. No se puede cerrar caja hasta resolverlos."
    - **Acción:** Botón "Ir a Resolver" (Redirige a `/admin/sync`).

---

### 5. Protocolo de Bloqueo por Edición Concurrente (Integridad de Datos y Seguridad)
- **Disparador:** La invocación RPC de edición de catálogo retorna código `CONCURRENT_MUTATION_BLOCKED` o `MUTATION_COOLDOWN_ACTIVE`.
- **Comportamiento UX Obligatorio:**
  1. **Cierre Inmediato del Modal:** El formulario de edición (`ProductFormModal`, `ClientFormModal`) se cierra de forma inmediata para impedir que el operador reintente con datos obsoletos.
  2. **Bloqueo Definitivo (Sin Override Manual):** En colisiones de concurrencia queda terminantemente prohibido permitir "Forzar guardado" o "Sobrescribir", ya que constituye un riesgo de corrupción contable o sospecha de alteración (*tampering*).
  3. **Toast de Notificación Crítica:**
     - **Icono:** 🛡️ (`ShieldAlert`)
     - **Color:** Rojo Intenso de Seguridad (`bg-red-700 text-white`)
     - **Título:** "Operación Bloqueada por Seguridad e Integridad"
     - **Mensaje:** "Este registro fue modificado recientemente desde otra cuenta o terminal. Por seguridad, tus cambios fueron rechazados y se descargaron los datos vigentes."
     - **Duración:** 7000ms.
  4. **Auto-Purga y Recarga Reactiva:** El cliente invalida de inmediato la clave en `SystemCacheManager` y actualiza la lista o tabla visual con la verdad de PostgreSQL.
