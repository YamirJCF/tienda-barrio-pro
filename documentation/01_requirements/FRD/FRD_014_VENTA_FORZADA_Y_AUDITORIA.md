# FRD-014: Protocolo de Excepción - Venta Forzada y Auditoría

> **Módulo:** Ventas / Auditoría  
> **Versión:** 1.4
> **Fecha:** 2026-02-07  
> **Dependencias:** 
> - **FRD-007 (Ventas) - Norma General**
> - FRD-012 (Offline Sync)
> - FRD-004 (Caja)
> **Autor:** @/architect

---

## 1. Descripción Ejecutiva

Este documento define el **Protocolo de Excepción** conocido como **"Venta Forzada"**. 

> **Aclaración de Jerarquía:** 
> La norma general definida en **FRD-007 (Sección: Límites del Carrito)** establece que *"No se pueden agregar productos sin stock"*. 
> Este documento (FRD-014) define la **única excepción autorizada** a dicha regla, aplicable exclusivamente bajo privilegios administrativos y con auditoría obligatoria.

El objetivo es permitir que la operación continúe frente a discrepancias de inventario (físico > sistema), sin violar la integridad contable.

---

## 2. Reglas de Negocio (Hard Rules)

### RN-014-01: Excepción a la Regla de Stock (FRD-007)
1.  **Regla General (FRD-007):** El sistema bloquea la adición de productos con `stock <= 0` al carrito.
2.  **Excepción Controlada (FRD-014):** El sistema PERMITE omitir este bloqueo SI Y SOLO SI:
    *   El usuario tiene rol de **Administrador**.
    *   El usuario confirma explícitamente la acción de "Forzar".
    *   Se provee una justificación válida.

### RN-014-02: Universalidad del Protocolo
El protocolo de excepción aplica idénticamente en dos contextos:
1.  **Online (POS):** Al momento de intentar agregar/cobrar un producto.
2.  **Offline (Sincronización):** Al momento de resolver un conflicto de venta que fue rechazada por la regla general.

### RN-014-03: Mecánica de Auto-Corrección (Atomicidad)
Para mantener la consistencia contable (que exige no tener stock negativo), el sistema DEBE:
1.  Identificar la cantidad faltante.
2.  Generar un **Movimiento de Entrada** (ajuste) por esa cantidad EXACTA antes de procesar la venta.
    *   *Tipo:* `CORRECCION_SISTEMA`.
3.  Procesar la venta normlamente (ahora con stock suficiente).

### RN-014-04: Privilegio Exclusivo
*   **Empleados:** Se rigen estrictamente por **FRD-007**. No tienen acceso a esta excepción.
*   **Administradores:** Tienen acceso a la excepción **FRD-014**.

### RN-014-05: Bloqueo de Cierre (Consecuencia)
El uso de esta excepción (o la existencia de conflictos no resueltos derivados de ella) impide el Cierre de Caja hasta que la auditoría sea completada.

---

## 3. Casos de Uso

### Caso A: Venta Estándar (Empleado) - Cumplimiento FRD-007
- **Actor:** Empleado
- **Situación:** Intenta vender producto con Stock 0.
- **Resultado:**
    - Sistema muestra alerta: "Stock Insuficiente".
    - Acción bloqueada (Botón cobrar deshabilitado o item no agregado).
    - **Cumple FRD-007.**

### Caso B: Excepción Administrativa (Admin) - Aplicación FRD-014
- **Actor:** Administrador
- **Situación:** Intenta vender producto con Stock 0 (tiene el producto físico).
- **Flujo:**
    1. Sistema detecta Stock 0.
    2. Sistema detecta Rol Admin.
    3. Sistema ofrece: "⚠️ Stock Insuficiente. ¿Forzar Venta?".
    4. Admin confirma y justifica: "Stock físico hallado".
    5. Sistema ajusta inventario (+1) y vende.
    - **Cumple FRD-014.**

---

## 4. Criterios de Aceptación

- [ ] El sistema mantiene el bloqueo estricto (FRD-007) para empleados normales.
- [ ] El sistema habilita el flujo de excepción (FRD-014) solo para Admins.
- [ ] La venta forzada no deja el stock en negativo (usa inyección previa).
- [ ] Toda venta forzada queda marcada y justificada en auditoría.
