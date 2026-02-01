# Estrategia de QA Integral - Fase 2 (WO-PHASE2-005)

> **Auditor**: Agente de QA (Antigravity)
> **Fecha**: 2026-01-21
> **Alcance**: Inventario, POS, Control de Caja, Reportes.

## 1. Matriz de Riesgos y Cobertura

Validaremos los puntos críticos donde un fallo costaría dinero real al negocio.

| ID | Riesgo | Severidad | Mitigación a Probar |
|----|--------|-----------|--------------------|
| R-01 | **Venta sin Stock** | 🔴 Crítica | Intentar vender más de lo disponible. |
| R-02 | **Caja Descuadrada** | 🔴 Crítica | Vender X monto y verificar que Caja tenga `Base + X`. |
| R-03 | **Evasión de Cierre** | 🟠 Alta | Intentar vender con la tienda "Cerrada" (bypass UI). |
| R-04 | **Permisos Rotos** | 🟠 Alta | Verificar que un "Cajero" no vea "Valor del Inventario" ni "Configs". |
| R-05 | **Precisión Decimal** | 🟡 Media | Verificar sumas complejas (ej. $1,230.50 + $500). |
| R-06 | **Persistencia** | 🟡 Media | Recargar la página en medio de una venta o caja abierta. |

---

## 2. Plan de Pruebas (Test Cases)

### Bloque A: Integridad del Flujo de Venta (E2E)
- **TC-A1**: Ciclo completo con efectivo exacto. (`Inventory` -> `Cart` -> `Checkout` -> `Receipt` -> `Inventory Updated`).
- **TC-A2**: Venta mixta o fiado (si aplica). Verificar que `Fiado` no sume al efectivo en caja.
- **TC-A3**: Validación de Stock. Agregar producto agotado.

### Bloque B: Control Financiero (Caja)
- **TC-B1**: Apertura de Caja. Verificar `openingBalance`.
- **TC-B2**: Registro de Gasto. Sacar dinero y verificar que `currentCash` baje.
- **TC-B3**: Cálculo de Arqueo.
    - Escenario 1: Cuadre perfecto.
    - Escenario 2: Faltante (Robo/Error). Verificar reporte de discrepancia negativo.
    - Escenario 3: Sobrante. Verificar reporte positivo.
- **TC-B4**: Bloqueo. Intentar entrar a POS sin sesión de caja.

### Bloque C: Seguridad y Permisos
- **TC-C1**: Rol Cajero.
    - Intento de ver Dashboard Admin.
    - Intento de editar stock (si no tiene permiso).
- **TC-C2**: Rol Admin. Acceso total.

### Bloque D: Dashboard y Reportes
- **TC-D1**: Consistencia de Datos.
    - ¿La suma de ventas en Reportes coincide con el Arqueo de Caja?
    - ¿El filtro de fecha funciona?

---

## 3. Protocolo de Ejecución Automatizada

Ejecutaré scripts de validación en el navegador y verificaciones de código estático.

1. **Auditoría Estática**:
   - Buscar `TODO`, `FIXME` críticos.
   - Verificar uso de `Decimal.js` en todos los cálculos monetarios.
   - Verificar protección de rutas (Route Guards).

2. **Auditoría Dinámica (Simulada)**:
   - Navegación por componentes clave.
   - Inyección de estados inválidos en Stores.

## 4. Entregable Final
Un **Reporte de Auditoría** con:
- Score de Robustez (0-100%).
- Lista de Hallazgos (Bugs encontrados).
- Recomendaciones de Mitigación.
