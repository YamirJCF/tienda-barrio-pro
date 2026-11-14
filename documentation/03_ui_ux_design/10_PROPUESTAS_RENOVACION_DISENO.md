# 10 - Definición Profesional de Estilo y 3 Nuevas Propuestas (Inspiración Nu, Nequi y Fintech Editorial)

> **Rol Activo:** Diseñador de UX/UI (`@[/ux]`)  
> **Motor Generativo Utilizado:** **Stitch MCP** (`projects/15343944491388602158`)  
> **Restricción Invariante:** Conservación estricta de **`Work Sans`** (voz humana, títulos y etiquetas) + **`JetBrains Mono`** (`tabular-nums` para saldos, precios, cantidades y teclado numérico).  
> **Archivo Interactivo con las 3 Propuestas en Vivo:** [`propuestas-renovacion-diseno.html`](../../propuestas-renovacion-diseno.html)  
> **Certificación Determinista Impeccable:** `[]` (0 violaciones, código de salida `0`).

---

## 1. Diagnóstico Profesional: ¿Por qué el diseño actual parece un "juguete / prototipo"?

Cuando una aplicación funcional tiene buenas intenciones pero se percibe como un "prototipo escolar" o "aplicación de juguete", casi nunca es por falta de componentes, sino por **exceso de estímulos compitiendo al mismo nivel**. Al auditar [`DashboardView.vue`](../../frontend/src/views/DashboardView.vue) y [`POSView.vue`](../../frontend/src/views/POSView.vue) frente a los sistemas de diseño de **Nu (NuDS)** y **Nequi**, encontramos 4 causas raíz exactas:

1. **El "Síndrome del Arcoíris" (Competencia Cromática):**
   - **Hoy en el prototipo:** En el Inicio tienes una barra verde brillante (`ABIERTO`), 4 tarjetas de colores distintos (`Caja Real` verde, `Ventas` azul, `Por Cobrar` ámbar, `Inventario` rojo/morado) y un botón grande azul (`Nueva Venta POS`).
   - **En un producto profesional (Nu / Nequi):** El **90% de la pantalla es neutra** (blanco puro `#FFFFFF`, gris nube `#F5F6F8` y texto carbón `#111318`). Solo existe **1 color de marca protagonista**. Los colores semánticos (verde/ámbar/rojo) se usan en puntos de `8px` o píldoras diminutas, **nunca** para pintar bloques enteros que compiten entre sí.
2. **Ausencia de un "Dato Héroe" (Empate Visual 2×2):**
   - **Hoy en el prototipo:** Las 4 métricas financieras tienen exactamente el mismo tamaño en una cuadrícula `2×2`. Cuando todo grita con el mismo tamaño, el ojo no sabe dónde mirar primero.
   - **En Nu y Nequi:** Existe **1 único Dato Héroe** arriba (`Caja Real Disponible: $1.250.000` en `36px` bold con botón de ojo para ocultar saldo), y el resto de métricas viven debajo en renglones o bolsillos tranquilos.
3. **Exceso de Cajas, Bordes y Sombras ("Box-in-Box"):**
   - **Hoy en el prototipo:** Tarjetas con borde dentro de contenedores con borde y sombra, además de etiquetas técnicas en mayúscula sostenida (`MODULO OPERATIVO`, `PLU: ___ |`).
   - **En Nu y Nequi:** El **espacio en blanco (`24px`–`32px`)** separa las secciones mucho mejor que las cajas. Los divisores son líneas de `1px` casi invisibles (`#F1F5F9`).
4. **Teclado POS con aspecto de calculadora pesada:**
   - **Hoy en el prototipo:** Botones cuadrados con bordes grises gruesos y varios colores (`CANT` amarillo, `+ AGREGAR` negro, `COBRAR` verde).
   - **En Nu y Nequi:** Las teclas numéricas son **"Ghost Keys"** (números limpios flotando sobre blanco o sobre círculos suaves `#F8FAFC` sin bordes oscuros) y un único botón tipo píldora (`rounded-full`) al final para cobrar.

---

## 2. ¿Cómo se define el estilo de un producto en un ambiente profesional?

En equipos de diseño de producto fintech (como el equipo de **NuDS en Nubank** o el equipo de **Sistema de Diseño de Nequi**), el estilo no se elige "al ojo", sino siguiendo un proceso de **5 etapas**:

### Paso 1: Benchmarking Funcional y Principios de Marca (Design Tenets)
Se eligen 2 referentes probados en el mercado real (en nuestro caso **Nu** por su limpieza radical y **Nequi** por su estructura cercana de *Disponible + Bolsillos*) y se fijan **3 reglas innegociables**:
- *Regla 1 — Silencio Visual:* Si un borde, sombra o color de fondo se puede quitar sin que se pierda la estructura, se quita.
- *Regla 2 — Un Solo Punto Focal por Pantalla:* En `DashboardView` manda el **Efectivo Disponible en Caja**; en `POSView` manda el **Total a Cobrar**.
- *Regla 3 — Lenguaje Humano, Cifras de Precisión:* Cero jerga de ingeniero en la interfaz (`Work Sans` cálida para hablarle al tendero + `JetBrains Mono` tabular para el dinero).

### Paso 2: La Regla 60-30-10 de Proporción de Color
Para que la app deje de verse como juguete de inmediato, se bloquea por contrato la proporción de color en cada pantalla:
- **60% Lienzo y Espacio Negativo (Superficies):** Blanco puro (`#FFFFFF`) y gris seda/nube (`#F5F6F8`).
- **30% Tinta y Estructura Tipográfica:** Negro Carbón (`#111318`) para títulos y montos principales; Gris Pizarra (`#64748B`) para etiquetas secundarias.
- **10% Acento Único de Acción:** Un solo color reservado para el botón principal (`CTA`) y el indicador activo de navegación.

### Paso 3: Arquitectura de Información por "Revelación Progresiva"
En lugar de mostrar todas las tarjetas al mismo nivel:
- **Nivel 1 (Arriba):** Monto Héroe (`Disponible en Caja`) + 4 accesos rápidos de 1 toque.
- **Nivel 2 (Centro):** Renglones limpios o Bolsillos suaves para `Ventas de hoy`, `Fiados por cobrar` e `Inventario`.

### Paso 4: Exploración Comparativa sobre Pantallas Reales (3 Direcciones)
Se construyen **3 caminos visuales distintos** aplicando las mismas reglas de limpieza sobre las pantallas reales del sistema (`DashboardView.vue` y `POSView.vue`) para tomar una decisión informada.

### Paso 5: Tokenización en Código (`design.json` + `tailwind.config.js`)
Una vez elegida la opción ganadora, se congelan los tokens (`--bg-surface`, `--ink-primary`, `--accent-brand`, radios y espaciados) y se aplican a los componentes base sin tocar la lógica del backend.

---

## 3. Las 3 Nuevas Opciones Limpias (Generadas con Stitch MCP)

| Dimensión | Opción 1: **Claridad Nu** (Inspiración Nubank) | Opción 2: **Bolsillos Dinámicos** (Inspiración Nequi) | Opción 3: **Silencio Editorial** (Monocromo + Esmeralda) |
|-----------|------------------------------------------------|-------------------------------------------------------|----------------------------------------------------------|
| **Referente Directo** | **Nu (Nubank / NuDS)** | **Nequi Colombia (Rediseño Moderno)** | **Revolut Light / Cash App (Fintech Suizo)** |
| **Lienzo (60%)** | Blanco Puro (`#FFFFFF`) con aire amplio (`24px`) | Cabecera Uva Noche (`#18112B`) + Hoja Blanca curva (`rounded-t-3xl`) | Gris Piedra suave (`#F7F7F8`) + Tarjetas Blancas (`#FFFFFF`) |
| **Acento Único (10%)** | **Violeta Nu (`#6D28D9`)** | **Rosa Orquídea (`#DB2777`)** + punto Esmeralda (`#10B981`) | **Negro Carbón (`#111318`)** + cobro **Esmeralda (`#059669`)** |
| **Cómo resuelve el Inicio (`DashboardView`)** | Un solo saldo grande sobre blanco, **4 botones circulares en fila** (`#F3F4F6`) y 3 filas limpias divididas por líneas de `1px` (`#F1F5F9`) sin cajas. | Tarjeta protagonista *"Disponible en Caja"* arriba en fondo oscuro, **Bolsillos del Negocio** en tarjetas nube (`#F8FAFC`) y botón flotante `$ Nueva Venta POS`. | Tarjeta Héroe blanca con saldo en `36px`, botón ancho en Negro Carbón (`+ Nueva Venta POS`) y renglones contables monocromáticos. |
| **Cómo resuelve el POS (`POSView`)** | Lista limpia sin bordes, buscador en píldora (`rounded-full`), **Ghost Numpad** (números flotando sobre blanco) y botón píldora Violeta `Cobrar $12.800 →`. | Resumen del total en cabecera oscura, productos en píldoras suaves (`#F8FAFC`), teclado redondeado amigable y botón Orquídea `Cobrar $12.800`. | Ticket blanco nítido, barra PLU sobria, teclado minimalista blanco sobre piedra y un único botón verde esmeralda `Cobrar $12.800`. |
| **Stitch Design System** | `assets/18225198082875512479` | `assets/16373973118072947131` | `assets/137910355072377972` |
| **Stitch Screen Inicio** | `06ecc28afa9b4115b2e1cd802cb470e2` | `7e5afe9d9eb84f6f831be3afa6e08afa` | `d3463c7d4a064048a9e5f78fd36cbb16` |
| **Stitch Screen POS** | `ec5df00f06a84bf39ff23985856ea9d0` | `b18e736442d24e4f857fc258e11b5266` | `767c00baf9a04d1db07baa8266556b3d` |
