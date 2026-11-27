# 📐 Estándar ARQ-005: Barrera Lógica Anti-Desvío y Glosario Único del Tendero

**Versión:** 1.0  
**Fecha:** 2026-11-26  
**Autor:** Arquitecto de Producto  
**Estado:** ✅ Activo  
**Documentos Relacionados:** `ARQ_002_POLITICAS_GLOBALES_NEGOCIO.md` (`POL-PROD-01`), `SYSTEM_BOUNDARIES.md`, `PRODUCT.md`

---

## Problema que Resuelve

En un sistema de Punto de Venta e Inventario, conectar nuevas funciones o reescribir el *"cómo se hace"* una operación siempre parece razonable en abstracto. Sin una barrera lógica interna orientada al oficio real del tendero de barrio, ocurren dos desviaciones graves:

1. **Sobre-ingeniería de escritorio (Deriva hacia Minisupermercado):** Se imponen al tendero controles burocráticos copiados de cadenas corporativas (ej. exigir arqueo manual de billeteras digitales que no están en el cajón físico, pedir fechas de vencimiento por producto o mostrar jerga técnica como *"SQL"* y *"OPEX"*).
2. **Ciclo de refactorización infinita (*Perpetual Churn*):** Se reescribe repetidamente cómo funcionan módulos ya estables sin que exista un fallo contable ni un bloqueo real en mostrador, rompiendo contratos en cascada.

Mientras `SYSTEM_BOUNDARIES.md` fija los límites **hacia afuera** (no DIAN, no pasarelas bancarias, no multi-sucursal), este estándar fija la **barrera lógica hacia adentro**: protege la esencia de la tienda de esquina y congela los módulos que ya cumplen su propósito.

---

## I. Los Tres Muros de la Barrera Lógica (`POL-PROD-01`)

Toda nueva funcionalidad, ajuste de regla o propuesta de refactorización DEBE superar secuencialmente estas tres compuertas antes de redactar o modificar cualquier FRD:

### Muro 1 — Voluntariedad y Realidad Física ("La libreta no secuestra el mostrador")
- **Declaración:** **Tienda Barrio Pro** es una **Libreta Inteligente Voluntaria con Respaldo y Orden**, no una registradora fiscal obligatoria. El tendero utiliza el sistema por interés propio de control; el software jamás pretende paralizar la vida física del local fuera de la pantalla, pero **dentro de la libreta** aplica rigor matemático absoluto sobre todo lo que el tendero decide registrar.
- **Filtro obligatorio:** Toda acción exigida en pantalla DEBE corresponder 1:1 a un acto físico real y verificable en el mostrador. Queda prohibido exigir conteos manuales sobre cuentas bancarias/billeteras externas al cajón físico o aceptar casillas sin diligenciar disfrazadas silenciosamente como cero (`0`).

### Muro 2 — Fricción Racional (Deliberada) vs. Fricción Accidental
- **Fricción Racional (Permitida y Protegida):** Solo se admite exigir un paso adicional al usuario cuando compra **seguridad jurídica bilateral, resguardo patrimonial o hábito de orden por periodo** (ej. cédula obligatoria por única vez al dar de alta un cliente de fiado; cierre obligatorio de turnos que superen las 24 horas; separación consciente entre entrada de mercancía y registro de deuda a proveedor).
- **Fricción Accidental (Prohibida):** Queda prohibido añadir campos obligatorios, pasos intermedios, modales de supervisión o tecnicismos que no eviten una fuga real de dinero ni aporten respaldo legal (ej. mostrar controles de pausa de empleado cuando opera el propio dueño, o pedir fechas de vencimiento por lote en entradas).

### Muro 3 — Cortafuegos contra la Refactorización Infinita
- **Declaración:** Si un flujo implementado **no pierde dinero, no corrompe inventario y no contradice la realidad física del mostrador**, queda **prohibido** reescribir *"cómo funciona"* por motivos estéticos o por imaginar casos teóricos de escritorio.
- **Regla de admisión:** Un módulo congelado solo se reabre ante (a) un defecto verificable de integridad de datos/seguridad o (b) evidencia empírica directa de bloqueo en operación real de mostrador. Toda otra idea pasa al **Congelador (*Parking Lot*)**.

---

## II. Matriz Oficial de Zonas Congeladas

Los siguientes bloques funcionales quedan declarados **estables e intocables** en su lógica de negocio:

| Dominio | Criterio Consolidado | Estado |
|---------|----------------------|--------|
| **Cobro base en POS y cola offline acotada** | Venta en menos de 3 toques, cálculo por peso/valor, deshacer limpieza de carrito y encolado offline exclusivo del POS (`FRD-007-01`, `FRD-012`). | 🧊 Congelado |
| **Cédula obligatoria en alta de Fiado** | Prueba de voluntad bilateral entre tendero y vecino, exigida una única vez al crear la ficha (`FRD-009`, `FRD-029`, `POL-PRIV-01`). | 🧊 Congelado |
| **Protección de Stock `0` en libreta y Venta Forzada** | Dentro de la libreta no se vende en negativo salvo excepción auditada del Administrador en línea (`FRD-006-01`, `POL-LOG-02`). | 🧊 Congelado |
| **Disciplina de turnos de máximo 24 horas** | Fomenta responsabilidad por periodo de venta y trazabilidad limpia sin cortar turnos nocturnos menores a 24h (`FRD-017`, `FRD-027-02`, `POL-SEG-02`). | 🧊 Congelado |
| **Independencia entre Entradas y Cuentas por Pagar** | Mantiene la naturaleza de libreta sin contabilidad de causación pesada y refuerza la conciencia de deuda (`FRD-006-01-01`, `FRD-019`, `POL-LOG-01`). | 🧊 Congelado |
| **Vitrina de Empleados en Administración** | Las opciones de gestión de equipo permanecen visibles en Administración para comunicar capacidad de crecimiento sin lógica condicional frágil por conteo de empleados (`FRD-003-01`). *(En el POS, la pausa operativa aplica únicamente a empleados).* | 🧊 Congelado |

---

## III. Glosario de Lenguaje Único del Tendero

Toda etiqueta visible al usuario en la aplicación y todo texto funcional en documentos `FRD` o `UXD` DEBE hablar el idioma cotidiano del tendero colombiano, erradicando jerga de ingeniería de software o contabilidad corporativa.

### 3.1 Tabla de Traducción Obligatoria

| ❌ Término Prohibido en Interfaz / FRD | ✅ Término Oficial del Tendero | Contexto de Uso |
|---------------------------------------|-------------------------------|-----------------|
| *"Nueva Entrada Atómica"* / *"Entrada Atómica"* | **Registrar Entrada** / **Entrada de Mercancía** | Ingreso de compras o reposición al inventario (`FRD-006-01-01`). |
| *"Total factura (SQL)"* / *"Validado por SQL"* | **Total de la entrada** / **Total calculado** | Resumen de confirmación tras ingresar mercancía. |
| *"Gastos OPEX"* / *"Categoría OPEX"* | **Gastos de Caja** / **Categoría del gasto** | Salidas cotidianas pagadas desde la caja del turno (`FRD-004`, `FRD-026`). *(La sigla técnica OPEX solo se admite internamente en fórmulas financieras de `FRD-018`, nunca en botones o etiquetas operativas).* |
| *"Nequi Contado"* / *"Llave Bre-B Contado"* | **Ventas / Movimientos por Nequi** y **por Llave Bre-B** | Resumen informativo de pagos digitales del turno (nunca como conteo físico manual). |
| *"Efectivo Total Contado"* / *"Balance de apertura"* | **Efectivo contado en cajón** / **Base inicial en efectivo** | Apertura y cierre físico del turno de caja (`FRD-004`). |
| *"Fecha de vencimiento"* (en entradas/productos) | *(Eliminado de la interfaz de inventario)* | Excluido permanentemente por `SYSTEM_BOUNDARIES.md` (solo existe fecha de vencimiento en facturas por pagar a proveedores de `FRD-019`). |

### 3.2 Regla de Verificación Lingüística
1. Ninguna pantalla operativa puede mostrar siglas de arquitectura o base de datos (`SQL`, `RPC`, `UUID`, `JSON`, `OPEX`, `FIFO` como requisito para entender una acción básica, `Atómica`, `Idempotencia`).
2. Ningún texto dirigido al **Administrador (Dueño)** puede hablarle en tercera persona como si tuviera un jefe superior (ej. *"El administrador verá tu estado como En Pausa"* o *"Se envió alerta al Administrador"* cuando es el propio Administrador quien ejecuta la acción).

---

## Historial de Cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1.0 | 2026-11-26 | Arquitecto de Producto | Creación inicial de la Barrera Lógica (3 Muros), Matriz de Zonas Congeladas y Glosario Único del Tendero. |

---

**Firmado:** Arquitecto de Producto  
**Fecha:** 2026-11-26
