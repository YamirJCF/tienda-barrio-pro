# 🕵️‍♂️ Informe de Arquitectura: Alineación FRD vs Código Actual

**Documento Analizado:** `FRD_Reportes_Historiales_v1.0.md`
**Versión del Código:** Febrero 15, 2026
**Rol:** Arquitecto de Requisitos

---

## 🚦 Veredicto General: **DESALINEACIÓN CRÍTICA (Esperada)**

El FRD actúa correctamente como un documento de **"Definición de Futuro"**. Describe un estado ideal que **NO existe** actualmente en el código.

*   **Alineación en Diagnóstico:** ✅ **ALTA**. El FRD describe con precisión quirúrgica las limitaciones actuales (falta de costos, UI estática, ceguera financiera).
*   **Alineación en Funcionalidad:** ❌ **NULA**. El 90% de las funcionalidades propuestas en la sección 5, 6 y 7 **NO están implementadas**.

---

## 🔍 Hallazgos Detallados (Gap Analysis)

### 1. Arquitectura de Datos (Cimientos)
| Entidad | FRD (Requerido) | Código Actual (Realidad) | Brecha |
|---------|-----------------|--------------------------|--------|
| **`products`** | Columna `cost` (Costo Promedio) | ❌ INEXISTENTE | 🔴 **Bloqueante**. Imposible calcular ganancia. |
| **`sale_items`** | Columna `unit_cost` (Costo Histórico) | ❌ INEXISTENTE | 🔴 **Bloqueante**. No hay historial de márgenes. |
| **`inventory_movements`** | Costo monetario de la entrada | ❌ INEXISTENTE | 🔴 **Bloqueante**. No se puede valorar inventario. |

### 2. Lógica de Negocio (Backend RPCs)
| RPC | FRD (Requerido) | Código Actual (Realidad) | Estado |
|-----|-----------------|--------------------------|--------|
| `get_daily_summary` | Operativo diario | ✅ Existe y coincide | 🟢 Alineado |
| `get_financial_summary` | Ganancia Neta y Costos | ❌ NO EXISTE | 🔴 Pendiente |
| `get_top_selling_products` | Ranking con ganancia | ❌ NO EXISTE | 🔴 Pendiente |
| `get_stagnant_products` | Días sin venta | ❌ NO EXISTE | 🔴 Pendiente |

### 3. Interfaz de Usuario (Frontend)
| Componente | FRD (Requerido) | Código Actual (Realidad) |
|------------|-----------------|--------------------------|
| **Dashboard Ejecutivo** | Pantalla principal con ganancias | ❌ No existe. Solo hay un resumen bruto en `SmartDailySummary`. |
| **Top Ventas** | Gráficos y lista detallada | ❌ No existe. |
| **Historiales** | Búsqueda y rango fechas libre | ⚠️ Parcial. Solo presets rígidos y listas simples. |

---

## ⚠️ Riesgos de Implementación Detectados

Al contrastar el FRD con el código, identifico estos riesgos técnicos para la implementación:

1.  **Migración de Datos "Ciegos"**: Como no tenemos costos históricos, el Día 1 del nuevo dashboard mostrará **Ganancia = Ventas** (Margen 100%) o **Ganancia = $0** (Margen 0%), dependiendo la estrategia. El FRD sugiere migrar asumiendo un margen del 30%, lo cual requiere un script SQL delicado.
    
2.  **Impacto en Rendimiento RPC Venta**: Agregar la lógica de buscar costos y escribir en trazas históricas (`sale_items`) aumentará ligeramente el tiempo de la transacción `rpc_procesar_venta_v2`.

3.  **Deuda Técnica en Frontend**: El componente `AdminHubView.vue` necesitará una refactorización mayor para soportar el sub-routing del nuevo Dashboard, ya que actualmente es una vista monolítica.

---

## ✅ Recomendación del Arquitecto

El documento FRD es **SÓLIDO y APROBADO** para ejecución. No refleja el presente, sino que traza el camino exacto para cubrir las falencias detectadas.

**Siguientes Pasos Recomendados (Roadmap Técnico):**

1.  **Fase de Base de Datos (Inmediata):** Ejecutar scripts para agregar columnas de costos (`products`, `sale_items`).
2.  **Fase de Migración (Script):** Popular costos estimados (Precio * 0.7) para evitar dashboard vacío.
3.  **Fase Backend:** Implementar `get_financial_summary`.
4.  **Fase Frontend:** Construir `FinancialDashboard.vue`.
