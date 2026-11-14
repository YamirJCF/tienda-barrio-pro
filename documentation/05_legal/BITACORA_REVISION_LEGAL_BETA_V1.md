# Bitácora Interna de Diseño y Verificación — Documentos Legales Fase BETA (`v1.0`)

> [!WARNING]
> **Alcance y honestidad documental (sin valor de asesoría jurídica ni contable profesional).** Este archivo es **únicamente bitácora interna de diseño y NUNCA se carga en la base de datos (`public.legal_document_versions`)**. Consolida: (1) la lectura directa de 5 documentos públicos de empresas del sector (**Siigo S.A.S.**, **Vendty S.A.S.**, **Soluciones Alegra S.A.S.** y **Treinta Tecnología S.A.S.**); y (2) una **revisión cruzada asistida por IA** (no realizada por una firma de abogados ni por un consultor humano titulado). Este trabajo no reemplaza el concepto ni la revisión de un abogado titulado ni de un Contador Público en Colombia.

---

## 1. Ajustes Incorporados de la Revisión Cruzada Asistida por IA (13 de noviembre de 2026)

| # | Observación de la revisión cruzada por IA | Por qué mejora el borrador | Cómo quedó aplicado en los documentos publicables |
|---|---|---|---|
| **C-1** | **Dispersión de obligaciones y desequilibrio aparente:** el borrador enfatizaba qué *NO* hace la Plataforma, pero tenía disperso qué *SÍ* hace y qué le corresponde al comerciante. | Explicitar los compromisos de la Plataforma como **obligaciones de medios (diligencia razonable)** aporta claridad y reduce el riesgo de cuestionamiento por desequilibrio en un contrato de adhesión. | Se insertaron las **Cláusulas 3A, 3B, 3C y 3D** después de la Cláusula 3, conservando la numeración `1` a `21` y las referencias cruzadas con la Política de Datos. |
| **C-2** | **Resumen previo en lenguaje sencillo:** facilitar la lectura inicial antes del articulado, cuidando que no prometa más que las cláusulas (ej. precisar *"durante la Fase BETA"* en la no venta de datos). | Facilita la comprensión rápida y evita contradicciones entre el resumen y las Cláusulas `3B.4`, `4.3` y `9.4`. | Se incluyó antes de la Cláusula 1 en **tercera persona** (**A1**), precisando *"durante la Fase BETA"* y con regla expresa de prelación del articulado. |
| **C-3** | **Reciprocidad proporcional (`Cláusula 3D.2`) y Cuadro Orientador (`3D.3`):** evitar exigir causa *"exclusiva"* en `3D.2` (que la haría inaplicable en la práctica) y conectarla con la proporcionalidad de `17.3`. | Hace operativa la reciprocidad cuando un daño provenga directamente de un incumplimiento de `3B` y resume 10 situaciones frecuentes en una tabla. | En `3D.2` se dejó *"consecuencia directa... en la proporción en que el daño sea atribuible a LA PLATAFORMA, sin perjuicio de la reducción prevista en la Cláusula 17.3"*, conectada además con la `Cláusula 18`. |
| **C-4** | **Nombre del Pilar (c):** *"Orientación Contable y de Formalización"* rozaba con la `Cláusula 5.1` (*"no presta servicios contables"*). | Reduce el riesgo de confusión terminológica frente a las actividades reservadas a Contadores Públicos (Ley 43 de 1990). | Se renombró en todo el documento a **"Pilar de Organización y Formalización"** (`T&C 1.10`, `5`, `9.1` y `PTDP 4.1.4`). |
| **C-5** | **Salvedad en la entrega *as is* (`Cláusula 4.1`):** aclarar que entregar en estado BETA no exime de los compromisos de seguridad, confidencialidad y avisos. | Acota el alcance de la cláusula `4.1` para que no se lea en contradicción con los deberes de las Cláusulas `3B` y `7`. | Se agregó al final de `4.1`: *"Lo anterior no limita los compromisos de las Cláusulas 3B y 7."* |
| **C-6** | **Jurisdicción (`Cláusula 21.6`) y remisión en `21.4`:** fijar un domicilio único podía resultar gravoso para comerciantes de otros municipios. | Reduce fricción frente a microcomerciantes de distintas ciudades. | En `21.6` se remite a las **reglas generales de competencia del Código General del Proceso** (**A3**), y `21.4` remite a la `Cláusula 3A`. |
| **C-7** | **Frecuencia de cobro (Ley 2300/2023 Art. 3), lenguaje penal prudente (`11.2`) y citas (`3C.3` y Decreto 1074/2015):** agregar el límite diario y semanal tras contacto directo; cambiar *"constituye"* por *"podría configurar"* en `11.2`; citar `7.9(c)` y `Sección 8 de la Política` en `3C.3`; y mantener solo el Art. 2.2.2.25.2.6 del Decreto 1074/2015 (confirmado en línea). **Por verificar contra Diario Oficial:** (i) el Art. 2.2.2.25.2.8 (*Limitaciones temporales al Tratamiento*), que se **retiró del texto publicable** hasta confirmarlo; y (ii) el Art. 3 de la Ley 2300 de 2023, reproducido en documento de la CRC (Comisión de Regulación de Comunicaciones) y en resúmenes web, pendiente de contraste con el Diario Oficial. | Alinea `8.3` con el Art. 3 de la Ley 2300 de 2023, evita calificaciones penales categóricas en `11.2` y deja en el texto publicable únicamente la cita verificada del Decreto 1074. | Aplicado en `3C.3`, `3C.5`, `8.3`, `8.4(a)`, `11.2` y `PTDP Sección 7`. |
| **C-8** | **Agenda para el abogado y el contador (antes de abrir al público o cobrar):** **4 preguntas puntuales para el abogado:** (1) el tope de `$0 COP` (`17.2`) frente a la indemnidad (`18`) —riesgo abierto principal—; (2) si es exigible que el comerciante reembolse multas administrativas de la SIC o la DIAN (`18`); (3) la jurisdicción (`21.6`) en un contrato de adhesión; (4) si anonimizar datos por instrucción del comerciante para estadística y mejora es compatible con el rol de Encargado (`7.3(b)` y `9`). **Además:** verificar obligación frente al **RNBD de la SIC**, monitorear la reforma a la Ley 1581 y revisar con **Contador Público** que ningún texto en pantalla del simulador RST se lea como asesoría. | Separa con transparencia lo que el borrador ya resuelve para una BETA cerrada de lo que requiere concepto profesional humano antes de abrir al público o cobrar. | Documentado como lista de control pre-apertura pública. |

---

## 2. Resumen de los 5 Archivos de Referencia Analizados

| # | Archivo aportado | Empresa y documento real | Vigencia | Estado de integración |
|---|---|---|---|---|
| 1 | `Política_de_Uso_de_Siigo___Siigo_Seguridad.pdf` (16 págs.) | **Siigo S.A.S.** — *Política de Tratamiento de Datos Personales* | 📄 **Vigencia según el propio documento: 28 de enero de 2026** (no verificada en fuente oficial en línea) | Integrado (roles duales, tercero receptor, analítica/IA para innovación, pruebas de soporte por WhatsApp, y reglas de 2 días hábiles y 2 meses del Art. 15 Ley 1581). |
| 2 | `Terminos+y+Condiciones+Vendty-c45506d5.pdf` (68 págs.) | **Vendty S.A.S.** — *T&C POS + Anexos A, B y C* | 📄 **Vigencia según el propio documento: febrero de 2025** (no verificada en fuente oficial en línea) | Integrado (licencia sobre datos operativos, propiedad de mejoras sugeridas sin revelar secretos, catálogo de servicios no incluidos, mitigación del daño, contingencia offline y deberes Art. 18 Ley 1581). *Se descartó su prescripción nula de 1 mes.* |
| 3 | `Software_Contable_y_de_facturación_para_Pymes.pdf` (18 págs.) | **Soluciones Alegra S.A.S.** — *Términos y Condiciones* | 🟡 **Parcialmente desactualizado en normas DIAN (2022/2023)** | Integrado en lo vigente (errores de clasificación del usuario, prohibición de evasión fiscal, modo solo consulta al cierre y no migración a medida). *Se descartó su cláusula de venta de datos a terceros.* |
| 4 | `Versión_2.0._-_Política_de_Privacidad.md` | **Treinta Tecnología S.A.S.** — *Política de Privacidad v2.0* | 📄 **Vigencia según el propio documento: 29 de abril de 2025** (no verificada en fuente oficial en línea) | Integrado (acompañamiento por WhatsApp y restricción de supresión por fraude o defensa legal). *Se descartaron sus plazos europeos de 1–2 meses y permisos invasivos.* |
| 5 | `Colombia_-_Términos_y_Condiciones_de_Suscripción_Treinta_App_.docx.md` | **Treinta Tecnología S.A.S.** — *T&C de Suscripción* | 📄 **Actual según el propio documento** (no verificada en fuente oficial en línea) | Integrado (procedimiento de descargo en 5 días calendario ante quejas de terceros y deslinde de servicios de terceros). |

---

## 3. Decisiones Operativas, Campos Pendientes y Protocolo de Carga

| ID | Decisión operativa | Configuración actual en el texto |
|---|---|---|
| **D-1** | **Benchmark sectorial** (`Cláusula 9.3`) | Activo solo cuando el segmento reúna Datos Anonimizados de **al menos 5 comercios distintos**. |
| **D-2** | **Plazo de solo consulta/descarga al cierre** (`Cláusulas 3B.9` y `15.4`) | **30 días calendario** en modo de solo consulta y exportación CSV, luego supresión. |
| **D-3** | **Cesión a futura sociedad S.A.S.** (`Cláusula 21.3`) | Permitida con aviso previo al comerciante y manteniendo intactas las garantías de la Cláusula 7. |
| **D-4** | **Acceso técnico de soporte** (`Cláusula 7.5`) | Permitido solo para soporte/diagnóstico puntual y registrado en bitácora. |

### Seis (6) campos de identificación a completar antes de publicar en `public.legal_document_versions`
1. `[NOMBRE O RAZÓN SOCIAL]`
2. `[DOCUMENTO / NIT]`
3. `[CIUDAD Y DIRECCIÓN]`
4. `[CORREO OFICIAL]`
5. `[TELÉFONO / WHATSAPP]`
6. `[HORARIO DE SOPORTE]`

### Protocolo de congelación y carga (`v1.0`)
1. **Archivos limpios separados:** los textos publicables se encuentran en `TERMINOS_Y_CONDICIONES_BETA_V1.md` (`terms_of_service`) y `POLITICA_TRATAMIENTO_DATOS_BETA_V1.md` (`privacy_policy`), ya sin esta bitácora, sin encabezados `### DOCUMENTO...` y sin separadores externos.
2. **Inmutabilidad del hash `SHA-256`:** una vez reemplazados los 6 campos entre corchetes, el texto se congela sin alterar espacios ni saltos de línea para que el hash `SHA-256` almacenado coincida exactamente con el texto presentado.
3. **Verificación técnica y humana:** comprobar en base de datos que al aceptar queden guardados `version`, `content_hash` (`SHA-256`) y marca de tiempo del servidor, y realizar una prueba de lectura comprensiva con 1 o 2 tenderos reales.
