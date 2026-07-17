# Handoff Report — reviewer_ui_2

This report details the objective review and adversarial stress-testing of frontend changes made by `worker_ui_1` regarding client management (`ClientDetailView.vue`, `ClientFormModal.vue`, and unit tests).

---

## 1. Observation

### File Paths and Lines Observed:
1. **ClientDetailView.vue (`c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\views\ClientDetailView.vue`)**:
   - Lines 119-123 (`deleteClient` function):
     ```typescript
     const deleteClient = () => {
       clientsStore.deleteClient(clientId.value);
       showDeleteConfirm.value = false;
       router.push('/clients');
     };
     ```
   - Lines 125-143 (`registerPayment` function):
     ```typescript
     const registerPayment = () => {
       if (!paymentAmount.value || !client.value) return;

       const amount = new Decimal(paymentAmount.value);
       if (amount.lte(0)) return;

       // Validation: Prevent negative balance (Overpayment)
       if (amount.gt(client.value.totalDebt)) {
           alert(`El abono no puede superar la deuda actual (${formatCurrency(client.value.totalDebt)}).\nEl sistema no maneja "Saldo a Favor" por defecto.`);
           return;
       }

       // Ensure amount is valid before sending
       const finalAmount = amount.toNumber(); // Convert to number if needed by store, though store likely takes Decimal or number
       
       clientsStore.registerPayment(clientId.value, new Decimal(finalAmount), 'Abono Efectivo');
       paymentAmount.value = '';
       showPaymentModal.value = false;
     };
     ```

2. **ClientFormModal.vue (`c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\components\ClientFormModal.vue`)**:
   - Lines 81-88 (`updateClient` payload mapper):
     ```typescript
     if (isEdit.value && props.clientId) {
       const updateData = {
           name: data.name,
           cc: data.cc,
           phone: data.phone,
           creditLimit: data.creditLimit
       };
       client = await clientsStore.updateClient(props.clientId, updateData);
     }
     ```
   - Lines 90-105 (`storeId` injection for client creation):
     ```typescript
     // FIX: Inject storeId from AuthStore
     const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
     if (!storeId) {
         showError('Error: No se ha identificado la tienda activa. Recarga la página.');
         isSubmitting.value = false;
         return;
     }

     const createData = {
         name: data.name,
         cc: data.cc, 
         phone: data.phone,
         creditLimit: data.creditLimit,
         storeId: storeId
     };
     client = await clientsStore.addClient(createData);
     ```

3. **clientMapper.spec.ts (`c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\__tests__\clientMapper.spec.ts`)**:
   - `store_id` changed from `'store-1'` to `'3d474d8a-c238-4e3e-8b41-31346edb86eb'` (UUID format compliance).

4. **stores/clients.spec.ts (`c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\__tests__\stores\clients.spec.ts`)**:
   - New unit tests validating `clientsStore.updateClient` behavior.

### Tool Commands and Build/Test Results:
- **Build (`npm run build`)**: Passed successfully with Vite generating production assets (see terminal logs).
- **Test execution (`npx vitest run src/__tests__/clientMapper.spec.ts src/__tests__/stores/clients.spec.ts`)**:
  - `stores/clients.spec.ts` -> 1 passed
  - `clientMapper.spec.ts` -> 2 passed
  - Total: 3 tests passed successfully.
- **Overall project tests (`npm test`)**: 14 tests failed, 28 passed. The failures are unrelated pre-existing issues (such as `productMapper` expecting valid UUID instead of `'store-1'` and Cart store boolean mismatch).

---

## 2. Logic Chain

1. **Typos/Key Mismatches**:
   - In database schema v2 and `Client` interfaces, the unique identification field is named `cc` (CamelCase frontend) which maps to `id_number` (SnakeCase database).
   - In `ClientFormModal.vue`, the original edit payload was using `cedula` key instead of `cc` when submitting edits.
   - The worker corrected this to `cc: data.cc`, resolving the mapper mismatch and allowing updates to propagate.
2. **Missing Store ID (RLS Conformance)**:
   - Database security policies (RLS) reject records missing `store_id` (UUID format).
   - In `ClientFormModal.vue`, during client creation, `storeId` is now dynamically resolved from `authStore.currentUser?.storeId` or `authStore.currentStore?.id` and passed as part of the payload, preventing 401/403 authorization failures on client creation.
3. **Promise & UI State Violations**:
   - Both `registerPayment` and `deleteClient` in `ClientDetailView.vue` make asynchronous store calls (`clientsStore.registerPayment` and `clientsStore.deleteClient`).
   - Neither of these functions is marked `async` nor `await`s the returned Promise.
   - There are no loading states blocking the UI, no try/catch exception handlers, and no user-facing feedback (toasts) when those calls complete or fail.
   - Therefore, if a network failure or authorization rejection happens, the modal closes immediately, but the backend update fails silently, causing local vs backend drift and browser console unhandled rejections.

---

## 3. Caveats

- We assumed that general test failures (e.g. `productMapper.spec.ts`, `cart.spec.ts`) are out-of-scope pre-existing errors caused by UUID configuration changes from previous tasks, which is supported by their file locations and failure logs.
- The behavior of ledger synchronization under offline/online transitions was not stress-tested in a live network environment, only verified via code logic and mocks.

---

## 4. Conclusion

The worker successfully solved the keys mismatch and RLS compliance block in `ClientFormModal.vue`. However, `ClientDetailView.vue` contains critical violations of the **Promise and UI State Handling** guidelines on write actions. A verdict of **REQUEST_CHANGES** is issued.

---

## 5. Verification Method

To verify the changes and findings independently:
1. Run `npx vitest run src/__tests__/clientMapper.spec.ts src/__tests__/stores/clients.spec.ts` to verify the client mapper and store tests pass.
2. Run `npm run build` inside `frontend/` to confirm typescript types and assets build successfully.
3. Inspect `ClientDetailView.vue` lines 119-143 to confirm that `registerPayment` and `deleteClient` do not handle the promise and lack loading states.

---
---

# Quality Review Report

**Verdict**: REQUEST_CHANGES

## Findings

### [Major] Finding 1: Unhandled Promises & Missing UI Loading State on Payment Registration
- **What**: The payment registration function triggers an asynchronous action on the store but does not wait for it or manage its execution state.
- **Where**: `c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\views\ClientDetailView.vue:125`
- **Why**: Violates the "Promise and UI state handling" constraint. Without `await` and `isSubmitting` blocking, a user can double-click the register button, causing duplicate network requests. Additionally, failures (e.g., connection lost, RLS rules reject) fail silently in the background while the UI closes the modal and reports nothing to the user.
- **Suggestion**: Refactor `registerPayment` to be `async`, use a loading ref (e.g., `isRegisteringPayment`) to disable the confirmation button and show a spinner, wrap the store call in a `try/catch` block, and show success/error toasts.

### [Major] Finding 2: Unhandled Promises & Missing UI Loading State on Client Deletion
- **What**: The client deletion action redirects immediately to `/clients` without awaiting the asynchronous deletion promise from the store.
- **Where**: `c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\views\ClientDetailView.vue:119`
- **Why**: If the backend repository rejects the delete (e.g., database constraint error), the client will not be deleted, but the UI redirects immediately, giving a false impression of success and logging an unhandled rejection.
- **Suggestion**: Refactor `deleteClient` to be `async`, await `clientsStore.deleteClient(clientId.value)`, verify result success status, and only redirect on success (showing appropriate toast notification).

### [Minor] Finding 3: Use of browser `alert` instead of App Toast Notification
- **What**: Browser `alert(...)` is used to notify users of overpayment validation.
- **Where**: `c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\views\ClientDetailView.vue:133`
- **Why**: Native browser alert dialogs pause the JS thread and disrupt the UX. The project has a toast system (`useNotifications` / toast module).
- **Suggestion**: Use `useNotifications` and trigger `showError` or `showWarning`.

## Verified Claims

- **Client model typo corrected** → verified via code inspection of `ClientFormModal.vue` (`cedula` -> `cc`) and `types/index.ts` (exposes `cc`, no `cedula` property) → **PASS**
- **Active store ID validation and injection** → verified via code inspection of `ClientFormModal.vue` lines 90-105. It checks for a valid store UUID and aborts if empty → **PASS**
- **Store and Mapper unit tests pass** → verified by running `npx vitest` on `clientMapper.spec.ts` and `clients.spec.ts` → **PASS**
- **Frontend compiles cleanly** → verified by running `npm run build` → **PASS**

---
---

# Adversarial Challenge Report

**Overall risk assessment**: MEDIUM

## Challenges

### [High] Challenge 1: Decimal Parsing Crash
- **Assumption challenged**: Assumes that `paymentAmount.value` string will always be safely parsed into a `Decimal`.
- **Attack scenario**: If the input field gets populated with invalid character variations (like `e`, `-`, `.` with special keys in some browsers) causing `paymentAmount.value` to be an invalid decimal string representation, `new Decimal(paymentAmount.value)` will throw a `DecimalError` exception.
- **Blast radius**: The whole `registerPayment` function crashes, breaking the page context and causing visual freezes.
- **Mitigation**: Wrap the `new Decimal` conversion in a `try/catch` and validate the input before attempting parsing.

### [Medium] Challenge 2: Client Edit on Non-existent Client ID
- **Assumption challenged**: Assumes that the requested `clientId` prop always points to a valid client loaded in the store.
- **Attack scenario**: If a client is loaded via a direct URL containing a deleted or wrong UUID, `clientsStore.getClientById(clientId)` returns `undefined`.
- **Blast radius**: In `ClientFormModal.vue`, the watch handler on line 123 will not populate `formData.value`, leaving it empty or with stale data from a previous modal session, allowing users to save/create inconsistent entries.
- **Mitigation**: Handle the `undefined` case explicitly by closing the modal with an error message or resetting the form state.

### [Low] Challenge 3: Negative Credit Limit Input
- **Assumption challenged**: Assumes the user will only insert positive values for credit limits.
- **Attack scenario**: The input type is `number` but has no minimum constraint. A user could save a client with a credit limit of `-50000`.
- **Blast radius**: The available credit calculations (`creditLimit.minus(totalDebt)`) will yield negative available credits, blocking standard checkouts incorrectly.
- **Mitigation**: Add a validation step in `ClientFormModal.vue` to ensure `creditLimit` is `>= 0`.

## Stress Test Results

- **Attempting payment registration with invalid input** → causes unhandled Promise rejection and UI freeze if value is not numeric → **FAIL** (Needs mitigation)
- **Confirming client delete when server rejects** → UI redirects, giving false success, while console logs background rejection → **FAIL** (Needs mitigation)

## Unchallenged Areas

- **IndexedDB persistence capacity**: Local cache size limit was not tested under massive client record sets (> 5000 clients).
