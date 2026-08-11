# DICT-004: Payment Channels (Trinidad de Canales de Pago)

**Versión:** 1.0  
**Fecha:** 2026-08-11  
**Autor:** Arquitecto de Producto  
**FRD Relacionado:** [FRD-004: Control de Caja](../FRD/FRD_004_CONTROL_DE_CAJA.md)

---

## Dominio

Define y acota estrictamente los canales de recaudo autorizados para el sistema, formalizando la "Trinidad de Canales" requerida por la Política Financiera de Segregación de Canales (POL-FIN-02).

---

## Valores Permitidos

### `payment_channel`

Medio o conducto a través del cual el sistema recauda los fondos de una transacción.

| Valor Técnico | Término de Negocio | Semántica | Ejemplos de Uso |
|---------------|-------------------|-----------|-----------------|
| `'CASH'` | Efectivo | Dinero físico que ingresa directamente a la gaveta de la caja registradora de la tienda. | Pago con billetes o monedas. |
| `'NEQUI'` | Nequi | Transferencia digital dirigida exclusivamente a la cuenta Nequi del propietario. | Escaneo de código QR de Nequi. |
| `'BRE_KEY'` | Llave BRC (Bancolombia) | Transferencia digital dirigida a la cuenta Bancolombia del propietario. | Transferencia desde la App de Bancolombia. |

---

## Reglas de Negocio

### 1. Inmutabilidad de la Trinidad
Estos son los únicos tres (3) canales autorizados a nivel de base de datos (`ARQ-004`). Cualquier intento de añadir o usar un canal distinto producirá un fallo por violación de integridad. La agregación de nuevos canales requiere una decisión formal de Arquitectura.

### 2. Segregación Logístico-Financiera
El único canal con capacidad de afectar la Base y el flujo de liquidez interno de la caja de turno es `'CASH'`. Los canales `'NEQUI'` y `'BRE_KEY'` son canales digitales blindados o "ciegos" para la gaveta física: nutren las cuentas del dueño pero no inciden en los ingresos/egresos del turno.

---

## Valores NO Permitidos

| Valor Incorrecto | Razón |
|------------------|-------|
| `'TRANSFERENCIA'`| Es un concepto general que agrupa dos canales. Para fines de cuadre contable, se exige desagregarlo en `'NEQUI'` o `'BRE_KEY'`. |
| `'TARJETA'`      | Fuera del alcance tecnológico y comercial actual del sistema de la tienda. |
| `'EFECTIVO'`     | Término español de negocio, el valor técnico en BDD debe ser `'CASH'`. |
