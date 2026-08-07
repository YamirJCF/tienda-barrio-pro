# FRD-016: Registro de Costo en Ventas (Habilitación de Analytics)

> **Módulo:** Ventas / Inventario — Costeo FIFO  
> **Versión:** 2.0 (Renumerado de FRD_015 → FRD_016, saneamiento documental 2026-08-07)  
> **Estado:** Aprobado  
> **SDD Asociado:** SDD_016 (Por crear — Fase 3-P3)  
> **Nota de Trazabilidad:** Este documento fue renumerado como FRD_016 por colisión de numeración con FRD_015_GESTION_DISPOSITIVOS. El contenido funcional se preserva íntegro.

---

## Descripción

El sistema DEBE registrar el costo unitario real de cada producto vendido en el momento exacto en que se efectúa la venta. Este registro es un requisito estructural previo e indispensable para cualquier módulo de análisis financiero y cálculo de ganancia bruta real. Sin este dato, el sistema no puede distinguir entre ingresos y ganancias.

---

## Contexto del Problema

Actualmente el sistema registra todas las ventas correctamente a nivel de ingresos (precio de venta), pero omite registrar el costo unitario de la mercancía al momento de la transacción, dejando este valor en cero. Esto genera que:

1. Todo reporte de ganancia calculado sobre datos actuales es inválido (margen del 100% ficticio).
2. La lógica de reducción de inventario por lotes FIFO se ejecuta correctamente, pero el costo resultante no se asocia al registro de venta — el procesamiento ocurre sin aprovechar su resultado principal.

---

## Reglas de Negocio

1. **Inmutabilidad Histórica del Costo:** El costo registrado en cada venta DEBE reflejar el costo real conocido en el momento preciso en que se ejecutó la transacción. Los futuros cambios de precio del producto NUNCA DEBEN modificar el costo ya registrado en ventas históricas.

2. **Origen del Costo — Primera Iteración:** En la primera implementación, el sistema DEBE usar el costo estándar del producto (costo de referencia registrado en la ficha del producto) como el valor de costo a registrar en la venta.

3. **Origen del Costo — Segunda Iteración (Objetivo Final):** En una implementación posterior, el sistema DEBE calcular el costo preciso de cada ítem vendido usando el método FIFO, promediando los costos de los lotes consumidos en la transacción. Este es el objetivo arquitectónico final.

4. **No Interrupción de Venta:** Si el costo estándar de un producto es cero o no está disponible, el sistema DEBE registrar cero como costo, sin interrumpir ni cancelar la venta bajo ninguna circunstancia.

5. **Alcance Restringido:** Esta regla aplica únicamente al registro de ventas. Los ajustes de inventario, devoluciones y entradas de mercancía tienen sus propias reglas de costeo definidas en sus módulos correspondientes.

---

## Casos de Uso

**Caso A: Venta con Producto Costeado**

- **Actor:** Tendero / Empleado (operando el Punto de Venta)
- **Precondición:** El producto tiene un costo estándar mayor a cero registrado en el sistema.
- **Flujo Principal:**
  1. El empleado agrega productos al carrito y completa el proceso de cobro.
  2. El sistema procesa la venta.
  3. Por cada ítem vendido, el sistema consulta el costo estándar vigente del producto en ese momento.
  4. El sistema registra ese costo como el costo unitario de la línea de venta.
  5. La venta queda registrada con su precio de venta Y su costo unitario real.
- **Postcondición:** El registro de venta contiene el costo unitario real. El cálculo de ganancia bruta es posible.

**Caso B: Venta con Producto Sin Costo Registrado**

- **Actor:** Tendero / Empleado
- **Precondición:** El producto tiene costo estándar en cero o no configurado.
- **Flujo Principal:**
  1. El empleado agrega el producto al carrito y completa el cobro.
  2. El sistema procesa la venta normalmente.
  3. El sistema detecta que el costo estándar es cero o nulo.
  4. El sistema registra cero como costo unitario.
  5. La venta se completa sin interrupción.
- **Postcondición:** La venta queda registrada. El costo unitario es cero. La venta es válida aunque el margen de ganancia no sea calculable para ese ítem.

---

## Criterios de Aceptación

- [ ] **CA-016-01:** Tras ejecutar una venta, cada línea de venta tiene un valor de costo unitario registrado (puede ser cero si el producto no tiene costo configurado).
- [ ] **CA-016-02:** El costo registrado en ventas históricas NO se modifica cuando el costo estándar del producto cambia posteriormente.
- [ ] **CA-016-03:** La implementación de este registro no interrumpe ni altera la lógica existente de validación de caja abierta, ventas fiadas ni reducción de inventario FIFO.
- [ ] **CA-016-04:** El sistema acepta y registra correctamente un costo de cero sin tratar esta condición como un error.

---

## Requisitos de Datos (Para Equipo Data)

El sistema DEBE almacenar por cada línea de venta:

| Información | Descripción |
|-------------|-------------|
| Costo unitario al momento de la venta | El costo real del producto en el instante de la transacción. Valor inmutable post-registro. |
| Precio de venta | Ya existe en el sistema. |

> **Nota para Equipo Data:** El costo unitario DEBE capturarse dentro del mismo proceso atómico de registro de venta. No debe ser un proceso posterior. La captura y el registro de la venta son una sola operación indivisible.

---

## Trazabilidad

| Documento | Referencia |
|-----------|------------|
| FRD_007_01 | Núcleo POS — Proceso de venta principal |
| FRD_010_VALORACION_INVENTARIO_FIFO | Valoración por lotes FIFO — Origen del costo en segunda iteración |
| FRD_006_01_01 | Movimientos de entrada — Establece el costo de los lotes |
