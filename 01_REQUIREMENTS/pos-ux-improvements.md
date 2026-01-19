# Diseño UX/UI - Mejoras POS

## Observaciones del Usuario

### OBS-01: Lista de Checkout Confinada
**Problema**: En el modal de checkout, la lista de productos está limitada a un espacio pequeño que no permite ver todos los items.

**Solución propuesta**: Agregar botón para expandir la lista a pantalla completa (overlay sobre el teclado) o hacer el área de la lista más grande por defecto.

---

### OBS-02: Números Largos en POS
**Problema**: El producto "azucar" muestra "692307692307693" junto al nombre (ver imagen).
**Causa**: La cantidad del producto pesable tiene decimales muy largos sin redondear para display.

**Solución**: Formatear la cantidad a máximo 2-3 decimales en la vista del ticket:
```
x0.319 lb  en vez de  x0.31930769230769...
```

---

### OBS-03: Validación de PLU Tardía
**Problema**: Al digitar un PLU inexistente y presionar "CANT.", no se muestra error. Solo aparece al presionar "AGREGAR".

**Solución**: Validar existencia de PLU también en `handleQuantity()` y mostrar error si el número no es PLU válido ni cantidad válida.

---

## Impacto en el Sistema

| Archivo | Cambio |
|---------|--------|
| `CheckoutModal.vue` | Agregar opción de expandir lista |
| `POSView.vue` | Formatear cantidad a 2 decimales |
| `POSView.vue` | Validar PLU en handleQuantity |
