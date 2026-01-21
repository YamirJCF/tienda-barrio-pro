# Política de Migración de Datos: localStorage → Supabase

> **Documento Arquitectónico**  
> Versión: 1.0  
> Fecha: 2026-01-21  
> Estado: ✅ Decisión Tomada

---

## Decisión: Hard Reset con Seeds

> [!IMPORTANT]
> **Se descarta la opción de script de migración.** El sistema iniciará con datos limpios (Seeds) al conectar Supabase.

---

## Análisis Costo-Beneficio

| Opción | Desarrollo | Beneficio | Riesgo | Decisión |
|--------|------------|-----------|--------|----------|
| **Script Migración** | 8-16h | Preserva datos demo | Bugs de mapeo ID→UUID | ❌ Descartado |
| **Hard Reset + Seeds** | 2h | Base limpia | Pérdida de datos demo | ✅ Seleccionado |

### Justificación Económica

1. **Datos Actuales = Demos**: No hay clientes reales ni ventas de producción
2. **Costo de Scripts**: 8-16 horas de desarrollo + testing
3. **Riesgo de Bugs**: Mapear IDs numéricos a UUIDs es propenso a errores
4. **ROI**: Tiempo ahorrado (6-14h) → invertir en QA del sistema real

---

## Estrategia de Implementación

### Fase 1: Preparación de Seeds

Crear archivos JSON con datos iniciales de demostración:

```
src/data/seeds/
├── products.json      # 20 productos de ejemplo
├── clients.json       # 5 clientes de demo
├── categories.json    # Categorías estándar de tienda
└── employees.json     # Admin + 1 cajero de prueba
```

**Formato de ejemplo (`products.json`):**

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "name": "Leche Entera Colanta",
    "plu": "1001",
    "price": 5200,
    "cost_price": 4500,
    "current_stock": 24,
    "category": "Lácteos",
    "is_weighable": false
  }
]
```

### Fase 2: Script de Carga

```sql
-- Ejecutar al configurar nueva tienda
INSERT INTO products (id, store_id, name, plu, price, cost_price, current_stock, category, is_weighable)
SELECT 
  gen_random_uuid(),
  :store_id,
  seed->>'name',
  seed->>'plu',
  (seed->>'price')::decimal,
  (seed->>'cost_price')::decimal,
  (seed->>'current_stock')::decimal,
  seed->>'category',
  (seed->>'is_weighable')::boolean
FROM json_array_elements(:seeds_json) as seed;
```

### Fase 3: Cleanup de localStorage

Al confirmar conexión exitosa con Supabase:

```typescript
// Solo ejecutar DESPUÉS de sync exitoso
const cleanupLocalStorage = () => {
  const keysToRemove = [
    'tienda-inventory',
    'tienda-sales', 
    'tienda-clients',
    'tienda-employees'
  ];
  keysToRemove.forEach(key => localStorage.removeItem(key));
  console.log('localStorage migrado a Supabase');
};
```

---

## Plan de Rollback

> [!CAUTION]
> **Mitigación QA R-06**: Documentar cómo revertir si la migración falla

### Principio: No Destruir Hasta Confirmar

1. **PRE-MIGRACIÓN**: localStorage permanece intacto
2. **DURANTE**: Nuevas transacciones van a Supabase, localStorage queda "congelado"
3. **POST-MIGRACIÓN**: Eliminar localStorage solo tras:
   - 7 días de operación estable en producción
   - Admin confirma manualmente "Migración Completada"

### Escenario de Rollback

Si Supabase falla críticamente en los primeros 7 días:

1. Desactivar conexión a Supabase (`VITE_SUPABASE_ENABLED=false`)
2. Frontend vuelve a leer localStorage automáticamente
3. Transacciones del período Supabase deben exportarse manualmente

**Flag de Control:**

```typescript
// composables/useDataSource.ts
const dataSource = computed(() => {
  if (import.meta.env.VITE_SUPABASE_ENABLED === 'true') {
    return 'supabase';
  }
  return 'localStorage'; // Fallback
});
```

---

## Comunicación al Usuario

### Pantalla de Primera Conexión

```
┌────────────────────────────────────────┐
│ 🚀 ¡Tienda de Barrio Pro 2.0!         │
│                                        │
│ Tu tienda ahora se sincroniza en la   │
│ nube. Tus datos de prueba anteriores  │
│ han sido reemplazados.                │
│                                        │
│ Datos iniciales cargados:              │
│ • 20 productos de ejemplo              │
│ • 5 clientes de demo                   │
│ • 1 usuario cajero                     │
│                                        │
│ [Empezar a Configurar Mi Tienda]       │
└────────────────────────────────────────┘
```

---

## Criterios de Aceptación

- [ ] Seeds JSON creados y validados
- [ ] Script SQL de carga de seeds funcional
- [ ] Flag `VITE_SUPABASE_ENABLED` implementado
- [ ] Cleanup de localStorage solo tras 7 días
- [ ] Pantalla de bienvenida v2.0 implementada

---

## Referencias

- [QA_AUDIT_ARCHITECTURE_NORMALIZATION.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/04_DEV_ORCHESTRATION/QA_AUDIT_ARCHITECTURE_NORMALIZATION.md) - Mitigación R-06
- [architecture-supabase.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/02_ARCHITECTURE/architecture-supabase.md) - Migración de Stores
