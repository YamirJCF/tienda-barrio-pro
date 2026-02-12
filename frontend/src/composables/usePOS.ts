import { ref, type Ref } from 'vue';
import { useCartStore } from '../stores/cart';
import { useInventoryStore } from '../stores/inventory';
import type { Product } from '../types';
import { useNotifications } from './useNotifications';
import { logger } from '../utils/logger';
import { Decimal } from 'decimal.js';

interface UsePOSConfig {
    pluInput: Ref<string>;
    clearPluInput: () => void;
    openWeightCalculator: (product: Product) => void;
}

export function usePOS({ pluInput, clearPluInput, openWeightCalculator }: UsePOSConfig) {
    const cartStore = useCartStore();
    const inventoryStore = useInventoryStore();
    const { showSuccess, showError } = useNotifications();

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

    // Handle CANT. × button
    const handleQuantity = () => {
        logger.log('[CANT.×] Pressed. pluInput:', pluInput.value);

        if (!pluInput.value) {
            logger.log('[CANT.×] No input');
            return;
        }

        // CASE 1: Product already selected (Waiting for Quantity in input)
        // User workflow: [PLU] -> [CANT] -> [QUANTITY] -> [CANT]
        if (isProductMode.value && pendingProduct.value) {
            const rawQty = parseInt(pluInput.value);
            const qty = isNaN(rawQty) || rawQty <= 0 ? 1 : rawQty;

            // Stock validation delegated to cart.ts (single source of truth)
            const added = cartStore.addItem({ ...pendingProduct.value, quantity: qty });
            if (!added) {
                showError(`Stock insuficiente para ${pendingProduct.value.name}`);
                clearPluInput();
                resetModes();
                return;
            }
            showSuccess(`${qty}x ${pendingProduct.value.name} agregado`);
            clearPluInput();
            resetModes();
            return;
        }

        // NEW CASE: Check if input is a PLU (Flow: PLU -> CANT -> QUANTITY)
        // If user typed "122" (Aceite) and hit CANT, they likely want to set quantity for Aceite.
        const potentialProduct = inventoryStore.getProductByPLU(pluInput.value);
        if (potentialProduct) {
            pendingProduct.value = potentialProduct;
            isProductMode.value = true;
            logger.log('[CANT.×] Entered Product Mode for:', potentialProduct.name);
            clearPluInput();
            return;
        }

        // CASE 2: No product selected yet (Pre-setting quantity for NEXT product)
        // User typed "2" then pressed "CANT. x" -> They want next item to be added 2 times
        // Flow: [QUANTITY] -> [CANT] -> [PLU]
        const rawQty = parseInt(pluInput.value);
        if (!isNaN(rawQty) && rawQty > 0) {
            pendingQuantity.value = rawQty;
            isQuantityMode.value = true;
            logger.log('[CANT.×] Set pendingQuantity:', rawQty);
            // showSuccess(`Cantidad fijada: ${rawQty}x`); // Optional feedback
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

                // Stock validation delegated to cart.ts (single source of truth)
                const added = cartStore.addItem({ ...pendingProduct.value, quantity });
                if (!added) {
                    showError(`Stock insuficiente para ${pendingProduct.value.name}`);
                    clearPluInput();
                    resetModes();
                    return;
                }
                showSuccess(`${quantity}x ${pendingProduct.value.name} agregado`);
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

            // Stock validation delegated to cart.ts (single source of truth)
            const added = cartStore.addItem({ ...product, quantity });
            if (!added) {
                showError(`Stock insuficiente para ${product.name}`);
                clearPluInput();
                resetModes();
                return;
            }
            showSuccess(`${quantity}x ${product.name} agregado`);
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
