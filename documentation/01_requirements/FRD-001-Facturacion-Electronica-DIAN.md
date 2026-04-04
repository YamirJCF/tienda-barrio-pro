# Análisis Normativo Funcional: Facturación Electrónica DIAN (Modelo vía Proveedor Tecnológico)

## Contexto y Arquitectura Elegida
- **Jurisdicción:** Colombia
- **Entidad Reguladora:** Dirección de Impuestos y Aduanas Nacionales (DIAN)
- **Modelo de Integración:** Uso de un **Proveedor Tecnológico (PT) Autorizado** vía API REST. Nuestro software actuará como sistema origen (ERP/POS) que envía intenciones de facturación, delegando la pesada carga criptográfica y de comunicación oficial al PT.

## 1. Requisitos Previos Operativos (Dueño del Negocio)
*Trámites que el cliente final debe realizar para poder conectar su cuenta con nuestro software.*

- **RUT Actualizado:** RUT con responsabilidad explícita de facturador electrónico.
- **Contratación de Proveedor Tecnológico:** Suscripción a un plan de documentos/timbres electrónicos con un PT autorizado (Ej. Siigo, Alegra, The Factory HKA).
- **Adquisición de Certificado Digital:** Aunque usemos un PT, por ley la firma digital debe ser del dueño del negocio. Este certificado (archivo .p12 o .pfx) se adquiere con una certificadora ONAC y se "sube" a la plataforma del PT.
- **Habilitación en Portal DIAN:** Ingresar a la DIAN, y en la sección de Facturador Electrónico, seleccionar la opción **"Software de un proveedor tecnológico"**, seleccionando en el buscador al PT contratado.
- **Resolución DIAN y Asociación:** Solicitar una resolución de numeración para factura electrónica, y asociar los prefijos concedidos al Proveedor Tecnológico en el portal MUISCA comercial.

## 2. Flujo / Protocolo Sistémico (La Vía API)
*Cómo se desagrega la responsabilidad entre nuestro software y el Proveedor Tecnológico en tiempo de ejecución.*

### Fase A: Nuestro Sistema (POS / Backend)
1. **Consolidación de Datos:** El vendedor finaliza la venta en la UI. El Backend valida que los datos del cliente (NIT/CC) y productos y calcula los impuestos matemáticamente.
2. **Generación del Payload (JSON):** Construye un objeto JSON estandarizado con la estructura que exija el Proveedor Tecnológico.
3. **Consumo de la API externa (POST):** Se envía el JSON a la API del PT. Aquí el flujo se bloquea momentáneamente a la espera de la respuesta.

### Fase B: El Proveedor Tecnológico (Caja Negra Externa)
4. Convierte el JSON a un archivo estandarizado XML (UBL estándar DIAN).
5. Aplica el **Certificado Digital** del cliente para firmar criptográficamente el XML.
6. Calcula e inyecta el **CUFE** (Código Único de Factura Electrónica).
7. Se comunica vía WebService Soap/Rest directamente con los servidores de la DIAN para la "Validación Previa Mensaje a Mensaje".
8. Tras recibir la aprobación de la DIAN, el PT genera automáticamente el PDF (Representación Gráfica con QR) y envía el e-mail legal al comprador.

### Fase C: Respuesta a Nuestro Sistema
9. **Acuse de Recibo:** La API del PT nos responde un JSON con éxito o con excepciones (ej. "El cliente tiene un NIT inválido según RUT").
10. **Almacenamiento Local:** Si es exitoso, recibimos y guardamos en nuestra base de datos el `CUFE`, `URL del PDF` y `URL del XML`. 
11. **Desbloqueo de UI:** El usuario ve en pantalla que la factura fue aprobada y se le habilita el botón para imprimir o descargar el PDF devuelto por la API.

## 3. Reglas de Negocio Duras (Para Nuestro Sistema)
- **Validación Estricta Pre-Envío:** Para evitar malgastar consumo de API (o bloqueos por límite de peticiones erróneas del PT), nuestro backend debe pre-validar que no falten datos fiscales del comprador (Documento, Tipo doc, Municipio, Régimen) cuando el monto exija factura nominativa.
- **Delegación de Responsabilidad:** **No** somos responsables del almacenamiento legal por 5 años del XML (lo hace el PT), ni del algoritmo del CUFE, ni del diseño legal del PDF con el QR oficial.
- **Estados de Transacción:** Una petición a la API puede dar "Timeout". Debemos tener un cron job u operador de reintentos para facturas que quedaron en un limbo de comunicación *Networking* entre nuestro server y el PT.

## 4. Impacto Premiliminar en el Sistema (Para el Arquitecto)
- **Estructuras de Datos:** 
  - `sales`: `provider_sync_status` (Pending, Success, Failed), `cufe` (string genérico), `dian_pdf_url` (url al servidor del PT).
  - Configuración global del Tenant (`settings`): Guardar los `api_key` o `tokens` provistos por el Proveedor Tecnológico al negocio para poder hacer la autenticación en sus endpoints.
- **Validaciones UX:** 
  - La espera de respuesta de la API del PT tomará entre 2 a 5 segundos (dado que el PT debe ir a la DIAN y volver). Es vital un "Loading Skeleton" en el POS para que el cajero no vuelva a cobrar o enviar la venta dos veces.
  - Interfaz de "Facturas Fallidas": Panel para cajeros/administradores donde vean facturas locales que no pasaron la validación de la API (ej: error en NIT del cliente) para que corrijan el dato y presionen "Reenviar a DIAN".

---
**Siguiente Paso Recomendado:** Ejecutar el flujo de trabajo `@/architect` con el contexto de este documento para diseñar el módulo de "Cola de Integración Externa" y definir la interfaz genérica de envío (Repository Pattern) que luego inyectaremos sin importar si el PT contratado es Siigo, Alegra, u otro.
