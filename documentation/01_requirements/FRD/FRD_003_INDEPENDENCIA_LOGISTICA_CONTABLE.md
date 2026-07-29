# FRD-003: Independencia Logística y Contable

### Desacoplamiento de Cuentas por Pagar e Inventario

#### Descripción
Este documento norma la separación estricta entre la operación logística de ingreso de mercancía y la operación financiera de asunción de pasivos corporativos (deudas). Su objetivo es garantizar que la responsabilidad contable sea un acto consciente, desvinculado de procesos automáticos derivados de la recepción física de bienes.

---

## Reglas de Negocio
1. **Ruptura de Automatización Financiera:** El acto logístico de aumentar las existencias físicas de un producto (inventario) TIENE PROHIBIDO desencadenar o generar automáticamente la creación de un pasivo, deuda, o cuenta por pagar de manera implícita.
2. **Creación Deliberada de Deudas:** Todo registro de deuda o factura emitida por un proveedor DEBE nacer como una operación humana explícita y aislada, originada en el entorno contable, requiriendo autorización y montos exactos de facturación.
3. **Vinculación Trazable Opcional:** Si un pasivo financiero corresponde a una entrega específica de mercancía, el sistema DEBE permitir la asociación manual o asistida de esa deuda con el lote logístico recibido. Esta vinculación sirve a propósitos de trazabilidad, pero la existencia de la deuda no depende estructuralmente del lote de inventario.

---

## Casos de Uso

**Caso A: Recepción Logística Pura con Deuda Posterior**
- **Actor:** Usuario Operativo Logístico y Usuario Contable.
- **Precondición:** Se recibe un volumen considerable de mercancía en el establecimiento. El proveedor aún no ha entregado la factura oficial, o esta requiere revisión y validación administrativa.
- **Flujo Principal:**
  1. El actor logístico registra el ingreso físico de la mercancía, indicando producto y cantidad a sumar en bodega.
  2. El servidor procesa y aumenta las existencias disponibles para su comercialización al público.
  3. El servidor detiene su proceso. Ningún pasivo o deuda financiera se inyecta en el estado contable de la tienda.
  4. Horas o días más tarde, el actor contable recibe la documentación oficial y procede a registrar explícitamente una "Cuenta por Pagar", fijando el monto legal y los plazos de vencimiento acordados.
  5. Durante el registro financiero, el actor contable asocia de manera opcional este pasivo a la entrada de mercancía generada previamente por el actor logístico, estableciendo el puente de trazabilidad.
- **Flujo Alternativo:** Ninguno.
- **Postcondición:** El inventario se alimenta sin comprometer anticipada ni automáticamente los saldos financieros, permitiendo un control exacto de las cuentas y sus orígenes documentales.

---

## Criterios de Aceptación
- [ ] **CA-FRD-003-01:** La acción sistémica de aumentar el inventario físico NO PUEDE disparar la creación de un pasivo financiero, deuda o cuenta por pagar bajo ninguna condición automática u oculta.
- [ ] **CA-FRD-003-02:** El registro de cuentas por pagar DEBE operar como un módulo financiero autónomo, permitiendo su creación sin dependencia directa de la existencia previa o simultánea de eventos logísticos de ingreso de bienes.
- [ ] **CA-FRD-003-03:** El servidor DEBE soportar y requerir un evento humano explícito para formalizar cualquier obligación financiera hacia agentes externos.
