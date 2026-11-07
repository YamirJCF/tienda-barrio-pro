# Análisis Normativo Funcional: Marco de Normas ISO y Legislación Aplicable (SaaS, POS y E-Commerce)

## Contexto y Fuentes Legales Oficiales
- **Jurisdicción:** Colombia (Armonizado con Estándares Internacionales ISO/IEC y GDPR)
- **Entidades Reguladoras y de Normalización:**
  - **Internacional:** ISO (*International Organization for Standardization*) / IEC (*International Electrotechnical Commission*).
  - **Normalización Nacional:** ICONTEC (*Instituto Colombiano de Normas Técnicas y Certificación* — adopta las normas como `NTC-ISO/IEC`).
  - **Vigilancia y Control en Colombia:**
    - **SIC** (*Superintendencia de Industria y Comercio*): Protección de Datos Personales (RNBD) y Protección al Consumidor en Comercio Electrónico.
    - **DIAN** (*Dirección de Impuestos y Aduanas Nacionales*): Facturación Electrónica, Documentos Equivalentes POS Electrónicos y Trazabilidad Fiscal.
    - **MinTIC / ColCERT**: Lineamientos de Ciberseguridad y Modelo de Seguridad y Privacidad de la Información (MSPI).
- **Fuentes Legales Nacionales y Estándares Oficiales:**
  - **Ley 1581 de 2012** y **Decreto Único Reglamentario 1074 de 2015** (Régimen General de Protección de Datos Personales / *Habeas Data*).
  - **Ley 1266 de 2008** y **Ley 2157 de 2021** (*Borró y Cuenta Nueva* — Datos Financieros, Crediticios y Comerciales, aplicable a cartera/fiados).
  - **Ley 527 de 1999** y **Decreto 2364 de 2012** (Validez jurídica de los mensajes de datos, comercio electrónico y firma electrónica).
  - **Ley 1480 de 2011** (Estatuto del Consumidor, Arts. 49–54 sobre Comercio Electrónico) y **Ley 2439 de 2024** (Actualización de plazos de retracto y comercio digital).
  - **Ley 1273 de 2009** (Delitos Informáticos y Protección de la Información y los Datos en el Código Penal Colombiano).
  - **Resolución DIAN 000165 de 2023** (Facturación Electrónica UBL 2.1 y Documento Equivalente Electrónico tiquete POS).
  - **Familia ISO/IEC 27000** (`27001:2022`, `27002:2022`, `27701:2019`, `27017:2015`, `27018:2019`, `27037:2012`), **ISO/IEC 25010:2023**, **ISO 22301:2019**, **ISO 37301:2021**, **ISO/IEC 40500:2012 (WCAG)**.

---

## 0. Matriz Maestra: Normas ISO Requeridas y su Equivalencia Legal

Para que una plataforma web transaccional / SaaS sea legalmente sólida, auditable y defendible ante tribunales o entes reguladores (SIC, DIAN), las normas ISO proporcionan los **controles técnicos demostrables** que exigen las leyes:

| Categoría | Norma Internacional | Norma Nacional (ICONTEC) | Propósito Técnico en el Sistema Web | Ley Nacional / Internacional que Respalda |
| :--- | :--- | :--- | :--- | :--- |
| **1. Seguridad de la Información (Base)** | **ISO/IEC 27001:2022** y **27002:2022** | `NTC-ISO/IEC 27001` | Sistema de Gestión de Seguridad de la Información (SGSI): control de accesos, cifrado, gestión de vulnerabilidades y segregación de roles. | **Ley 1581/2012** (Art. 4 lit. g - Principio de Seguridad), **Ley 1273/2009** y Requisitos DIAN para Proveedores/Integradores. |
| **2. Privacidad y Datos Personales** | **ISO/IEC 27701:2019** y **29100** | `NTC-ISO/IEC 27701` | Sistema de Gestión de Información de Privacidad (PIMS): define controles para **Responsables** (*Controllers*) y **Encargados** (*Processors*). | **Ley 1581/2012**, **Decreto 1377/2013**, **GDPR (UE)** (Principio de *Accountability* o Responsabilidad Demostrada ante la SIC). |
| **3. Seguridad y PII en la Nube (SaaS)** | **ISO/IEC 27017:2015** e **ISO/IEC 27018:2019** | `NTC-ISO/IEC 27017` / `27018` | Seguridad en entornos Cloud Multi-tenant (aislamiento de clientes en base de datos) y prohibición de uso comercial no autorizado de PII en la nube. | Circulares Externas de la **SIC** sobre transferencia/transmisión internacional de datos en servidores Cloud (AWS/Supabase/Vercel). |
| **4. Evidencia Digital y Trazabilidad** | **ISO/IEC 27037:2012** e **ISO/IEC 27042** | `NTC-ISO/IEC 27037` | Identificación, recolección, adquisición y preservación de evidencia digital (logs inmutables, cadena de custodia, sellado de tiempo). | **Ley 527/1999** (Arts. 8, 9 y 11 - Integridad, Originalidad y Valor Probatorio de los mensajes de datos) y **Código General del Proceso**. |
| **5. Calidad y Arquitectura de Software** | **ISO/IEC 25010:2023** y **12207** | `NTC-ISO/IEC 25010` | Modelo SQuaRE de calidad del producto software: exactitud funcional, integridad financiera, tolerancia a fallos, seguridad y mantenibilidad. | **Ley 1480/2011** (Art. 6 y Art. 50 - Garantía de calidad, idoneidad y exactitud en precios e impuestos cobrados al consumidor). |
| **6. Continuidad de Negocio y DRP** | **ISO 22301:2019** e **ISO/IEC 27031** | `NTC-ISO 22301` | Sistema de Gestión de Continuidad de Negocio (SGCN): backups (PITR), recuperación ante desastres (RTO/RPO) y operación en contingencia (Offline). | **Resolución DIAN 000165/2023** (Continuidad y contingencia en facturación) y disponibilidad exigida en contratos SaaS (SLA). |
| **7. Gestión de Compliance Legal** | **ISO 37301:2021** e **ISO 31000** | `NTC-ISO 37301` | Sistema de Gestión de Cumplimiento Normativo y Gestión de Riesgos: matriz de obligaciones legales, prevención de lavado/fraude y auditoría. | Responsabilidad corporativa ante la **SIC**, **DIAN** y **UGPP/UIAF** (según volumen transaccional). |
| **8. Accesibilidad y Usabilidad Web** | **ISO/IEC 40500:2012** (WCAG 2.0/2.1) e **ISO 9241** | `NTC 5854` / `NTC-ISO/IEC 40500` | Accesibilidad web para personas con discapacidad (contraste, navegación por teclado, lectores de pantalla) y ergonomía visual. | **Ley Estatutaria 1618 de 2013** y directrices de inclusión digital en servicios abiertos al público. |

---

## 1. Requisitos Previos Operativos (Negocio y Gobierno Corporativo)
*Acciones legales y documentales que el propietario del SaaS (Casa de Software) y los comercios suscritos deben formalizar fuera del código antes de operar con tráfico real:*

1. **Política de Tratamiento de Datos Personales (PTDP) y Aviso de Privacidad (Ley 1581/2012 + ISO 27701):**
   - Redactar y publicar en ruta pública (`/privacidad`) la PTDP identificando a la Casa de Software (razón social, NIT, correo de contacto para ejercicio de derechos ARCO: Acceso, Rectificación, Cancelación y Oposición).
   - Definir claramente la **dualidad de roles legales**:
     - Frente al *Tendero/Suscriptor*: La plataforma SaaS es **Responsable del Tratamiento**.
     - Frente a los *Clientes Finales del Tendero* (registrados en fiados o facturación): El Tendero es el **Responsable** y la plataforma SaaS actúa como **Encargado del Tratamiento** (*Data Processor* bajo ISO 27701).
2. **Contrato de Transmisión de Datos y Acuerdo de Nivel de Servicio (DPA & T&C):**
   - Incorporar en los Términos y Condiciones (T&C) un Anexo de Encargo de Tratamiento de Datos (*Data Processing Agreement* - DPA) conforme al Art. 25 del Decreto 1377 de 2013 e ISO/IEC 27018, además de la cláusula de autorización para almacenamiento en nubes extranjeras (EE. UU. / UE donde operen Supabase y Vercel).
3. **Verificación de Certificaciones de Sub-encargados Cloud (ISO 27001 / SOC 2 Tipo II):**
   - Como el sistema se aloja en infraestructura PaaS/IaaS (Supabase, Vercel, AWS), el sistema hereda los controles de seguridad física y de hipervisor (`ISO/IEC 27017`). Se debe conservar en el repositorio legal de la empresa los certificados vigentes **ISO/IEC 27001** y reportes **SOC 2 Type II** de dichos proveedores para exhibirlos ante requerimientos de la SIC.
4. **Registro Nacional de Bases de Datos (RNBD - SIC):**
   - Si la empresa propietaria del SaaS supera los topes de activos fijados por la ley colombiana (o voluntariamente como buena práctica bajo ISO 37301), registrar las bases de datos ante la Superintendencia de Industria y Comercio.

---

## 2. Flujo / Protocolo Obligatorio en el Ciclo de Vida del Sistema Web
*Secuencia normativa que debe cumplir toda interacción de usuario y transacción comercial desde su origen hasta su archivo o eliminación:*

1. **Paso 1 — Consentimiento Informado y Verificable (`Ley 1581 Art. 9` + `Ley 527` + `ISO 27701`):**
   - Durante el registro del comercio (`AdminRegister`) o del comprador, el usuario debe marcar activamente (*Opt-in* explícito, prohibido usar casillas pre-marcadas) la aceptación de T&C y PTDP.
   - El servidor debe almacenar una prueba criptográfica o registro inmutable del consentimiento: `user_id`, `ip_address`, `user_agent`, `policy_version` (ej. `v1.0-2026`) y `accepted_at` (timestamp UTC del servidor).
2. **Paso 2 — Autenticación y Aislamiento Multi-Tenant (`ISO/IEC 27001 A.8.2` + `ISO/IEC 27017`):**
   - Toda petición autenticada viaja sobre TLS 1.2/1.3 (HTTPS estricto) con JWT firmados.
   - La base de datos ejecuta políticas de Seguridad a Nivel de Fila (**RLS** centralizado vía funciones de seguridad como `get_current_store_id()`), garantizando aislamiento criptográfico y lógico entre comercios.
3. **Paso 3 — Transacción Comercial y Deber de Información (`Ley 1480 Art. 50` + `ISO/IEC 25010`):**
   - Antes de finalizar cualquier compra o cierre de venta, la interfaz presenta el resumen discriminando precio base, impuestos aplicables y medio de pago.
   - El cálculo financiero se ejecuta exclusivamente en el **Backend (PostgreSQL RPC)** para cumplir con el principio de integridad de datos de `ISO/IEC 25010` y prevenir alteraciones en el cliente.
4. **Paso 4 — Generación de Evidencia Digital Inmutable (`Ley 527 Arts. 8-12` + `ISO/IEC 27037`):**
   - Toda operación crítica (venta, anulación, ajuste de inventario, préstamo/fiado, cierre de caja, cambio de permisos) genera un registro en bitácora de auditoría (*Evidence Hub*) con marca temporal del servidor, actor, estado anterior y estado nuevo.
   - Los registros contables y de auditoría son **inmutables** (`Append-Only`): no admiten `DELETE` ni `UPDATE` destructivo; las correcciones se realizan mediante asientos de contrapeso (notas de ajuste/reembolso).
5. **Paso 5 — Retención Legal vs. Derecho de Supresión / Anonimización (`Ley 1581` vs `Estatuto Tributario Art. 632` + `ISO/IEC 27018`):**
   - Cuando un titular solicita la eliminación de sus datos personales (*Derecho al Olvido / Supresión*), el sistema verifica si existen obligaciones legales o fiscales vigentes (ej. facturas o movimientos contables que deben conservarse por **5 años** según el Art. 632 del Estatuto Tributario o **10 años** según el Art. 28 de la Ley 962 de 2005 para libros y papeles del comerciante).
   - Si existe deber de conservación contable, el sistema ejecuta **Anonimización / Seudonimización irreversible** de la PII (desvinculando nombre, teléfono y correo personal) sin destruir la integridad numérica ni el consecutivo de la transacción histórica.

---

## 3. Reglas de Negocio Duras Extrapoladas
*Restricciones inquebrantables derivadas de las normas ISO y leyes colombianas que deben regir la arquitectura del sistema:*

- **RN-ISO-01 (Prohibición de Consentimiento Tácito — Ley 1581 / ISO 27701):** Ningún formulario de creación de cuenta o captura de clientes puede continuar sin el registro explícito de autorización de tratamiento de datos ni sin guardar la versión del documento legal aceptado.
- **RN-ISO-02 (Inmutabilidad Probatoria — Ley 527 / ISO 27037):** Está estrictamente prohibido el borrado físico (`HARD DELETE`) de transacciones financieras, tickets de venta, cierres de caja o logs de seguridad. Todo evento debe preservar su cadena de custodia para tener validez probatoria ante un juez o auditoría de la DIAN/SIC.
- **RN-ISO-03 (Autoridad Única del Servidor — ISO 25010 / ISO 27001):** Ningún cálculo de totales, saldos de cartera (fiados), impuestos o validación de inventario puede ser decidido por el navegador web. El Frontend solo envía intenciones; el Backend valida y calcula.
- **RN-ISO-04 (Visibilidad de Fallos y Cero Ocultamiento — ISO 25010 Fiabilidad / Ley 1480):** Ningún error transaccional o rechazo de integración externa (ej. Proveedor Tecnológico DIAN o pasarela de pagos) puede ser silenciado ni reemplazado por valores por defecto (`$0`, `null`). El usuario debe visualizar el estado real de la transacción en todo momento.
- **RN-ISO-05 (Seguridad de Almacenamiento Local y Offline — ISO 27001 A.8.1 / ISO 22301):** En modos de contingencia u operación *Offline* (IndexedDB / LocalStorage), está prohibido almacenar contraseñas en texto plano, claves privadas o datos sensibles sin protección, y toda cola sincronizada debe validar su integridad temporal al reconectar con el servidor.
- **RN-ISO-06 (Trazabilidad en Cartera y Fiados — Ley 1266 Habeas Data Financiero):** Todo registro de deuda o crédito otorgado a un cliente ("fiado") debe contar con soporte de la transacción origen, fecha exacta, abonos realizados y saldo actualizado en tiempo real, permitiendo al titular consultar su estado de cuenta sin restricciones.
- **RN-ISO-07 (Reversión y Retracto en E-Commerce — Ley 1480 Arts. 47 y 51 / Ley 2439 de 2024):** Si el sistema habilita ventas no presenciales (catálogo web con pago digital), debe existir el flujo de solicitud de retracto (5 días hábiles) y el soporte documental de reversión de pago dentro de los plazos legales.

---

## 4. Impacto Preliminar en el Sistema (Insumo para el Arquitecto)
*Mapeo directo entre las exigencias normativas y los módulos técnicos actuales o futuros de **Tienda Barrio Pro**:*

- **Estructuras de Datos (Supabase / PostgreSQL):**
  - **Trazabilidad de Consentimiento Legal (`ISO 27701` / `Ley 1581`):** Asegurar que la tabla de tiendas/usuarios (`stores` / `profiles`) y clientes (`clients`) registre `terms_accepted_at`, `privacy_policy_version` y `data_treatment_authorized`.
  - **Anonimización Compatible con Contabilidad (`ISO 27018`):** Procedimiento almacenado (RPC) para anonimizar registros en `clients` cuando se invoque el derecho de supresión, manteniendo intactos los registros en `sales` y `client_ledger` una vez que el saldo de deuda sea `$0`.
  - **Evidencia Digital (`ISO 27037`):** Consolidación del módulo `SDD_005_AUDITORIA_TRAZABILIDAD` (*Evidence Hub*) garantizando políticas RLS donde ningún rol (ni siquiera el Admin de la tienda) pueda ejecutar `UPDATE` o `DELETE` sobre las tablas de auditoría.
- **Validaciones UX y Frontend (Vue 3 / Pinia):**
  - **Pantallas de Registro y Checkout:** Casillas de verificación desmarcadas por defecto con enlaces directos a los textos legales versionados.
  - **Accesibilidad (`ISO/IEC 40500` / WCAG 2.1 AA):** Mantener ratios de contraste mínimos de `4.5:1` en textos, soporte de foco por teclado y etiquetas semánticas (`aria-label`) en el POS y catálogo.
  - **Exportación de Datos (Portabilidad y Acceso — `Ley 1581` / `ISO 27701`):** Capacidad desde el panel administrativo para exportar el historial de un cliente o las operaciones de la tienda en formatos estándar (CSV/JSON/PDF) ante requerimientos del titular o de una autoridad.

---
**Siguiente Paso Recomendado:** Ejecutar el flujo de trabajo `@/architect` con el contexto de este documento si deseas desglosar alguna de estas normas (como el módulo de **Consentimiento Legal y Habeas Data Ley 1581 / ISO 27701** o el **Flujo de Anonimización de Clientes**) en Casos de Uso técnicos (FRD/SDD) y criterios de aceptación.
