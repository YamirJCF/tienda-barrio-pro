# Original User Request

## 2026-07-17T02:52:51Z

Implementación de dos correcciones críticas en la app **Tienda Barrio Pro** (Vue 3 + Supabase): (1) reconciliación del libro mayor de clientes para que el historial de compras y abonos sea visible en la UI, y (2) habilitación de la funcionalidad de edición de clientes que estaba especificada en el FRD pero nunca fue implementada en pantalla.

Working directory: `c:\Users\Windows 11\OneDrive\Desktop\prueba`

Integrity mode: development

---

## Requirements

### R1. Migración de Base de Datos — Reconciliación `client_transactions` → Vista de `client_ledger`

Crear el archivo `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql` que ejecute, dentro de una única transacción `BEGIN/COMMIT`, los siguientes pasos en orden:

1. **Backfill**: Insertar en `public.client_ledger` todos los registros de `public.client_transactions` que no tengan ya un correspondiente en `client_ledger` (comparar por `client_id`, `amount` y `created_at` con ventana de ±60 segundos). Mapear `transaction_type = 'pago'` → `'abono'` y `'compra'` → `'venta_fiado'`. El `amount` para abonos debe ser negativo.
2. **Eliminar tabla**: `DROP TABLE IF EXISTS public.client_transactions CASCADE;`
3. **Crear vista**: Crear `public.client_transactions` como `VIEW` con `WITH (security_invoker = true)` que seleccione desde `public.client_ledger`, mapeando:
   - `transaction_type`: `'venta_fiado'` → `'compra'`, `'abono'`/`'anulacion_fiado'` → `'pago'`
   - `amount`: `ABS(cl.amount)`
   - `description`: construida con CASE (ej: 'Compra Ticket #X' para ventas, 'Abono efectivo' para abonos, 'Anulación de fiado' para anulaciones)
   - `sale_id`: `cl.reference_id`
4. **Permisos**: `GRANT SELECT ON public.client_transactions TO anon, authenticated, service_role;`
5. **Recrear RPC `registrar_abono`**: `CREATE OR REPLACE FUNCTION public.registrar_abono(p_client_id uuid, p_amount numeric)` que ahora inserte en `public.client_ledger` (con `amount = -p_amount`) en lugar de en `public.client_transactions`. Debe mantener toda la lógica existente de validación de balance negativo, cliente no encontrado, IDOR check, y actualización del balance del cliente.

### R2. Corrección de `clean_database.sql`

Modificar `supabase/scripts/clean_database.sql`:
- Remover `public.client_transactions` de la lista del `TRUNCATE TABLE`.
- Agregar `public.client_ledger` a la lista del `TRUNCATE TABLE`.

### R3. Frontend — Eliminar escrituras directas duplicadas en `clientRepository.ts`

Modificar `frontend/src/data/repositories/clientRepository.ts`:
- El método `updateDebt(id, amount)`: si `isSupabaseConfigured()` es verdadero, debe retornar `true` sin ejecutar ninguna escritura a la base de datos (delegarlo al backend).
- El método `addTransaction(...)`: igual que `updateDebt`, retornar `true` como no-op cuando Supabase está activo.
- El método `updatePendingTransactionSaleId(...)`: retornar `true` como no-op siempre (la reconciliación ya la hace la vista).
- El comportamiento offline (fallback a localStorage/IndexedDB) se mantiene sin cambios.

### R4. Frontend — `clients.ts` Pinia Store: Redirigir `registerPayment` al RPC

Modificar `frontend/src/stores/clients.ts`:
- En la acción `registerPayment(clientId, amount, description)`:
  - Si `isSupabaseConfigured()` is verdadero, invocar `supabase.rpc('registrar_abono', { p_client_id: clientId, p_amount: amount.toNumber() })` en lugar de llamar a `clientRepository.updateDebt` y `clientRepository.addTransaction`.
  - Si el RPC retorna `success: true`, actualizar el estado de Pinia localmente (restar `amount` del balance del cliente en `clients.value`) y agregar un `txStub` al listado de transacciones para la respuesta visual inmediata.
  - Si el RPC retorna error, lanzar el error con el mensaje del campo `error` de la respuesta.
  - El path offline (cuando Supabase no está configurado) permanece igual.

### R5. Frontend — Habilitar "Editar Cliente" en `ClientDetailView.vue`

Modificar `frontend/src/views/ClientDetailView.vue`:
- Importar el componente `ClientFormModal` desde `../components/ClientFormModal.vue`.
- Importar `useAuthStore` desde `../stores/auth`.
- Añadir estado reactivo: `const showEditModal = ref(false)`.
- Añadir computed `const isAdmin = computed(() => authStore.isAdmin)`.
- En el dropdown menu (`showOptionsMenu`), añadir un botón "Editar cliente" **antes** del botón "Eliminar cliente", visible sólo con `v-if="isAdmin"`. Al hacer click, establecer `showEditModal.value = true` y cerrar el menú.
- Al final del template, añadir el componente `<ClientFormModal v-model="showEditModal" :client-id="clientId" @saved="showEditModal = false" />`.

### R6. Frontend — Corregir bug de mapeo de datos en `ClientFormModal.vue`

Modificar `frontend/src/components/ClientFormModal.vue`:
- En el bloque `save()`, dentro del branch `isEdit`, cambiar la clave `cedula: data.cc` por `cc: data.cc` en el objeto `updateData` que se pasa a `clientsStore.updateClient`.

---

## Acceptance Criteria

### Base de Datos
- [ ] El archivo `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql` existe y es sintácticamente válido SQL.
- [ ] Tras la migración, `public.client_transactions` existe como VIEW (no TABLE) en la base de datos.
- [ ] La vista usa `security_invoker = true`.
- [ ] `clean_database.sql` no contiene `client_transactions` y sí contiene `client_ledger` en el bloque `TRUNCATE`.
- [ ] La RPC `registrar_abono` inserta en `client_ledger` con `amount` negativo (abono).

### Frontend — Eliminación de Doble Cargo
- [ ] El método `updateDebt` en `clientRepository.ts` retorna `true` sin realizar ninguna query a Supabase cuando la conexión está activa.
- [ ] El método `addTransaction` en `clientRepository.ts` retorna `true` como no-op cuando Supabase está activo.

### Frontend — Registro de Pago via RPC
- [ ] `registerPayment` en `clients.ts` llama a `supabase.rpc('registrar_abono', ...)` cuando está en línea.
- [ ] Si el RPC retorna error, el store lo propaga como excepción con el mensaje de error del servidor.

### Frontend — Edición de Cliente
- [ ] El dropdown de opciones en `ClientDetailView.vue` muestra el botón "Editar cliente" sólo si `authStore.isAdmin` es verdadero.
- [ ] Al hacer clic en "Editar cliente", el modal `ClientFormModal` se abre con los campos pre-llenados con los datos del cliente actual.
- [ ] En `ClientFormModal.vue`, el objeto `updateData` usa la clave `cc` (no `cedula`) al llamar a `updateClient`.

### Compilación
- [ ] El frontend compila sin errores de TypeScript (`npm run build` sin errores).

## 2026-07-17T03:04:43Z

Instrucción del usuario: M3 (cambios UI — ClientDetailView.vue y ClientFormModal.vue) no tiene dependencias de M1 ni M2. Por favor, lanza un agente paralelo para ejecutar M3 al mismo tiempo que M2 en lugar de esperar a que M2 termine. Estos son cambios puramente de UI sin relación con la capa de datos.
