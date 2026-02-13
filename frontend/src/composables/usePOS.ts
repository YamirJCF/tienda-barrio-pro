import { ref, type Ref } from 'vue';
import { useCartStore } from '../stores/cart';
import { useInventoryStore } from '../stores/inventory';
import type { Product } from '../types';
import { useNotifications } from './useNotifications';
import { logger } from '../utils/logger';
import type { AddItemResult } from '../stores/cart';

interface UsePOSConfig {
    pluInput: Ref<string>;
    clearPluInput: () => void;
    openWeightCalculator: (product: Product) => void;
}

export function usePOS({ pluInput, clearPluInput, openWeightCalculator }: UsePOSConfig) {
    const cartStore = useCartStore();
    const inventoryStore = useInventoryStore();
    const { showSuccess, showError, showWarning } = useNotifications();

    // State
    const pendingQuantity = ref(1);
    const pendingProduct = ref<Product | null>(null);
    const isQuantityMode = ref(false);
    const isProductMode = ref(false);

    // Reset all modes
    const resetModes = () => {
        logger.log('[Reset] Clearing all modes');
        pendingQuantity.value = 1;
        pendingProduct.value = null;
        isQuantityMode.value = false;
        isProductMode.value = false;
    };

    // ============================================
    // DRY HELPER: Add item + handle feedback
    // Replaces 3 duplicated blocks of ~12 lines each
    // ============================================
    const addWithFeedback = (product: Product, quantity: number): boolean => {
        const result: AddItemResult = cartStore.addItem({ ...product, quantity });
        if (!result.success) {
            showError(result.stockError || `No se pudo agregar ${product.name}`);
            return false;
        }
        if (result.warning) {
            showWarning(result.warning);
        } else {
            showSuccess(`${quantity}x ${product.name} agregado`);
        }
        return true;
    };

    // Handle CANT. × button
    const handleQuantity = () => {
        logger.log('[CANT.×] Pressed. pluInput:', pluInput.value);

        if (!pluInput.value) {
            logger.log('[CANT.×] No input');
            return;
        }

        // CASE 1: Product already selected (Waiting for Quantity in input)
        if (isProductMode.value && pendingProduct.value) {
            const rawQty = parseInt(pluInput.value);
            const qty = isNaN(rawQty) || rawQty <= 0 ? 1 : rawQty;

            addWithFeedback(pendingProduct.value, qty);
            clearPluInput();
            resetModes();
            return;
        }

        // NEW CASE: Check if input is a PLU
        const potentialProduct = inventoryStore.getProductByPLU(pluInput.value);
        if (potentialProduct) {
            pendingProduct.value = potentialProduct;
            isProductMode.value = true;
            logger.log('[CANT.×] Entered Product Mode for:', potentialProduct.name);
            clearPluInput();
            return;
        }

        // CASE 2: No product selected yet (Pre-setting quantity for NEXT product)
        const rawQty = parseInt(pluInput.value);
        if (!isNaN(rawQty) && rawQty > 0) {
            pendingQuantity.value = rawQty;
            isQuantityMode.value = true;
            logger.log('[CANT.×] Set pendingQuantity:', rawQty);
            clearPluInput();
        } else {
            showError('Cantidad inválida');
            clearPluInput();
        }
    };

    // Add product by PLU (The main + button)
    const addProductByPLU = () => {
        logger.log(
            '[AGREGAR] pluInput:',
            pluInput.value,
            '| isProductMode:',
            isProductMode.value,
            '| pendingQuantity:',
            pendingQuantity.value,
        );

        // Flow B: Product already selected, input is quantity
        if (isProductMode.value && pendingProduct.value) {
            const rawQty = pluInput.value ? parseInt(pluInput.value) : 1;
            const quantity = isNaN(rawQty) || rawQty <= 0 ? 1 : rawQty;

            if (quantity > 0) {
                if (pendingProduct.value.isWeighable) {
                    logger.log('[AGREGAR] Flow B: Product is weighable - opening calculator');
                    openWeightCalculator(pendingProduct.value);
                    clearPluInput();
                    resetModes();
                    return;
                }

                addWithFeedback(pendingProduct.value, quantity);
                clearPluInput();
                resetModes();
                return;
            }
        }

        // Flow A: Normal flow - input is PLU
        if (!pluInput.value) {
            logger.log('[AGREGAR] No PLU entered');
            return;
        }

        const product = inventoryStore.getProductByPLU(pluInput.value);

        if (product) {
            if (product.isWeighable) {
                openWeightCalculator(product);
                clearPluInput();
                resetModes();
                return;
            }

            const quantity = pendingQuantity.value;
            addWithFeedback(product, quantity);
            clearPluInput();
            resetModes();
        } else {
            showError(`Producto no encontrado: ${pluInput.value}`);
            clearPluInput();
            resetModes();
        }
    };

    return {
        pendingQuantity,
        pendingProduct,
        isQuantityMode,
        isProductMode,
        resetModes,
        handleQuantity,
        addProductByPLU
    };
}

