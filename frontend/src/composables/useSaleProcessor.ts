/**
 * useSaleProcessor — Sale Processing Composable
 * 
 * Extracted from POSView.vue to maximize maintainability and SRP.
 * Handles:
 *  - Building sale items from cart (DRY helper)
 *  - Normal sale processing (completeSale)
 *  - Force Sale processing (handleForceSale)
 *  - Force Sale detection & recovery flow
 * 
 * @module composables/useSaleProcessor
 */

import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { useCartStore } from '../stores/cart';
import { useSalesStore } from '../stores/sales';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useAuthStore } from '../stores/auth';
import { useInventoryStore } from '../stores/inventory';
import { useNotificationsStore } from '../stores/notificationsStore';
import { useNotifications } from './useNotifications';
import { useAsyncAction } from './useAsyncAction';
import type { PaymentTransaction } from '../types';

// ============================================
// PUBLIC TYPES
// ============================================

/** Info about a forced item for the ForceSaleModal */
export interface ForceSaleItemInfo {
    productId: string;
    name: string;
    requested: number;
    available: number;
    deficit: number;
    unit: string;
}

/** Pending sale data cached for Force Sale retry */
interface PendingSaleData {
    payments: PaymentTransaction[];
    totalPaid: Decimal;
    clientId?: string;
}

// ============================================
// CONFIG
// ============================================

interface UseSaleProcessorConfig {
    /** Callback to get current ticket string for notifications */
    getTicketLabel: () => string;
    /** Callback to clear POS input after successful sale */
    clearInput: () => void;
    /** Ref to close checkout modal */
    closeCheckout: () => void;
}

export function useSaleProcessor(config: UseSaleProcessorConfig) {
    // === Store Dependencies ===
    const cartStore = useCartStore();
    const salesStore = useSalesStore();
    const cashRegisterStore = useCashRegisterStore();
    const authStore = useAuthStore();
    const inventoryStore = useInventoryStore();
    const notifStore = useNotificationsStore();
    const { showSaleSuccess } = useNotifications();
    const { execute: executeSale, isLoading: isProcessing } = useAsyncAction();

    // === Reactive State ===
    const isSuccess = ref(false);
    const showForceSaleModal = ref(false);
    const forceSaleItems = ref<ForceSaleItemInfo[]>([]);
    const pendingSaleData = ref<PendingSaleData | null>(null);

    // ============================================
    // DRY HELPER: Build sale items from cart
    // ============================================
    const buildSaleItems = () => {
        return cartStore.items.map((item) => {
            const qty =
                typeof item.quantity === 'object' && 'toNumber' in item.quantity
                    ? (item.quantity as Decimal).toNumber()
                    : Number(item.quantity);

            return {
                productId: item.id,
                productName: item.name,
                quantity: qty,
                price: item.price,
                subtotal: item.subtotal || item.price.times(item.quantity),
            };
        });
    };

    // ============================================
    // DRY HELPER: Derive payment method from transactions
    // ============================================
    const derivePrimaryMethod = (payments: PaymentTransaction[]): string => {
        const uniqueMethods = new Set(payments.map(p => p.method));
        return uniqueMethods.size > 1 ? 'mixed' : payments[0].method;
    };

    // ============================================
    // HELPER: Build force sale item list for modal
    // ============================================
    const buildForceSaleItems = (): ForceSaleItemInfo[] => {
        return cartStore.items
            .filter(item => cartStore.isForcedItem(item.id))
            .map(item => {
                const product = inventoryStore.products.find(p => p.id === item.id);
                const available = product?.stock instanceof Decimal
                    ? product.stock.toNumber()
                    : Number(product?.stock || 0);
                const requested = item.quantity instanceof Decimal
                    ? item.quantity.toNumber()
                    : Number(item.quantity);
                return {
                    productId: item.id,
                    name: item.name,
                    requested,
                    available,
                    deficit: Math.max(0, requested - available),
                    unit: item.measurementUnit || 'un',
                };
            });
    };

    // ============================================
    // MAIN: completeSale
    // ============================================
    const completeSale = async (
        payments: PaymentTransaction[],
        totalPaid: Decimal,
        clientId?: string
    ) => {
        // OPTIMISTIC UI: Close modal immediately to show feedback on main screen
        config.closeCheckout();

        const currentTicket = config.getTicketLabel();
        const primaryMethod = derivePrimaryMethod(payments);

        // Calculate total cash received for change calculation
        const cashPayment = payments.find(p => p.method === 'cash');
        const amountReceived = cashPayment ? cashPayment.amount : undefined;

        const success = await executeSale(async () => {
            // SAFEGUARD: Check Register Status (JIT)
            if (!cashRegisterStore.isOpen) {
                throw new Error('La caja está cerrada. No se puede procesar la venta.');
            }

            const saleItems = buildSaleItems();

            // Register Sale Record (Source of Truth for Inventory & Business Logic)
            await salesStore.addSale({
                items: saleItems,
                total: cartStore.total,
                roundingDifference: new Decimal(0),
                effectiveTotal: cartStore.total,
                paymentMethod: primaryMethod,
                payments: payments,
                amountReceived,
                change: undefined,
                clientId: clientId,
                employeeId: authStore.currentUser?.employeeId || authStore.currentUser?.id,
            });

            return true;
        }, {
            successMessage: undefined,  // Disable default toast, we use morphic button
            checkConnectivity: false,   // Offline-first
        });

        if (success) {
            // MORPHIC FEEDBACK: Show Success State
            isSuccess.value = true;
            setTimeout(() => {
                isSuccess.value = false;
                cartStore.clearCart();
                config.clearInput();
                showSaleSuccess(currentTicket);
            }, 1500);
        } else {
            // ============================================
            // FORCE SALE DETECTION (Capa 3 Recovery)
            // ============================================
            if (cartStore.hasForcedItems && authStore.isAdmin && navigator.onLine) {
                forceSaleItems.value = buildForceSaleItems();
                pendingSaleData.value = { payments, totalPaid, clientId };
                showForceSaleModal.value = true;
                return; // Don't clear cart — user decides via ForceSaleModal
            }
            // If not Force Sale applicable, error was already shown by useAsyncAction
        }
    };

    // ============================================
    // FORCE SALE: handleForceSale
    // ============================================
    const handleForceSale = async (justification: string) => {
        if (!pendingSaleData.value) return;

        const { payments, clientId } = pendingSaleData.value;
        const currentTicket = config.getTicketLabel();
        let saleId: string | null = null;

        const success = await executeSale(async () => {
            if (!cashRegisterStore.isOpen) {
                throw new Error('La caja está cerrada. No se puede procesar la venta.');
            }

            const saleItems = buildSaleItems();

            // Call the Force Sale repository method
            const result = await salesStore.forceSale({
                items: saleItems,
                total: cartStore.total,
                paymentMethod: derivePrimaryMethod(payments),
                clientId,
            }, authStore.currentStore!.id, justification);

            if (!result.success) {
                throw new Error(result.error || 'Force sale failed');
            }

            // Update cash register for cash payments
            const cashPayment = payments.find(p => p.method === 'cash');
            if (cashPayment) {
                cashRegisterStore.addIncome(cashPayment.amount, `Venta Forzada ${currentTicket}`, result.id);
            }

            // Update inventory locally (Fase 5b fix: forceSale wasn't updating local stock)
            saleItems.forEach(item => {
                inventoryStore.adjustStockLocal(item.productId, new Decimal(item.quantity).neg());
            });

            saleId = result.id ?? null;
            return true;
        }, {
            checkConnectivity: false,
            errorMessage: 'Error al procesar la venta forzada.',
            showSuccessToast: false,
        });

        if (success) {
            cartStore.clearCart();
            config.closeCheckout();
            showForceSaleModal.value = false;
            pendingSaleData.value = null;
            forceSaleItems.value = [];
            showSaleSuccess(currentTicket);

            // NOTIFICATION INTEGRATION (Level 2: Force Sale Audit)
            if (saleId) {
                notifStore.addNotification({
                    type: 'finance',
                    audience: 'admin',
                    title: 'Venta Forzada',
                    message: `Venta forzada autorizada. Justificación: ${justification}`,
                    icon: 'alert-triangle',
                    isRead: false,
                    metadata: { saleId: saleId },
                });
            }
        }
    };

    // ============================================
    // FORCE SALE: Cancel
    // ============================================
    const handleForceSaleCancel = () => {
        showForceSaleModal.value = false;
        pendingSaleData.value = null;
        forceSaleItems.value = [];
    };

    return {
        // State
        isSuccess,
        isProcessing,
        showForceSaleModal,
        forceSaleItems,
        // Actions
        completeSale,
        handleForceSale,
        handleForceSaleCancel,
    };
}
