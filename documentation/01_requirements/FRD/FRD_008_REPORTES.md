# FRD-008: Resumen Diario y Abastecimiento Inteligente

## 1. Descripción General
El módulo de Reportes es la herramienta de inteligencia de negocios diseñada para usuarios no técnicos. Su propósito es responder, en lenguaje natural y en menos de 5 segundos, las dos preguntas críticas del operación diaria:
1.  **Evaluación de Desempeño:** "¿Cómo me fue hoy?" (Resumen Diario).
2.  **Gestión de Abastecimiento:** "¿Qué debo comprar hoy para no perder ventas?" (Smart Supply).

---

## 2. Reglas de Negocio

### RN-008-01: Lenguaje Humano Obligatorio
El sistema DEBE presentar toda la información financiera en formato conversacional.
- **Prohibido:** Mostrar códigos de error, IDs, o términos técnicos ("ROI", "Margen Bruto", "Lead Time").
- **Permitido:** Frases directas ("Ventas de hoy", "Te queda stock para 3 días").

### RN-008-02: Política de "Verdad Tangible"
El sistema NO PUEDE mostrar proyecciones o sugerencias de compra si no cuenta con datos históricos suficientes.
- **Umbral de Silencio:** Si un producto tiene menos de 15 días de historial de ventas, el sistema DEBE mostrar un estado de "Recopilando información" y NO PUEDE generar alertas de abastecimiento.
- **Contexto:** Toda sugerencia de compra DEBE incluir la razón verificable (ej: "Se agotó 2 días antes de la entrega anterior").

### RN-008-03: Configurabilidad del Abastecimiento
El sistema DEBE permitir la configuración de proveedores para calcular las alertas de reabastecimiento.
- Todo producto DEBE estar asociado a un proveedor (o al "Proveedor General" por defecto).
- El cálculo de días de autonomía DEBE considerar el tiempo de entrega del proveedor (Días de espera).

### RN-008-04: Detección de Demanda Reprimida
El sistema DEBE identificar los días donde el stock se agotó antes del cierre de la operación (ej: 5:00 PM) y marcar esos días como "Días Saturados".
- Si un producto presenta "Días Saturados" en más del 50% de la ventana de análisis, el sistema DEBE activar una alerta de "Pérdida de Ventas".

---

## 3. Casos de Uso

### Caso A: Consultar el Estado del Negocio (Cierre de Turno)
- **Actor:** Dueño de Tienda / Encargado
- **Precondición:** Existen ventas registradas en el día en curso.
- **Flujo Principal:**
    1. El Actor accede al módulo de Reportes.
    2. El Sistema muestra el "Semáforo de Desempeño" (Comparando hoy vs promedio semanal).
    3. El Sistema presenta el "Número Héroe" (Total vendido) destacado.
    4. El Sistema despliega el desglose de dinero por método de pago (Efectivo/Digital/Fiado).
    5. El Actor selecciona la tarjeta de "Efectivo".
    6. El Sistema navega al detalle de transacciones en efectivo.
- **Postcondición:** El Actor conoce el total a cuadrar en caja.

### Caso B: Gestión de Reabastecimiento Crítico
- **Actor:** Dueño de Tienda
- **Precondición:** Existen productos cuyo stock actual no cubre el tiempo de espera del proveedor.
- **Flujo Principal:**
    1. El Sistema identifica productos en riesgo de agotarse antes de la próxima visita del proveedor.
    2. El Sistema muestra una tarjeta roja: "Pedidos Urgentes".
    3. El Actor selecciona la tarjeta.
    4. El Sistema lista los productos sugeridos y la cantidad a pedir.
    5. El Actor marca los productos como "Añadidos a lista de compra" (mental o externa).
- **Postcondición:** El Actor recibe la alerta preventiva de quiebre de stock.

### Caso C: Asignación Masiva de Proveedores
- **Actor:** Admin
- **Precondición:** Existen múltiples productos asignados al "Proveedor General" por defecto.
- **Flujo Principal:**
    1. El Actor accede a la configuración de "Analítica de Abastecimiento".
    2. El Sistema alerta: "Tienes 50 productos sin proveedor específico".
    3. El Actor selecciona "Asignar Proveedor".
    4. El Sistema permite seleccionar múltiples productos de una lista.
    5. El Actor elige el proveedor "Panadería Central" y confirma.
    6. El Sistema recalcula las alertas de esos productos usando la frecuencia de la "Panadería Central".
- **Postcondición:** Los productos tienen reglas de abastecimiento precisas.

### Caso D: Análisis de Producto Nuevo (Silencio Prudente)
- **Actor:** Sistema (Automático)
- **Precondición:** Se ha creado un producto hace 3 días.
- **Flujo Principal:**
    1. El Sistema intenta calcular la velocidad de venta.
    2. El Sistema detecta que la antigüedad es menor a 15 días.
    3. El Sistema omite cualquier alerta de colores (Verde/Amarillo/Rojo).
    4. En su lugar, muestra un estado Gris: "Aprendiendo de tus ventas...".
- **Postcondición:** El Usuario no recibe alertas falsas o prematuras.

---

## 4. Criterios de Aceptación

### Funcionales
- [ ] El desglose de dinero DEBE coincidir exactamente con la suma de las transacciones del día.
- [ ] El sistema DEBE asignar automáticamente el "Proveedor General" a productos nuevos.
- [ ] La alerta de "Pérdida de Ventas" (Azul) SOLO debe aparecer si se detectan quiebres de stock tempranos (Días Saturados).
- [ ] El sistema NO PUEDE mostrar decimales en los montos monetarios principales.

### De Interfaz (UX)
- [ ] El usuario DEBE poder ver el resumen financiero sin hacer scroll en dispositivos móviles estándar.
- [ ] Los términos técnicos ("Lead Time", "Forecast") ESTÁN PROHIBIDOS en la interfaz.
- [ ] Las alertas de abastecimiento DEBEN estar agrupadas por urgencia (Urgente > Advertencia > Informativo).

### De Rendimiento
- [ ] La carga del resumen diario NO DEBE exceder los 2 segundos.
- [ ] El cálculo de alertas de abastecimiento DEBE realizarse en segundo plano o estar cacheado para no bloquear la navegación.
