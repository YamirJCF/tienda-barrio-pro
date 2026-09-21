# ⚙️ ÓRDENES DE TRABAJO - ESTABILIZACIÓN

**Generado:** 2026-01-31  
**Orquestador:** Tech Lead

---

## Orden de Trabajo 0: Snapshot de Seguridad

### Estado Git
```bash
git status
git add -A
git commit -m "chore: snapshot pre-estabilizacion fase-0"
```

### Tareas Atómicas
| # | Tarea | Comando | DoD |
|---|-------|---------|-----|
| 0.1 | Verificar cambios pendientes | `git status` | Lista de cambios visible |
| 0.2 | Stage todos los archivos | `git add -A` | Sin archivos unstaged |
| 0.3 | Crear commit snapshot | `git commit -m "..."` | Commit hash generado |

### Prompt Antigravity (No aplica - Manual)

### Definición de Hecho
- [ ] Commit creado con hash visible
- [ ] `git log -1` muestra "snapshot pre-estabilizacion"

---

## Orden de Trabajo 1: Fundación Backend

### Estado Git
```bash
# No se crea rama - cambios en Supabase son externos
```

### Tareas Atómicas
| # | Tarea | Comando/Acción | DoD |
|---|-------|----------------|-----|
| 1.1 | Leer schema-v2.sql | Abrir `02_ARCHITECTURE/supabase-schema-v2.sql` | Contenido visible |
| 1.2 | Abrir SQL Editor | Dashboard → SQL Editor | Editor abierto |
| 1.3 | Pegar y ejecutar SQL | Ctrl+V → Run | Sin errores |
| 1.4 | Verificar tablas | Query `pg_tables` | ≥10 filas |

### Prompt Antigravity
```markdown
## Prompt: Verificar Tablas Supabase

### Contexto
Proyecto: ihtjocmhzuliwwvdzfnz
Schema aplicado: 02_ARCHITECTURE/supabase-schema-v2.sql

### Objetivo
Ejecutar query de verificación y reportar tablas creadas

### Restricciones
- NO modificar schema
- Solo verificar existencia

### DoD
Lista de tablas en public schema con count ≥10
```

### SQL de Verificación
```sql
SELECT tablename, 
       (SELECT COUNT(*) FROM pg_policies p 
        WHERE p.tablename = t.tablename AND p.schemaname = 'public') as policies
FROM pg_tables t 
WHERE schemaname = 'public' 
ORDER BY tablename;
```

### Criterio de Éxito
- [ ] Query retorna stores, employees, products, sales, clients, etc.
- [ ] Cada tabla tiene ≥1 política RLS

---

## Orden de Trabajo 2: Corrección Frontend

### Estado Git
```bash
git checkout -b fix/cash-control-storeid
```

### Tareas Atómicas
| # | Tarea | Archivo | DoD |
|---|-------|---------|-----|
| 2.1 | Abrir vista | `src/views/CashControlView.vue` | Archivo abierto |
| 2.2 | Localizar línea 96-99 | Buscar `handlePinSuccess` | Función visible |
| 2.3 | Agregar validación storeId | Insertar 5 líneas | Código insertado |
| 2.4 | Actualizar llamada openRegister | Agregar storeId param | Firma correcta |
| 2.5 | Guardar archivo | Ctrl+S | Sin errores syntax |

### Prompt Antigravity
```markdown
## Prompt: Corregir CashControlView con storeId

### Contexto
Archivo: src/views/CashControlView.vue
Línea: 96-115 (función handlePinSuccess)

El método openRegister ahora requiere storeId como segundo parámetro:
`openRegister(employeeId, storeId, amount, notes)`

El authStore expone: authStore.currentStore?.id

### Objetivo
Modificar handlePinSuccess para:
1. Obtener storeId de authStore.currentStore
2. Validar que storeId exista antes de continuar
3. Mostrar error si no existe storeId
4. Pasar storeId a openRegister

### Restricciones
- NO cambiar la lógica del PIN
- NO modificar closeRegister
- Usar showError() para errores de usuario

### Código Esperado
```typescript
const handlePinSuccess = async () => {
    showPinModal.value = false;
    
    await executeAction(async () => {
        if (pendingAction.value === 'open') {
            // ===== VALIDACIÓN STOREID =====
            const storeId = authStore.currentStore?.id;
            if (!storeId) {
                showError('No hay tienda asociada. Cierra sesión e ingresa de nuevo.');
                return;
            }
            
            if (authStore.currentUser?.id) {
                await cashRegisterStore.openRegister(
                    authStore.currentUser.id,
                    storeId,  // ← NUEVO PARÁMETRO
                    new Decimal(amount.value),
                    notes.value
                );
            } else {
                throw new Error('Usuario no autenticado');
            }
            showSuccess('Caja abierta correctamente');
            router.push('/');
        } else {
            // Closing - sin cambios
            await cashRegisterStore.closeRegister(new Decimal(amount.value), notes.value);
            showSuccess('Turno cerrado. Reporte generado.');
            router.push('/');
        }
    }, {
        checkConnectivity: false,
        errorMessage: 'Error en la operación de caja'
    });
};
```

### DoD
- [ ] storeId se obtiene de authStore
- [ ] Validación existe antes de openRegister
- [ ] openRegister recibe 4 parámetros
```

### Comandos Post-Edición
```bash
# Verificar sintaxis
npx vue-tsc --noEmit src/views/CashControlView.vue

# Si pasa, commit
git add src/views/CashControlView.vue
git commit -m "fix(cash): add storeId validation to openRegister"
```

---

## Orden de Trabajo 3: Compilación TypeScript

### Estado Git
```bash
# Continuar en rama fix/cash-control-storeid
```

### Tareas Atómicas
| # | Tarea | Comando | DoD |
|---|-------|---------|-----|
| 3.1 | Primera compilación | `npx tsc --noEmit` | Lista de errores |
| 3.2 | Filtrar errores prod | Excluir `__tests__/` | Solo errores prod |
| 3.3 | Corregir error #1 | Editar archivo | 1 error menos |
| 3.4 | Iterar hasta 0 errores | Repetir 3.1-3.3 | 0 errores |

### Prompt Antigravity
```markdown
## Prompt: Corregir Errores TypeScript

### Contexto
Ejecutar: npx tsc --noEmit --skipLibCheck
Ignorar: archivos en __tests__/

### Objetivo
Corregir TODOS los errores de TypeScript en código de producción.

### Estrategia de Corrección
1. storeId faltante → Agregar desde authStore o como parámetro
2. Tipo incompatible → Ajustar interface o cast
3. Propiedad no existe → Agregar a interface

### Restricciones
- NO eliminar código funcional
- NO cambiar lógica de negocio
- Mantener tipos estrictos (no usar `any`)

### DoD
`npx tsc --noEmit` retorna 0 errores en código prod
```

### Comando de Verificación
```bash
# PowerShell - contar errores excluyendo tests
npx tsc --noEmit --skipLibCheck 2>&1 | Select-String -NotMatch "__tests__" | Select-String "error TS" | Measure-Object
# Debe retornar Count: 0
```

---

## Orden de Trabajo 4: Suite de Tests

### Estado Git
```bash
# Merge a main antes de tests
git checkout main
git merge fix/cash-control-storeid -m "merge: fix cash control storeid"
```

### Tareas Atómicas
| # | Tarea | Comando | DoD |
|---|-------|---------|-----|
| 4.1 | Ejecutar test crítico | `npx vitest run src/__tests__/stores/cashRegister.spec.ts` | 18/18 |
| 4.2 | Ejecutar todos tests | `npx vitest run` | Sin crasheos |

### Prompt Antigravity
```markdown
## Prompt: Ejecutar y Validar Tests

### Contexto
Suite principal: src/__tests__/stores/cashRegister.spec.ts
Cobertura: Validación storeId, integración repositorio

### Objetivo
Confirmar que todos los tests del puente Store-Repositorio pasan.

### DoD
- 18/18 tests de cashRegister pasan
- Sin errores de runtime en otros tests
```

### Comando
```bash
npx vitest run src/__tests__/stores/cashRegister.spec.ts
# Esperar: ✓ 18 tests passed
```

---

## Orden de Trabajo 5: Build Producción

### Estado Git
```bash
# En main después del merge
```

### Tareas Atómicas
| # | Tarea | Comando | DoD |
|---|-------|---------|-----|
| 5.1 | Limpiar dist | `rm -rf dist` | Carpeta eliminada |
| 5.2 | Ejecutar build | `npm run build` | Sin errores |
| 5.3 | Verificar output | `ls dist` | Archivos generados |

### Prompt Antigravity
```markdown
## Prompt: Build de Producción

### Objetivo
Generar bundle de producción sin errores.

### Comando
npm run build

### DoD
- Build completa sin errores
- Carpeta dist/ contiene index.html y assets/
```

### Comando
```bash
npm run build
# Esperar: ✓ built in XXs
```

---

## Orden de Trabajo 6: Verificación RLS

### Estado Git (No aplica - Supabase)

### Tareas Atómicas
| # | Tarea | Acción | DoD |
|---|-------|--------|-----|
| 6.1 | Abrir Dashboard | supabase.com/dashboard | Dashboard visible |
| 6.2 | Ir a Authentication | Menú → Policies | Lista de políticas |
| 6.3 | Verificar cada tabla | Click en tabla | Políticas visibles |

### Prompt Antigravity
```markdown
## Prompt: Verificar Políticas RLS

### Contexto
Proyecto Supabase: ihtjocmhzuliwwvdzfnz

### Objetivo
Ejecutar query y confirmar que todas las tablas tienen RLS.

### Query
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'public';

### DoD
Cada tabla crítica tiene al menos 1 política:
- stores
- employees  
- products
- sales
- clients
```

### SQL de Verificación
```sql
SELECT 
    t.tablename,
    COALESCE(p.policy_count, 0) as policies,
    CASE WHEN COALESCE(p.policy_count, 0) > 0 THEN '✅' ELSE '❌' END as status
FROM pg_tables t
LEFT JOIN (
    SELECT tablename, COUNT(*) as policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
    GROUP BY tablename
) p ON t.tablename = p.tablename
WHERE t.schemaname = 'public'
ORDER BY t.tablename;
```

---

## Orden de Trabajo 7: Cierre

### Estado Git
```bash
git add -A
git commit -m "fix: estabilizacion completa - DB + TS + RLS"
git tag v1.0.0-stable
git push origin main --tags
```

### Tareas Atómicas
| # | Tarea | Comando | DoD |
|---|-------|---------|-----|
| 7.1 | Stage cambios | `git add -A` | Todo staged |
| 7.2 | Commit final | `git commit -m "..."` | Commit creado |
| 7.3 | Crear tag | `git tag v1.0.0-stable` | Tag creado |
| 7.4 | Push | `git push origin main --tags` | Remoto actualizado |
| 7.5 | Actualizar MAPA_RIESGOS | Editar puntaje | 85/100+ |

### Prompt Antigravity
```markdown
## Prompt: Actualizar MAPA_RIESGOS

### Archivo
MAPA_RIESGOS_SISTEMA.md

### Objetivo
Actualizar puntaje global de 45/100 a 85/100

### Cambios
- Puntaje: 85/100
- Todos los módulos: 🟢 PROTEGIDO
- Fecha: 2026-01-31

### DoD
Archivo guardado con nuevo puntaje
```

---

## Resumen de Ejecución

| Fase | Orden de Trabajo | Tiempo | Comando de Inicio |
|------|------------------|--------|-------------------|
| 0 | Snapshot | 2 min | `git add -A && git commit` |
| 1 | Backend | 10 min | Dashboard SQL Editor |
| 2 | Frontend | 15 min | `git checkout -b fix/...` |
| 3 | TypeScript | 30 min | `npx tsc --noEmit` |
| 4 | Tests | 10 min | `npx vitest run` |
| 5 | Build | 5 min | `npm run build` |
| 6 | RLS | 10 min | Dashboard Policies |
| 7 | Cierre | 5 min | `git commit && git tag` |

**Total: ~1h 15min**
