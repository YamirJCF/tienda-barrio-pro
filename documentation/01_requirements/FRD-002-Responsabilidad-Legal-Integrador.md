# Análisis Legal y Responsabilidades: Integrador vs Proveedor Tecnológico (DIAN)

Este documento define la postura jurídica, fiscal y operativa de nuestra "Casa de Software" (Integrador) frente a los usuarios (Facturadores) y la Dirección de Impuestos y Aduanas Nacionales (DIAN) en Colombia.

## 1. Los Tres Actores del Ecosistema

Para la DIAN, el flujo de facturación mediante intermediación (API) involucra a tres entes diferentes, cada uno con un régimen legal distinto:

1. **Facturador Electrónico (El Usuario / Negocio):** Es el comercio o empresa que usa nuestro software (nuestro cliente).
2. **Proveedor Tecnológico (PT):** Empresa autorizada explícitamente mediante *Resolución de la DIAN* para fungir como vía legal de transacciones (ej: Siigo, Alegra, The Factory HKA).
3. **Casa de Software (Nosotros / El Integrador):** Creadores del sistema POS/ERP intermedio que orquesta la operación comercial y se conecta al PT vía API.

---

## 2. Definición de Responsabilidades Legales (DIAN y Ley Colombiana)

### A. La Casa de Software (Nosotros)
**Situación ante la DIAN:** Invisibles tributariamente. La DIAN **no** expide resoluciones para "Casas de Software" que usan APIs de terceros, ni nos audita tecnológicamente. 
**Nuestra Responsabilidad Real:** Es de carácter estrictamente **Contractual (Derecho Privado)** frente a nuestro usuario.
*   **Deberes:** Garantizar que los cálculos matemáticos (subtotales, IVA) en el POS sean correctos al enviarse al PT. Asegurar la conectividad de la API. Mantener interfaces donde el usuario pueda reintentar envíos si hay fallos de red.
*   **Límites de Responsabilidad Legal:** Si el Proveedor Tecnológico se cae, o si la DIAN se cae, nosotros NO somos responsables de las sanciones tributarias del usuario. Si el usuario ingresa mal la tarifa del IVA en un producto, la responsabilidad fiscal de ese error tributario es de él, no del software. **Esto debe quedar estipulado en nuestros Términos y Condiciones (T&C).**

### B. El Proveedor Tecnológico (El Aliado API)
**Situación ante la DIAN:** Sujeto de extrema vigilancia regulatoria.
**Su Responsabilidad Real:** Tienen la obligación legal (sancionable por la DIAN con la pérdida de la licencia) de asegurar:
*   Firma criptográfica válida de los XML.
*   Custodia legal y resguardo de la información por el periodo reglamentario (mínimo 5 años en Colombia).
*   Correcto cálculo del CUFE.
*   Interacción directa y segura (Normas ISO 27001) con los servidores del Estado.
*   Emisión de la Representación Gráfica (PDF y QR) cumpliendo las resoluciones vigentes.

### C. El Facturador Electrónico (Nuestro Usuario)
**Situación ante la DIAN:** Sujeto de control tributario final.
**Su Responsabilidad Real:** Según el Estatuto Tributario, el comerciante es el **único responsable** de emitir la factura.
* Si el sistema falla (sea la Casa de Software o el PT), la DIAN castigará al **Usuario**, no a las empresas de tecnología. 
* El usuario tiene la obligación operativa de aplicar los métodos de "Facturación por Contingencia" (factura física pre-impresa autorizada) si nuestro software o la API presentan fallas de sistema prolongadas, para luego transcribirlas cuando haya red.

---

## 3. Estrategia de Mitigación y Términos de Servicio (T&C)

Para salir en limpio y blindar nuestra operación comercial y legal como "Casa de Software", debemos implementar obligatoriamente:

1. **Cláusula de Exención por Terceros (T&C):** Dejar claro en el contrato del SaaS que la facturación electrónica es una integración sujeta al "Proveedor Tecnológico" (tercero autorizado) y a la disponibilidad de la DIAN. Nuestra plataforma no asume pagos de multas o sanciones de la DIAN por intermitencias en redes de terceros.
2. **Garantía Visual de Estado (Auditoría UX):** Para protegernos de demandas civiles, nuestro software DEBE tener un panel tipo "Bitácora" donde el usuario vea claramente si una factura fue "Rechazada por la API" o "Aprobada", trasladando la carga de arreglarla al usuario. Nunca debemos "ocultar" los fallos en pantalla.
3. **Rol de Pasarela:** Somos una pasarela de información. Nuestra responsabilidad termina cuando entregamos el payload (JSON) a la API del Proveedor Tecnológico y mostramos la respuesta en pantalla.

---
**Conclusión para el Negocio.**
Al operar como Integradores, la DIAN no nos exige Patrimonio Líquido Mínimo, ni certificaciones ISO 27001 obligatorias, ni fianzas, salvaguardando nuestro capital. Toda nuestra atención legal se moverá a redactar unos excelentes *Términos y Condiciones Generales de Uso* del Software.
