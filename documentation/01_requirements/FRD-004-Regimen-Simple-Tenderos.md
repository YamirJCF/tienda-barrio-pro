# Análisis Normativo: Régimen Simple de Tributación (RST) para Tenderos y Minimercados

Este documento investiga el caso de uso principal de nuestra "Casa de Software": **La formalización de tiendas y minimercados a través del Régimen Simple de Tributación (RST) en Colombia**, identificando obligaciones tributarias que alteren el comportamiento del Punto de Venta (POS).

## 1. Contexto Jurídico del RST y Beneficios
El RST fue creado para combatir la informalidad permitiendo a los comerciantes pagar una tarifa unificada muy baja. 

Un beneficio estrella (Estatuto Tributario Art. 905) afecta drásticamente nuestro software:
*   **Exoneración del IVA:** Si el negocio se dedica *única y exclusivamente* a tienda pequeña, minimercado o peluquería, **NO es responsable del recaudo del Impuesto a las Ventas (IVA).**

## 2. Obligación de Facturar Electrónicamente en el RST
A pesar de la exoneración del IVA, el marco normativo actual de la DIAN es implacable en este punto:
*   **OBLIGATORIO:** Todo contribuyente (por más pequeña que sea la tienda) que se formalice y acoja al RST, **está obligado legalmente a emitir Factura Electrónica** por sus operaciones. No hay excepción.

## 3. La Regla de Oro del Software: POS Electrónico vs Factura Electrónica
Históricamente, el documento POS era solo un papel físico (limitado a 5 UVT). **Esto cambió radicalmente con la Resolución 000165 de 2023.**

Hoy en día nace el **"Documento Equivalente Electrónico POS"**. Esto significa que *todo* pasa por la DIAN, pero nuestro software lo manejará para que el tendero no sufra:

1.  **Venta Cotidiana (El "Cobro Rápido"):** Si alguien compra una leche y no le interesa declarar impuestos, tu sistema permite cobrar con un botón rápido. Internamente, nuestro sistema enviará el JSON al Proveedor Tecnológico etiquetado como "POS Electrónico" a nombre de **"Consumidor Final" (Cédula genérica 222222222222)**. El PT lo manda a la DIAN y nosotros imprimimos la tirilla. Rápido y legal.
2.  **Venta Para Empresas / Mayoristas (El "Cobro Formal"):** Si un cliente pide soporte para descontarse impuestos, el tendero usará el botón de Factura Electrónica. Aquí el sistema **bloquea el envío rápido** y exige obligatoriamente Nombre, NIT y Correo, emitiendo una "Factura Electrónica de Venta" tradicional.

*(Nota: Con esta nueva ley, desaparece la restricción técnica de los 5 UVT para ti como desarrollador, ya que ambos documentos viajan electrónicamente a la DIAN a través de nuestro Proveedor Tecnológico).*

---

## 4. Impacto Funcional en Nuestro Producto (Requerimientos para el Arquitecto/UX)

### A. Configuración de Tenant (El Perfil de la Tienda)
- **Toggle "Soy Régimen Simple (Tienda)":** Al crear la cuenta en nuestro SaaS, el tendero debe marcar si es RST exclusivo de tienda. Si es así, **nuestro sistema apagará visual y matemáticamente toda la interfaz y cálculos de IVA**. El precio de entrada = precio de salida. Simplifica radicalmente la UX.

### B. El Motor de Caja (POS) en el Frontend
- **Flujo Híbrido (UX Optimizada):**
  - `Botón 1:` **Cobro Rápido / POS Equivalente:** Para lo cotidiano. No pide cédula. El sistema autocompleta el envío a la API con "Consumidor Final" (222).
  - `Botón 2:` **Factura Electrónica Normal:** Pide Cédula/NIT, Nombre y Correo. Útil cuando el cliente lo exija para sus contabilidades.

### C. Backend (Base de datos)
- La base de datos debe identificar rigurosamente en la tabla `sales` un campo `document_type`: `POS_TICKET` o `ELECTRONIC_INVOICE`. Esto servirá para decidir cuáles se encolan para la API del Proveedor Tecnológico de forma inmediata (FE), y cuáles quedan locales (POS).

---
**Conclusión de Negocio:**
El RST es nuestra mejor arma comercial. Al vender nuestro software, le diremos al tendero: *"Si usas nuestra app, no tienes que preocuparte por el IVA, y la caja misma sabe cuándo cobrar rápido sin molestar a los clientes y cuándo es estrictamente obligatorio pedir la cédula, protegiéndote de multas de la DIAN automáticamente"*.
