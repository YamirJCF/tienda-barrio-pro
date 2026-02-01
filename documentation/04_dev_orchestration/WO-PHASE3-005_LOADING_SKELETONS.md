## Orden de Trabajo - Estados de Carga (UX-03)

### Contexto
El reporte de auditoría (UX-03) indica que las listas de Productos y Clientes no muestran feedback visual mientras cargan datos, pareciendo vacías.
**Objetivo**: Implementar un componente `Skeleton` reutilizable y aplicarlo en las vistas principales.

### Estado Git Actual
- Rama a crear: `feat/ux-03-loading-skeletons`
- Comando: `git checkout -b feat/ux-03-loading-skeletons`

---

### Plan de Acción Atómico

#### Tarea 1: Componente Base (UI)
**Archivo**: `src/components/ui/Skeleton.vue`
- Crear un componente simple que acepte `width`, `height`, y `borderRadius`.
- Debe tener una animación de pulso (`animate-pulse`) y usar colores neutros (`bg-slate-200` / `dark:bg-slate-700`).

#### Tarea 2: Implementación en Inventario
**Archivo**: `src/views/InventoryView.vue`
- Usar `inventoryStore.isLoading` (o agregar la propiedad si falta).
- Reemplazar la lista vacía temporalmente con 5-6 items de Skeleton que imiten la estructura de la tarjeta de producto (Nombre, Precio, Stock).

#### Tarea 3: Implementación en Clientes
**Archivo**: `src/views/ClientListView.vue`
- Usar `clientsStore.isLoading` (verificar existencia en store).
- Mostrar Skeletons imitando la tarjeta de cliente (Avatar, Nombre, Cédula, Balance) cuando esté cargando.

### Bloque de Prompt para Antigravity

```markdown
## Prompt para UX-03 (Loading Skeletons)

### Contexto
- Nuevo Componente: `src/components/ui/Skeleton.vue`
- Vistas Objetivo: `InventoryView.vue`, `ClientListView.vue`

### Requerimientos
1. **Skeleton.vue**: Componente funcional con props de estilo.
2. **InventoryView**:
   - Importar Skeleton.
   - Si `inventoryStore.isLoading` es true, mostrar lista de skeletons en lugar de "No hay productos".
3. **ClientListView**:
   - Igual que Inventario, usando `clientsStore.isLoading`.
```

### Comandos de Consola
```bash
git checkout -b feat/ux-03-loading-skeletons
```
