/**
 * Cash Register Store - Bridge Validation Tests
 * 
 * Automated tests to ensure the Store-Repository bridge never breaks.
 * These tests verify:
 * 1. CashSession interface requires storeId
 * 2. openRegister validates storeId before persistence
 * 3. openRegister calls cashRepository.registerEvent
 * 4. closeRegister calls cashRepository.registerEvent
 * 5. ValidationError is thrown when storeId is missing
 * 
 * @module __tests__/stores/cashRegister.spec.ts
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useCashRegisterStore } from '../../stores/cashRegister';
import type { CashSession } from '../../types';

// Mock the cashRepository module
vi.mock('../../data/repositories/cashRepository', () => ({
    cashRepository: {
        registerEvent: vi.fn().mockResolvedValue({ success: true, data: { session_id: 'test-session-id' } }),
        getStoreStatus: vi.fn().mockResolvedValue({ isOpen: false, openingAmount: 0 }),
        getSessionTransactions: vi.fn().mockResolvedValue([]),
        getOwnShiftMovements: vi.fn().mockResolvedValue({ data: [], count: 0, has_open_shift: false, shift_id: null, shift_opened_at: null }),
        getSessionOpexExpenses: vi.fn().mockResolvedValue({ success: true, session_id: 'test-session-id', session_status: 'open', total_opex_expenses: 0, count: 0, data: [] }),
        addMovement: vi.fn().mockResolvedValue({ success: true })
    }
}));

vi.mock('../../data/supabaseClient', async (importOriginal) => ({
    ...(await importOriginal<typeof import('../../data/supabaseClient')>()),
    isSupabaseConfigured: () => true,
}));

describe('CashRegister Store - Bridge Validation', () => {
    let store: ReturnType<typeof useCashRegisterStore>;

    beforeEach(() => {
        setActivePinia(createPinia());
        store = useCashRegisterStore();
        vi.clearAllMocks();
    });

    afterEach(() => {
        vi.restoreAllMocks();
    });

    // =========================================================
    // 1. INTERFACE VALIDATION - storeId is required
    // =========================================================
    describe('Interface Validation - CashSession.storeId', () => {
        it('should have storeId as a required field in CashSession type', () => {
            // This is a compile-time check - if CashSession has storeId as optional,
            // creating a session without it should fail TypeScript compilation.
            // This test documents the requirement.
            const mockSession: CashSession = {
                id: 'test-id',
                storeId: 'test-store-id', // This line would fail TS if storeId was not defined
                employeeId: 'emp-1',
                status: 'open',
                openingTime: new Date().toISOString(),
                openingBalance: 1000 as any,
                transactions: []
            };

            expect(mockSession.storeId).toBe('test-store-id');
            expect(mockSession).toHaveProperty('storeId');
        });
    });

    // =========================================================
    // 2. VALIDATION CHECKPOINT - storeId is validated
    // =========================================================
    describe('Validation Checkpoint - storeId validation', () => {
        it('should throw ValidationError when storeId is empty string', async () => {
            const employeeId = 'emp-123';
            const invalidStoreId = '';
            const amount = 1000;

            await expect(
                store.openRegister(employeeId, invalidStoreId, amount)
            ).rejects.toThrow('Cannot open register without valid storeId');
        });

        it('should throw ValidationError when storeId is whitespace only', async () => {
            const employeeId = 'emp-123';
            const invalidStoreId = '   ';
            const amount = 1000;

            await expect(
                store.openRegister(employeeId, invalidStoreId, amount)
            ).rejects.toThrow('Cannot open register without valid storeId');
        });

        it('should log RLSViolationError to console when storeId is invalid', async () => {
            const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => { });

            try {
                await store.openRegister('emp-123', '', 1000);
            } catch (e) {
                // Expected to throw
            }

            expect(consoleSpy).toHaveBeenCalledWith(
                '🚫 [CashRegisterStore] RLSViolationError:',
                expect.stringContaining('storeId')
            );

            consoleSpy.mockRestore();
        });

        it('should NOT create a session when storeId validation fails', async () => {
            try {
                await store.openRegister('emp-123', '', 1000);
            } catch (e) {
                // Expected
            }

            expect(store.currentSession).toBeNull();
            expect(store.isOpen).toBe(false);
        });
    });

    // =========================================================
    // 3. REPOSITORY INTEGRATION - openRegister calls repository
    // =========================================================
    describe('Repository Integration - openRegister', () => {
        it('should call cashRepository.registerEvent when opening register', async () => {
            const { cashRepository } = await import('../../data/repositories/cashRepository');

            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            await store.openRegister('emp-123', validStoreId, 1000);

            expect(cashRepository.registerEvent).toHaveBeenCalledTimes(1);
        });

        it('should pass correct payload to registerEvent with snake_case store_id', async () => {
            const { cashRepository } = await import('../../data/repositories/cashRepository');

            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            const employeeId = 'emp-123';
            const amount = 1000;

            await store.openRegister(employeeId, validStoreId, amount);

            expect(cashRepository.registerEvent).toHaveBeenCalledWith(
                expect.objectContaining({
                    store_id: validStoreId, // Must be snake_case
                    type: 'open',
                    amount_declared: amount,
                    authorized_by_id: employeeId,
                    authorized_by_type: 'employee'
                })
            );
        });

        it('should create session with storeId after successful repository call', async () => {
            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            await store.openRegister('emp-123', validStoreId, 1000);

            expect(store.currentSession).not.toBeNull();
            expect(store.currentSession?.storeId).toBe(validStoreId);
            expect(store.isOpen).toBe(true);
        });

        it('should log success message when repository call succeeds', async () => {
            const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => { });

            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            await store.openRegister('emp-123', validStoreId, 1000);

            expect(consoleSpy).toHaveBeenCalledWith(
                '✅ [CashRegisterStore] Session ID synced from backend:',
                'test-session-id'
            );

            consoleSpy.mockRestore();
        });
    });

    // =========================================================
    // 4. REPOSITORY INTEGRATION - closeRegister calls repository
    // =========================================================
    describe('Repository Integration - closeRegister', () => {
        beforeEach(async () => {
            // Open register first
            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            await store.openRegister('emp-123', validStoreId, 1000);
            vi.clearAllMocks(); // Clear mocks from openRegister
        });

        it('should call cashRepository.registerEvent when closing register', async () => {
            const { cashRepository } = await import('../../data/repositories/cashRepository');

            await store.closeRegister(1000);

            expect(cashRepository.registerEvent).toHaveBeenCalledTimes(1);
        });

        it('should pass correct payload to registerEvent with type "close"', async () => {
            const { cashRepository } = await import('../../data/repositories/cashRepository');

            const physicalCount = 950;
            await store.closeRegister(physicalCount);

            expect(cashRepository.registerEvent).toHaveBeenCalledWith(
                expect.objectContaining({
                    store_id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
                    type: 'close',
                    amount_declared: physicalCount,
                    authorized_by_type: 'employee'
                })
            );
        });

        it('should archive session after closing', async () => {
            await store.closeRegister(1000);

            expect(store.currentSession).toBeNull();
            expect(store.isOpen).toBe(false);
            expect(store.sessionHistory.length).toBe(1);
        });
    });

    // =========================================================
    // 5. REGRESSION PREVENTION - No data island
    // =========================================================
    describe('Regression Prevention - No Data Island', () => {
        it('should require async signature for openRegister (repository call)', () => {
            // Verify that openRegister returns a Promise
            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            const result = store.openRegister('emp-123', validStoreId, 1000);

            expect(result).toBeInstanceOf(Promise);
        });

        it('should require async signature for closeRegister (repository call)', async () => {
            // Open first
            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            await store.openRegister('emp-123', validStoreId, 1000);

            // Verify closeRegister returns a Promise
            const result = store.closeRegister(1000);

            expect(result).toBeInstanceOf(Promise);
        });

        it('should include storeId in session object stored in Pinia state', async () => {
            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            await store.openRegister('emp-123', validStoreId, 1000);

            // Verify storeId is in the session
            const session = store.currentSession;
            expect(session).toHaveProperty('storeId', validStoreId);
        });

        it('method signature should require storeId as second parameter', async () => {
            // This documents the expected signature
            // openRegister(employeeId: string, storeId: string, amount: number, notes?: string)

            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

            // Call with all required parameters
            await store.openRegister('emp-123', validStoreId, 1000);

            expect(store.isOpen).toBe(true);
        });
    });

    // =========================================================
    // 6. ERROR HANDLING - Repository failures (Regla 3: Zero silent local fallback)
    // =========================================================
    describe('Error Handling - Repository failures', () => {
        it('should propagate error and NOT create local session if repository call throws', async () => {
            const { cashRepository } = await import('../../data/repositories/cashRepository');

            vi.mocked(cashRepository.registerEvent).mockRejectedValueOnce(
                new Error('Network error')
            );

            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            await expect(
                store.openRegister('emp-123', validStoreId, 1000)
            ).rejects.toThrow('Network error');

            expect(store.isOpen).toBe(false);
            expect(store.currentSession).toBeNull();
        });

        it('should propagate backend rejection (e.g. RECONCILIATION_REQUIRED / PERMISSION_DENIED) without local fallback', async () => {
            const { cashRepository } = await import('../../data/repositories/cashRepository');

            vi.mocked(cashRepository.registerEvent).mockResolvedValueOnce({
                success: false,
                error: 'RECONCILIATION_REQUIRED: Existe un turno cerrado forzosamente pendiente de reconciliación.'
            });

            const validStoreId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            await expect(
                store.openRegister('emp-123', validStoreId, 1000)
            ).rejects.toThrow('RECONCILIATION_REQUIRED');

            expect(store.isOpen).toBe(false);
            expect(store.currentSession).toBeNull();
        });
    });

    // =========================================================
    // 7. WO-OLA2-C2-001 (C2-H1 & C2-H2): Mapeo refund + throwOnError
    // =========================================================
    describe('C2-H1 & C2-H2 - Mapeo limpio y sincronización fail-closed', () => {
        it('mapea source === "refund" a movementType: "reembolso" (nunca "gasto") y distingue abono vs proveedor', async () => {
            const { cashRepository } = await import('../../data/repositories/cashRepository');
            const { useAuthStore } = await import('../../stores/auth');
            const authStore = useAuthStore();
            authStore.currentUser = {
                id: 'emp-1',
                employeeId: 'emp-1',
                name: 'Cajero',
                type: 'employee',
                storeId: 'store-1',
                permissions: { canManageInventory: false, canFiar: false, canOpenCloseCash: true, canManageRefunds: false },
            } as any;

            Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
            vi.mocked(cashRepository.getStoreStatus).mockResolvedValueOnce({
                isOpen: true,
                openingAmount: 50000,
                sessionId: 'sess-1',
                openedByName: 'Cajero',
                openedByRole: 'employee',
                lastEvent: {
                    store_id: 'store-1',
                    type: 'open',
                    amount_declared: 50000,
                    authorized_by_id: 'emp-1',
                    authorized_by_name: 'Cajero',
                    authorized_by_type: 'employee',
                    created_at: new Date().toISOString(),
                },
            });
            vi.mocked(cashRepository.getOwnShiftMovements).mockResolvedValueOnce({
                data: [
                    {
                        id: 'mov-refund',
                        source: 'refund',
                        payment_method: 'efectivo',
                        amount: 7000,
                        description: 'DEVOLUCIÓN #12',
                        category: 'reembolso',
                        created_at: new Date().toISOString(),
                        actor_name: 'Cajero',
                        actor_role: 'employee',
                    },
                    {
                        id: 'mov-abono',
                        source: 'payment',
                        payment_method: 'efectivo',
                        amount: 15000,
                        description: 'Abono cliente Rosa',
                        category: 'Abono / Ingreso',
                        created_at: new Date().toISOString(),
                        actor_name: 'Cajero',
                        actor_role: 'employee',
                    },
                    {
                        id: 'mov-prov',
                        source: 'payment',
                        payment_method: 'efectivo',
                        amount: 20000,
                        description: 'PAGO PROVEEDOR Panadería',
                        category: 'Pago a Proveedor',
                        created_at: new Date().toISOString(),
                        actor_name: 'Admin',
                        actor_role: 'owner',
                    },
                ],
                count: 3,
                has_open_shift: true,
                shift_id: 'sess-1',
                shift_opened_at: new Date().toISOString(),
            });

            const synced = await store.syncFromBackend('store-1', { throwOnError: true });
            expect(synced).toBe(true);
            expect(store.lastSyncError).toBeNull();

            const txs = store.currentSession?.transactions || [];
            const refundTx = txs.find((t) => t.id === 'mov-refund');
            const abonoTx = txs.find((t) => t.id === 'mov-abono');
            const provTx = txs.find((t) => t.id === 'mov-prov');

            expect(refundTx?.type).toBe('expense');
            expect(refundTx?.movementType).toBe('reembolso');
            expect(abonoTx?.type).toBe('income');
            expect(abonoTx?.movementType).toBe('ingreso');
            expect(provTx?.type).toBe('expense');
            expect(provTx?.movementType).toBe('pago_proveedor');
        });

        it('guarda lastSyncError y relanza error cuando throwOnError: true', async () => {
            const { cashRepository } = await import('../../data/repositories/cashRepository');
            Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
            vi.mocked(cashRepository.getStoreStatus).mockRejectedValueOnce(new Error('SERVER_DOWN'));

            await expect(store.syncFromBackend('store-1', { throwOnError: true })).rejects.toThrow('SERVER_DOWN');
            expect(store.lastSyncError).toBe('SERVER_DOWN');

            // Recuperación limpia lastSyncError
            vi.mocked(cashRepository.getStoreStatus).mockResolvedValueOnce({ isOpen: false, openingAmount: 0 });
            const res = await store.syncFromBackend('store-1', { throwOnError: true });
            expect(res).toBe(false);
            expect(store.lastSyncError).toBeNull();
        });
    });
});
