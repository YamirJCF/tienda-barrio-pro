# DICT-002: Supplier Payment Origin (Origen de Pago a Proveedores)

**Versión:** 1.0  
**Fecha:** 2026-08-11  
**Autor:** Arquitecto de Producto  
**FRD Relacionado:** [FRD-019: Cuentas por Pagar](../FRD/FRD_019_CUENTAS_POR_PAGAR.md)

---

## Dominio

Controla y audita desde dónde se originan los fondos que se usan para pagar o abonar a un proveedor, asegurando la segregación de canales monetarios dictada por POL-FIN-02.

---

## Valores Permitidos

### `payment_origin`

Define la procedencia del dinero para un pago o abono a proveedor.

| Valor Técnico | Término de Negocio | Semántica | Ejemplos de Uso |
|---------------|-------------------|-----------|-----------------|
| `'INTERNAL'` | Pago Interno | Fondos extraídos directamente de la caja registradora de la tienda. | • Pago en efectivo de la base actual. |
| `'EXTERNAL'` | Abono Externo | Fondos provenientes de fuera del ecosistema físico de la tienda (cuenta bancaria, bolsillo personal del dueño, transferencia externa). | • Transferencia bancaria del dueño al proveedor.<br>• Pago en efectivo hecho directamente por el dueño sin tocar la caja. |

---

## Reglas de Negocio

### 1. Pagos Internos (`'INTERNAL'`)
Un pago con origen interno DEBE registrar automáticamente una deducción (gasto) en la caja actual, ya que el dinero físico salió del flujo de la tienda.

### 2. Pagos Externos (`'EXTERNAL'`)
Un pago con origen externo NO debe afectar la caja registradora de la tienda de ninguna manera (Ceguera Financiera del canal externo). Reduce la deuda pero no toca los ingresos/egresos del turno.

---

## Valores NO Permitidos

| Valor Incorrecto | Razón |
|------------------|-------|
| `'CAJA'` | Ambigüo y español; usar `'INTERNAL'`. |
| `'BANCO'` | Demasiado específico; el origen es cualquier medio externo (`'EXTERNAL'`). |
| `'EFECTIVO'` | Confunde medio de pago con origen; usar `'INTERNAL'` o `'EXTERNAL'`. |

---

## Notas de Arquitectura

**Decisión:** Preferimos **"INTERNAL/EXTERNAL"** porque separa la procedencia de los fondos sin importar el medio físico o digital. Lo vital para el sistema de caja de la tienda es si el dinero salió de su propia liquidez operativa (`INTERNAL`) o de otra fuente que no le concierne (`EXTERNAL`).
