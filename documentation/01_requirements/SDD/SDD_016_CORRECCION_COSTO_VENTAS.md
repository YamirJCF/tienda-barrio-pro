# SDD-016: Registro y Congelamiento de Costo en Ventas (COGS) (DEROGADO / ABSORBIDO)

> [!WARNING]
> **DOCUMENTO DEROGADO Y ABSORBIDO POR CONSOLIDACIÓN ARQUITECTÓNICA (PAC-SDD v2.0)**  
> Este documento se conserva únicamente para trazabilidad histórica del repositorio.  
> **Documento Rector Vigente:** [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md)  
> **Justificación:** Fusionado formalmente con SDD-010 en el documento unificado SDD_010_016_VALORACION_FIFO.md (Ola 2) que gobierna consume_stock_fifo y sale_items.unit_cost.  
> **Prohibición:** Los equipos de Backend (`/data`) y Frontend (`/ux`) TIENEN PROHIBIDO implementar contratos a partir de este archivo; deben regirse exclusivamente por el SDD absorbente indicado arriba.

> **Asociado a:** [FRD-016](../FRD/FRD_016_CORRECCION_COSTO_VENTAS.md)  
> **Fase del Plan:** Consolidación Documental Pre-Código (Archivo Histórico)  
> **Estado:** ⚪ Derogado / Absorbido por Suite Consolidada (2026-10-17)  
> **Última Actualización:** 2026-10-17  

---

## 0. Contexto y Restricciones Aplicables

### 0.1 Políticas Globales Activadas (ARQ-002)
Las políticas originalmente listadas en este documento (`POL-AUTH-01`, `POL-SEC-01`, `POL-FIN-01`, `POL-LOG-01`, `POL-AUD-01`) se encuentran activas y gobernadas en [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md).

### 0.2 Contratos Vecinos que Limitan el Diseño
Todos los contratos vecinos han sido redirigidos hacia [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md).

### 0.3 Auditoría de BD contra Realidad (Deuda Técnica)
Sin deuda técnica propia abierta en este archivo por encontrarse absorbido. Toda brecha de migración sobre las entidades de este dominio reside formalizada bajo la Regla 7 en la sección `§0.3` de [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md).

---

## 1. Glosario Local
Los términos de dominio de este submódulo forman parte del glosario unificado de [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md).

---

## 2. Diagramas de Secuencia
Los flujos de interacción actualizados bajo el protocolo PAC-SDD v2.0 se encuentran especificados en la sección `§2` de [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md).

---

## 3. Diagramas de Estado
Las máquinas de estado vigentes de las entidades relacionadas se encuentran modeladas en la sección `§3` de [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md).

---

## 4. Especificación Detallada de Casos de Uso
Los casos de uso de este requerimiento están cubiertos de forma íntegra en la sección `§4` de [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md).

---

## 5. Contrato de Interfaz
Los payloads JSON, firmas de procedimientos almacenados y catálogos de códigos de error vigentes están normados en la sección `§5` de [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md).

---

## 6. Análisis de Seguridad
Las directivas de seguridad centralizada (`assert_store_access`, `get_current_store_id`, `is_authorized_employee`) aplicables se encuentran especificadas en la sección `§6` de [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md).

---

## 7. Modelo de Datos Lógico
El diagrama Entidad-Relación y el diccionario de columnas físicas verificadas contra `information_schema.columns` residen en la sección `§7` de [SDD_010_016_VALORACION_FIFO.md](./SDD_010_016_VALORACION_FIFO.md).
