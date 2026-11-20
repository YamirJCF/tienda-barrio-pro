# SDD-027-02: Límite de 24 Horas y Caducidad de Caja (DEROGADO / ABSORBIDO)

> [!WARNING]
> **DOCUMENTO DEROGADO Y ABSORBIDO POR CONSOLIDACIÓN ARQUITECTÓNICA (PAC-SDD v2.0 / Alineación `ARQ-002` v1.4)**  
> Este documento se conserva únicamente para trazabilidad histórica del repositorio.  
> **Documentos Rectores Vigentes:** [SDD_003_01_MATRIZ_PERMISOS_EMPLEADOS.md](./SDD_003_01_MATRIZ_PERMISOS_EMPLEADOS.md) (Contrato Marco), [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).  
> **Reglas Vigentes de `FRD-027-02` Consolidadas en `SDD_004` y `SDD_017`:**  
> 1. Al superar 24 horas desde `opened_at`, el turno transiciona a estado **`Expirado/Bloqueado`** (`forced_close = true`) y rechaza toda operación monetaria (`SHIFT_EXPIRED_24H`), emitiendo alerta automática al Administrador en `notifications`.  
> 2. **Propiedad Estricta del Turno (`POL-SEG-02`, `POL-SEG-03`):** Únicamente **quien abrió originalmente ese turno** (ejecutando Cierre Asistido de hasta 3 intentos con su conteo real) o el **Administrador** tienen potestad para cerrarlo. Cualquier otro empleado (incluso con `canOpenCloseCash`) tiene estrictamente bloqueado cerrarlo (`SHIFT_OWNERSHIP_VIOLATION`).  
> 3. **Cierre Forzoso Administrativo sin Conteo Físico Siempre Obligatorio (`FRD-027-02` R5):** Si el abridor original está ausente, el Administrador (`owner`/`manager` vía `rpc_reconciliar_cierre_forzado`) puede cerrar forzosamente declarando conteo real o **omitiendo el conteo físico** (`p_actual_balance = NULL`), asumiendo el servidor el saldo esperado con `difference = 0`, `forced_close_without_count = true` y alerta crítica forense de fondos desconocidos.  
> **Prohibición:** Los equipos de Backend (`/data`) y Frontend (`/ux`) TIENEN PROHIBIDO implementar contratos a partir de este archivo; deben regirse por `SDD_003_01`, `SDD_004` y `SDD_017`.

> **Asociado a:** [FRD-027-02](../FRD/FRD_027_02_LIMITE_24_HORAS_CAJA.md)  
> **Fase del Plan:** Consolidación Documental (Archivo Histórico Redirigido)  
> **Estado:** ⚪ Derogado / Absorbido por Suite Consolidada (`2026-10-17`, nota de redirección alineada a `ARQ-002` v1.4 el `2026-11-19`)  
> **Última Actualización:** 2026-11-19  

---

## 0. Contexto y Restricciones Aplicables

### 0.1 Políticas Globales Activadas (ARQ-002)
Las políticas originalmente listadas en este documento (`POL-AUTH-01`, `POL-SEC-01`, `POL-FIN-01`, `POL-LOG-01`, `POL-AUD-01`) se encuentran activas y gobernadas en [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).

### 0.2 Contratos Vecinos que Limitan el Diseño
Todos los contratos vecinos han sido redirigidos hacia [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).

### 0.3 Auditoría de BD contra Realidad (Deuda Técnica)
Sin deuda técnica propia abierta en este archivo por encontrarse absorbido. Toda brecha de migración sobre las entidades de este dominio reside formalizada bajo la Regla 7 en la sección `§0.3` de [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).

---

## 1. Glosario Local
Los términos de dominio de este submódulo forman parte del glosario unificado de [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).

---

## 2. Diagramas de Secuencia
Los flujos de interacción actualizados bajo el protocolo PAC-SDD v2.0 se encuentran especificados en la sección `§2` de [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).

---

## 3. Diagramas de Estado
Las máquinas de estado vigentes de las entidades relacionadas se encuentran modeladas en la sección `§3` de [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).

---

## 4. Especificación Detallada de Casos de Uso
Los casos de uso de este requerimiento están cubiertos de forma íntegra en la sección `§4` de [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).

---

## 5. Contrato de Interfaz
Los payloads JSON, firmas de procedimientos almacenados y catálogos de códigos de error vigentes están normados en la sección `§5` de [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).

---

## 6. Análisis de Seguridad
Las directivas de seguridad centralizada (`assert_store_access`, `get_current_store_id`, `is_authorized_employee`) aplicables se encuentran especificadas en la sección `§6` de [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).

---

## 7. Modelo de Datos Lógico
El diagrama Entidad-Relación y el diccionario de columnas físicas verificadas contra `information_schema.columns` residen en la sección `§7` de [SDD_004_CONTROL_DE_CAJA.md](./SDD_004_CONTROL_DE_CAJA.md), [SDD_017_CICLO_CONTABLE_Y_SESIONES.md](./SDD_017_CICLO_CONTABLE_Y_SESIONES.md) y [SDD_023_IMPACTO_CRUZADO_MULTICANAL.md](./SDD_023_IMPACTO_CRUZADO_MULTICANAL.md).
