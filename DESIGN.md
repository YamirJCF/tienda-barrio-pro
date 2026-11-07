---
name: Tienda Barrio Pro
description: Sistema de diseño "El Mostrador de Precisión" — claridad financiera táctil, tipografía estructural Work Sans + JetBrains Mono y cero ornamento artificial.
colors:
  primary: "#245feb"
  primary-dark: "#1a46b0"
  primary-light: "#5a8aff"
  brand-teal: "#0f766e"
  brand-teal-light: "#14b8a6"
  accent-emerald: "#10b981"
  accent-mint: "#0df2aa"
  warning-amber: "#f59e0b"
  danger-red: "#dc2626"
  background-light: "#f6f6f8"
  background-dark: "#111621"
  surface-light: "#ffffff"
  surface-dark: "#1e2736"
  ink-strong: "#0c0e12"
  ink-body: "#334155"
  ink-muted: "#64748b"
  border-subtle: "#e2e8f0"
typography:
  display:
    fontFamily: "'Work Sans', system-ui, -apple-system, sans-serif"
    fontSize: "clamp(2.25rem, 4.5vw, 3.5rem)"
    fontWeight: 800
    lineHeight: 1.08
    letterSpacing: "-0.03em"
  headline:
    fontFamily: "'Work Sans', system-ui, -apple-system, sans-serif"
    fontSize: "clamp(1.5rem, 3vw, 2.25rem)"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.02em"
  title:
    fontFamily: "'Work Sans', system-ui, -apple-system, sans-serif"
    fontSize: "1.125rem"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "-0.01em"
  body:
    fontFamily: "'Work Sans', system-ui, -apple-system, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 400
    lineHeight: 1.55
  label:
    fontFamily: "'JetBrains Mono', monospace"
    fontSize: "0.75rem"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.06em"
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  full: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  2xl: "48px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface-light}"
    typography: "{typography.body}"
    rounded: "{rounded.sm}"
    padding: "10px 16px"
  button-primary-hover:
    backgroundColor: "{colors.primary-dark}"
  button-success:
    backgroundColor: "{colors.accent-emerald}"
    textColor: "{colors.surface-light}"
    rounded: "{rounded.sm}"
    padding: "10px 16px"
  button-danger:
    backgroundColor: "{colors.danger-red}"
    textColor: "{colors.surface-light}"
    rounded: "{rounded.sm}"
    padding: "10px 16px"
  button-brand:
    backgroundColor: "{colors.brand-teal}"
    textColor: "{colors.surface-light}"
    rounded: "{rounded.md}"
    padding: "14px 32px"
  card-surface:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.ink-strong}"
    rounded: "{rounded.lg}"
    padding: "16px"
  input-field:
    backgroundColor: "{colors.surface-light}"
    textColor: "{colors.ink-strong}"
    rounded: "{rounded.md}"
    padding: "10px 12px"
---

# Design System: Tienda Barrio Pro

## Overview

**Creative North Star: "El Mostrador de Precisión"**

Tienda Barrio Pro rechaza tanto la estética fría y sobrecargada de los sistemas contables tradicionales como el "AI Slop" de plantillas SaaS llenas de gradientes violetas, tarjetas anidadas sin propósito y tipografías genéricas (`Inter`). Nuestra interfaz se comporta como un **instrumento financiero de mostrador**: táctil, inmediata, de alto contraste y construida alrededor de la legibilidad instantánea del dinero, el inventario y el tiempo.

En las superficies operativas (`frontend/` — modo `Operate`), la ambición visual se expresa mediante **precisión y contención**: superficies limpias sobre un lienzo gris frío muy sutil (`#f6f6f8`) o pizarra nocturna (`#111621`), jerarquía tipográfica decidida en `Work Sans`, y cifras monetarias o de stock ancladas en `JetBrains Mono` con alineación tabular estricta. En las superficies comerciales (`landing/` — modo `Persuade`), el sistema se expande con composiciones tipográficas audaces, ritmo editorial amplio y demostraciones interactivas vivas en lugar de ilustraciones genéricas.

**Key Characteristics:**
- **Bicombinación Tipográfica Estructural:** `Work Sans` lleva la voz humana, cálida y geométrica de la interfaz; `JetBrains Mono` es obligatoria para precios, saldos, códigos, atajos de teclado/texto, contadores de lote y etiquetas técnicas. Prohibido usar `Inter` o fuentes del sistema como voz principal.
- **Semántica Financiera Inequívoca:** Cada color de acento responde a un estado del dinero o de la operación (Azul Operativo para acción principal, Esmeralda para liquidez/cobro exitoso, Ámbar para crédito/alerta preventiva, Rojo para deuda vencida o bloqueo de seguridad).
- **Tactilidad Física:** Todo control interactivo responde al toque con compresión sutil (`active:scale-95`), bordes nítidos de `1px` y estados de carga que preservan la geometría exacta del contenido (*skeletons* estructurales).
- **Cero Ornamento Vacío:** Sin *eyebrows/kickers* decorativos sobre cada título, sin tarjetas dentro de tarjetas y sin gradientes decorativos en textos.

## Colors

La paleta equilibra un chasis neutro de alta legibilidad con acentos saturados que solo aparecen cuando comunican una acción de mostrador o el estado real de un saldo.

### Primary
- **Azul Mostrador** (`#245feb`): Color de acción primaria en la App Operativa (`POS`, navegación activa, confirmación de formularios).
- **Azul Profundo** (`#1a46b0`): Estado `:hover` y `:active` de acciones primarias.
- **Azul Luz** (`#5a8aff`): Acento primario sobre fondos oscuros (`#111621` / `#1e2736`) e indicadores de foco.

### Secondary
- **Teal Editorial** (`#0f766e`): Voz principal en la superficie comercial (`landing/`) y acento de solvencia institucional.
- **Teal Vivo** (`#14b8a6`): Estado interactivo en superficies comerciales y destellos de confirmación.
- **Esmeralda Liquidez** (`#10b981`): Cobros en efectivo, entradas de stock confirmadas, saldos a favor y acceso al módulo de Reportes Financieros.
- **Menta Señal** (`#0df2aa`): Indicadores de sincronización activa y micro-estados positivos sobre superficies oscuras.

### Tertiary
- **Ámbar Fiado** (`#f59e0b`): Advertencias operativas, saldos pendientes en cartera de clientes, stock bajo y cierres con novedad.
- **Rojo Arqueo** (`#dc2626`): Errores bloqueantes, deudas vencidas, faltantes de caja y acciones destructivas.

### Neutral
- **Tinta Fuerte** (`#0c0e12`): Titulares principales, montos totales de venta y texto de máximo contraste en modo claro.
- **Pizarra Cuerpo** (`#334155`): Texto de lectura general, nombres de productos y descripciones.
- **Pizarra Silenciosa** (`#64748b`): Metadatos secundarios, marcas de tiempo relativas y placeholders.
- **Lienzo Mostrador Claro** (`#f6f6f8`): Fondo base de la aplicación en modo día (evita el deslumbramiento del blanco puro en jornada completa).
- **Superficie Papel** (`#ffffff`): Contenedores elevados, filas activas, modales y barra de navegación inferior.
- **Borde Estructural** (`#e2e8f0`): Divisores de `1px` entre ítems de lista y contornos de tarjetas en reposo.
- **Lienzo Nocturno** (`#111621`): Fondo base en modo oscuro.
- **Superficie Pizarra Oscura** (`#1e2736`): Contenedores y tarjetas en modo oscuro.

### Named Rules
**The Money-Color Rule.** El verde esmeralda (`#10b981`), el ámbar (`#f59e0b`) y el rojo (`#dc2626`) están reservados exclusivamente para comunicar flujos de dinero, niveles de inventario o estados de seguridad. Prohibido usarlos como decoración estética aleatoria.

**The 10% Accent Rule.** En cualquier vista operativa (`Operate`), el color primario (`#245feb`) no debe cubrir más del 10% del viewport; su escasez garantiza que el botón de cobro o acción principal sea identificable en menos de 200ms.

## Typography

**Display Font:** `Work Sans` (con fallback a `system-ui, -apple-system, sans-serif`)
**Body Font:** `Work Sans` (con fallback a `system-ui, -apple-system, sans-serif`)
**Label/Mono Font:** `JetBrains Mono` (con fallback a `Menlo, Monaco, monospace`)

**Character:** `Work Sans` aporta una geometría abierta, cálida y altamente legible en tamaños pequeños de pantalla móvil, mientras que `JetBrains Mono` introduce rigor contable en cada cifra, precio, peso y código de lote.

### Hierarchy
- **Display** (`800`, `clamp(2.25rem, 4.5vw, 3.5rem)`, `line-height: 1.08`, `letter-spacing: -0.03em`): Titulares de impacto en `landing/` y totales gigantes de pantalla completa en cierre de venta.
- **Headline** (`700`, `clamp(1.5rem, 3vw, 2.25rem)`, `line-height: 1.15`, `letter-spacing: -0.02em`): Encabezados de sección y resúmenes financieros diarios (`SmartDailySummary`).
- **Title** (`700`, `1.125rem` / `18px`, `line-height: 1.3`, `letter-spacing: -0.01em`): Títulos de vistas móviles, encabezados de modales (`BaseModal`) y valores principales en `StatCard`.
- **Body** (`400` / `500`, `0.9375rem` / `15px`, `line-height: 1.55`, medida máxima `65ch` en bloques de lectura): Nombres de productos, listas de clientes, formularios e instrucciones.
- **Label** (`600`, `0.75rem` / `12px`, `line-height: 1.2`, `letter-spacing: 0.06em`, `uppercase` en encabezados de métrica): Etiquetas de métricas en `StatCard`, badges de estado, atajos del parser (`+5 arroz`) y cabeceras de tabla.

### Named Rules
**The Tabular Money Rule.** Todo monto en pesos (`$ 12.500`), cantidad de inventario (`14.5 kg`), porcentaje, fecha corta o PIN debe renderizarse con `font-variant-numeric: tabular-nums` (preferiblemente en `JetBrains Mono`) para que las columnas verticales jamás bailen al actualizar datos en vivo.

**The No-Eyebrow Rule.** Prohibido colocar *kickers* o etiquetas en mayúscula encima de un título de sección solo por costumbre decorativa. El encabezado lleva su propio peso; las etiquetas `Label` solo acompañan un dato numérico concreto (ej. `VENTAS HOY` sobre `$ 450.000`).

## Layout

- **Arquitectura Mobile-First (`frontend/`):** Diseñada desde un viewport base de `360px–430px` con navegación inferior fija de `64px` (`h-16` + `env(safe-area-inset-bottom)`) limitada a un contenedor central de lectura rápida (`max-w-lg mx-auto` en vistas de columna única, expandiéndose a grillas de 2–3 columnas en tablet/desktop para `POSView` y dashboards).
- **Arquitectura Editorial (`landing/`):** Contenedor centrado de `1080px` (`max-width: 1080px`), con ritmo vertical amplio (`120px` en desktop, `72px` en móvil) y padding horizontal mínimo de `20px–24px`.
- **Ritmo Espacial:** Agrupación interna estrecha (`4px–8px` entre etiqueta y valor), separación interna de contenedor de `16px` (`p-4`), y separación entre bloques funcionales de `16px–24px` (`gap-4` a `gap-6`). Siempre debe existir más espacio encima de un encabezado de bloque que debajo de él.

## Elevation & Depth

El sistema utiliza una jerarquía **Flat-by-Default con Capas Tonales**: la profundidad se comunica primero mediante el contraste entre el lienzo base (`#f6f6f8` en claro / `#111621` en oscuro) y la superficie del contenedor (`#ffffff` / `#1e2736`) delimitada por un borde sutil de `1px` (`#e2e8f0` / `#1f2937`). Las sombras son difusas, con desplazamiento vertical real y nunca halos coloreados de desplazamiento cero.

### Shadow Vocabulary
- **Soft Rest (`shadow-soft`)** (`box-shadow: 0 2px 8px 0 rgba(0, 0, 0, 0.04), 0 1px 2px 0 rgba(0, 0, 0, 0.02)`): Elevación mínima para tarjetas operativas principales (`StatCard`, bloques de resumen).
- **Soft Interactive (`shadow-soft-md`)** (`box-shadow: 0 4px 16px 0 rgba(0, 0, 0, 0.08), 0 2px 4px 0 rgba(0, 0, 0, 0.04)`): Flotación para barras de acción contextuales, dropdowns (`BaseDropdown`) y tarjetas en `:hover` en escritorio.
- **Showcase Frame (`app-frame`)** (`box-shadow: 0 4px 6px rgba(0, 0, 0, 0.04), 0 16px 40px rgba(0, 0, 0, 0.08), 0 0 0 1px rgba(0, 0, 0, 0.06)`): Reservado para marcos de demostración de producto en `landing/`.

### Named Rules
**The No-Nested-Card Rule.** Una tarjeta jamás vive dentro de otra tarjeta con borde y sombra. Para agrupar sub-elementos dentro de una tarjeta o modal, se usan divisores horizontales de `1px` (`divide-y`), espacio en blanco o un fondo tonal plano sin sombra ni borde adicional.

## Shapes

- **Lenguaje de Esquinas:** Curvatura progresiva y funcional. Controles compactos y botones usan `8px` (`rounded-lg`), campos de texto y contenedores de ícono usan `12px` (`rounded-xl`), tarjetas de resumen usan `16px` (`rounded-2xl`), y modales inferiores (*bottom sheets*) usan `24px` (`rounded-t-3xl`).
- **Contornos:** Bordes sólidos de `1px`. Queda prohibido el patrón de alerta con `border-left` grueso (`> 1px`) en tarjetas operativas de la aplicación; los estados de alerta se indican mediante ícono semántico, tinte sutil de superficie y tipografía clara.
- **Iconografía:** Exclusivamente íconos vectoriales de `lucide-vue-next` con grosor consistente (`stroke-width: 1.5` en reposo, `2` en estado activo). Prohibido usar emojis o glifos Unicode como sustitutos de íconos en la interfaz.

## Components

### Buttons (`BaseButton.vue`)
- **Character:** Táctiles, directos y con bloqueo de re-entrada integrado.
- **Shape:** Radio de `8px` (`rounded-lg`), altura táctil cómoda (`py-2 px-4` en `md`, `py-3 px-6` en `lg`).
- **Primary:** Fondo `#245feb`, texto blanco `#ffffff`, peso `500`.
- **Hover / Focus / Active:** Oscurecimiento a `#1a46b0` en hover, anillo de foco visible (`focus-visible:ring-2 focus-visible:ring-offset-2`), compresión física `active:scale-95` y spinner `Loader2` que bloquea clicks repetidos durante promesas pendientes.
- **Variants:** `success` (`#10b981` para confirmar cobros), `danger` (`#dc2626` para acciones destructivas), `secondary` (gris neutro), `outline` (borde `1px` `#d1d5db`) y `ghost` (sin fondo en reposo).

### Inputs / Fields (`BaseInput.vue`, `FormInputCurrency.vue`)
- **Character:** Claros, resistentes a errores de digitación en móvil y con validación en línea inmediata.
- **Style:** Borde `1px` (`#d1d5db` en claro, `#4b5563` en oscuro), fondo `#ffffff` (`#374151` en oscuro), radio `12px` (`rounded-xl`), padding `10px 12px` (`py-2.5 px-3`), `autocomplete="off"` por defecto.
- **Focus:** Transición limpia a borde y anillo `#245feb` (`focus:border-blue-500 focus:ring-blue-500`).
- **Error / Disabled:** Borde `#fca5a5`, texto de ayuda `#dc2626` debajo del campo vinculado por `aria-describedby`. En campos de moneda (`FormInputCurrency`), formato numérico en vivo con `JetBrains Mono`.

### Cards / Containers (`StatCard.vue`)
- **Corner Style:** `16px` (`rounded-2xl`).
- **Background:** `#ffffff` en modo claro, `#1e2736` (`surface-dark`) en modo oscuro.
- **Shadow Strategy:** `shadow-soft` combinada con borde `1px` (`#f3f4f6` en claro, `#1f2937` en oscuro).
- **Internal Padding:** `16px` (`p-4`), con contenedor de ícono tipo *squircle* (`rounded-xl p-2.5`).

### Navigation (`BottomNav.vue`)
- **Style:** Barra fija inferior (`h-16`) con borde superior de `1px` (`#e5e7eb` / `#1f2937`) y soporte para `safe-area-inset-bottom`.
- **States:** Ítem activo en `#245feb` (o `#10b981` para Reportes) con `stroke-width: 2`; inactivos en `#94a3b8` con `stroke-width: 1.5`. Etiquetas concisas de una sola palabra (`10px`, `font-medium`).

### Feedback & Waiting States (`BaseListSkeleton.vue`, `BaseEmptyState.vue`, `PinKeypad.vue`)
- **Skeletons:** Toda vista que consulte a Supabase muestra un esqueleto que imita la geometría exacta de las filas o tarjetas reales mientras la promesa está `pending`.
- **Highlight Pulse:** Los ítems recién creados o sincronizados aplican `.highlight-new` (pulso esmeralda de `3s` que se desvanece suavemente).

## Do's and Don'ts

### Do:
- **Do** usar `Work Sans` para toda la interfaz y `JetBrains Mono` con `tabular-nums` para cada precio, saldo, peso, PIN y código.
- **Do** diseñar cada pantalla móvil pensando primero en el alcance del pulgar en un viewport de `360px–430px` y verificar que ningún texto o cifra se desborde con montos en millones de pesos (`$ 12.450.000`).
- **Do** tematizar las superficies nativas del navegador (`::selection` con tinte primario, `caret-color: #245feb`, `focus-visible` nítido y scrollbars discretos) para que la app se sienta construida a medida.
- **Do** implementar siempre los 4 estados obligatorios de toda vista conectada a datos: `Loading` (Skeleton estructural), `Empty` (`BaseEmptyState` con acción clara), `Error` (mensaje accionable sin silenciar el fallo) y `Success/Data`.

### Don't:
- **Don't** usar la fuente `Inter`, gradientes violeta-azul, texto con gradiente o fondos crema genéricos.
- **Don't** anidar tarjetas con borde/sombra dentro de otras tarjetas ni construir páginas enteras como una grilla monótona de tarjetas idénticas de `ícono + título + párrafo`.
- **Don't** realizar cálculos de totales, saldos o stock en componentes `.vue` o stores de Pinia; la UI solo formatea y presenta la verdad calculada por Supabase.
- **Don't** usar modales de confirmación para acciones triviales o reversibles; resérvalos para cobros finales, cierres de caja, autorizaciones por PIN o eliminaciones críticas.
