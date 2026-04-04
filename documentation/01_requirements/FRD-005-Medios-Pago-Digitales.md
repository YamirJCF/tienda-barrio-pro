# Análisis Funcional: Medios de Pago Digitales (Nequi / Daviplata)

Este documento traza la estrategia de integración de billeteras digitales (Nequi, Daviplata, Dale!, etc.) enfocada específicamente en el perfil de "Tenderos" y "Minimercados" colombianos cobijados por el Régimen Simple de Tributación (RST).

## 1. La Barrera del Costo en Negocios de Barrio
Las plataformas de pago tradicionales (Pasarelas de Pago como Wompi, ePayco o MercadoPago) ofrecen integraciones automáticas donde el software recibe una alerta cuando el cliente paga. 
Sin embargo, **los tenderos evitan estas pasarelas** debido a:
*   Las altas comisiones por transacción (que recortan el bajísimo margen de ganancia de los productos de canasta familiar).
*   La retención del dinero por días (ellos necesitan flujo de caja diario).

Por esto, la solución ideal en el 95% de tiendas de Colombia es la **transferencia directa ("De Nequi a Nequi") mediante un Código QR plastificado** en la pared, lo cual tiene 0% de comisión.

## 2. Nuestra Estrategia Funcional (Flujo Semiautomático)

Para mantener los costos en cero para el tendero, pero asegurar la contabilidad cuadre perfecto dentro de nuestro sistema, proponemos un enfoque operativo "Cero Comisiones":

### Punto de Venta (Frontend UI)
- Al momento de liquidar una caja, el tendero verá no solo "Efectivo", sino botones nativos de **"Nequi"** y **"Daviplata"**.
- Al presionar alguno, la pantalla mostrará una ventana (opcional) donde el sistema podría, si se desea, proyectar en pantalla el código QR del celular del tendero (pre-configurado en su perfil) para que el comprador lo escanee.
- El tendero realiza una **Validación Visual:** Mira su celular, confirma que la plata de Nequi entró.
- En la interfaz del POS, el tendero da clic al botón **"Confirmar Recibido"**. (Opcional: el sistema puede habilitar un campo rápido para anotar los últimos 4 dígitos del número de recibo de Nequi).

### Beneficios Contables (Backend) y Reporte Oficial a la DIAN
- Aunque la validación de la transacción fue "Visual-Manual", la base de datos de nuestro sistema guardará la venta con un identificador exacto de `payment_method = 'NEQUI'`.
- **La magia del Anexo Técnico DIAN:** Cuando enviemos el JSON de la Factura Electrónica al Proveedor Tecnológico, nuestro backend traducirá la palabra "Nequi" al código estándar oficial de la DIAN para el XML UBL 2.1 (usualmente el código **`41`** para *Transferencia Bancaria* o el correspondiente a depósitos electrónicos).
- Al recibir el XML, **la DIAN automáticamente registra y audita** que esa factura se pagó de forma electrónica, porque lleva sellado el Código 41. Tu sistema no tiene que hacer ningún trámite extra.
- Al finalizar el día, el cajero hará el **"Cierre de Caja (Z)"** y el sistema le dirá con exactitud matemática su cuadre físico y digital.
- **Beneficio RST garantizado:** A final de bimestre, cuando su contador entre al portal oficial de la DIAN a pagar impuestos, la DIAN ya tendrá contabilizadas todas las facturas con Código 41 y le aplicará el **0.5% de rebaja** de forma directa, sustentado legalmente en los XML emitidos por nuestra API.

## 3. El Futuro (Fase 2: Integración Vía API Bancaria)
Cuando el negocio escale y apuntemos a *Minimercados de cadena* más sofisticados que sí deseen pagar pequeña comisión a cambio de automatización, nuestra arquitectura Agnóstica estará lista:
- Haremos integración con una cuenta empresarial bancaria (ej. **Boton Nequi de Wompi Bancolombia**).
- En este modelo, el sistema sí genera desde la API un código QR dinámico único en la pantalla LED del Datáfono/Tablet, y nuestro backend se queda auditando hasta recibir un mensaje cifrado de confirmación por la red de Bancolombia antes de liberar el tiquete (Sincronización Total).

---
**Conclusión de Producto:**
Arrancaremos de la forma más amigable y realista para el tendero local (Validación Visual Cero Comisiones), pero registrando con extrema pureza estructural el tipo de método de pago en nuestra base de datos para apalancar el descuento del RST de la DIAN y cuadrarle su contabilidad diaria.
