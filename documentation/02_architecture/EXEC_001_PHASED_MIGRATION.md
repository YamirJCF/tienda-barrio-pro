# Plan de Ejecución por Bloques: Migración Segura (Ref: EXEC-001)

**Filosofía**: "Cambiar el motor del avión en pleno vuelo".
**Objetivo**: Migrar a `ARCH-001` sin romper ninguna venta en curso (Online u Offline).

## Bloque 1: Cimientos "Aditivos" (Sin Riesgo)
*Estrategia*: Crear estructuras nuevas que nadie usa todavía. Si falla, no afecta a nadie.

1.  **Crear Tablas**: `payment_methods`, `transaction_types`.
2.  **Popular Datos ("Seed")**: Insertar los valores que ya existen hoy ('efectivo', 'fiado') para asegurar compatibilidad.
3.  **Crear RPC Config**: `rpc_get_system_config`.
4.  **Validación**: Ejecutar el RPC manualmente y verificar que devuelve el JSON esperado.

> **Riesgo**: 0%. El sistema actual ni se entera de que esto existe.

## Bloque 2: Puente de Compatibilidad (Backend)
*Estrategia*: El RPC `rpc_procesar_venta_v2` seguirá recibiendo `TEXT` ('nequi'), pero internamente consultará la nueva tabla.

1.  **Modificar RPC (V2.1)**:
    -   *Entrada*: `p_payment_method TEXT` (Se mantiene igual, no rompe la API).
    -   *Lógica Interna*:
        -   Antes: `IF p_payment_method = 'efectivo' THEN ...`
        -   Ahora: `SELECT allows_change FROM payment_methods WHERE code = p_payment_method`.
    -   *Fallback*: Si el código no existe en la tabla, lanzar error explícito `INVALID_PAYMENT_METHOD`.

> **Riesgo**: Bajo. Si la tabla `payment_methods` tiene los datos correctos ('efectivo', 'fiado'), la lógica funciona idéntica.
> **Prueba**: Procesar una venta normal. Debería funcionar transparente.

## Bloque 3: Adopción Frontend (Progressive Enhancement)
*Estrategia*: El Frontend empieza a "leer" la nueva configuración, pero sigue enviando los mismos strings.

1.  **Store Config**: Crear `useConfigStore` y consumir el RPC al inicio.
2.  **UI Dinámica**: Reemplazar los botones fijos `<button>Efectivo</button>` por un loop `v-for="method in config.paymentMethods"`.
3.  **Validación**:
    -   Verificar que aparecen los botones.
    -   Verificar que al hacer click, se envía el `code` correcto ('cash', 'nequi') al saleRepository.

## Bloque 4: Limpieza (Cleanup)
*Estrategia*: Una vez estable, eliminar deuda vieja.

1.  Marcar métodos viejos como `is_active = false` en DB si se dejan de usar.
2.  Eliminar lógica hardcodeada muerta en Frontend.

---

## checklist de Ejecución (Bloque 1)

- [ ] SQL: Create Table `payment_methods`
- [ ] SQL: Insert 'cash', 'fiado' (Seed)
- [ ] SQL: Create Table `transaction_types`
- [ ] SQL: Create RPC `rpc_get_system_config`
