import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { inventorySerializer } from '../data/serializers';
import { useNotificationsStore } from './notificationsStore';

export type MeasurementUnit = 'kg' | 'lb' | 'g' | 'un';

export interface Product {
    id: number;
    name: string;
    brand?: string;
    category?: string;
    plu?: string;
    price: Decimal;           // Si isWeighable: precio por unidad de medida (PUM)
    cost?: Decimal;
    isWeighable: boolean;     // true = producto por peso, false = por unidad
    measurementUnit: MeasurementUnit; // 'kg', 'lb', 'g', 'un'
    stock: Decimal;           // Stock en decimales para soportar 0.5 lb, etc.
    minStock: number;
    notifiedLowStock?: boolean;  // Flag anti-duplicado (QA)
    createdAt: string;
    updatedAt: string;
}

export const useInventoryStore = defineStore('inventory', () => {
    const products = ref<Product[]>([]);
    const nextId = ref(1);

    // Computed
    const totalProducts = computed(() => products.value.length);

    const lowStockProducts = computed(() =>
        products.value.filter(p => p.stock.lte(p.minStock))
    );

    const productsByCategory = computed(() => {
        const grouped: Record<string, Product[]> = {};
        products.value.forEach(product => {
            const category = product.category || 'Sin categoría';
            if (!grouped[category]) {
                grouped[category] = [];
            }
            grouped[category].push(product);
        });
        return grouped;
    });

    // Methods
    const addProduct = (productData: Omit<Product, 'id' | 'createdAt' | 'updatedAt'>) => {
        const now = new Date().toISOString();
        const newProduct: Product = {
            ...productData,
            id: nextId.value++,
            createdAt: now,
            updatedAt: now,
        };
        products.value.push(newProduct);
        return newProduct;
    };

    const updateProduct = (id: number, updates: Partial<Omit<Product, 'id' | 'createdAt'>>) => {
        const index = products.value.findIndex(p => p.id === id);
        if (index !== -1) {
            products.value[index] = {
                ...products.value[index],
                ...updates,
                updatedAt: new Date().toISOString(),
            };
            return products.value[index];
        }
        return null;
    };

    const deleteProduct = (id: number) => {
        const index = products.value.findIndex(p => p.id === id);
        if (index !== -1) {
            products.value.splice(index, 1);
            return true;
        }
        return false;
    };

    const getProductById = (id: number) => {
        return products.value.find(p => p.id === id);
    };

    const getProductByPLU = (plu: string) => {
        return products.value.find(p => p.plu === plu);
    };

    const searchProducts = (query: string) => {
        const lowerQuery = query.toLowerCase();
        return products.value.filter(p => {
            const nameMatch = p.name ? p.name.toLowerCase().includes(lowerQuery) : false;
            const brandMatch = p.brand ? p.brand.toLowerCase().includes(lowerQuery) : false;
            const catMatch = p.category ? p.category.toLowerCase().includes(lowerQuery) : false;
            const pluMatch = p.plu ? p.plu.includes(query) : false;

            return nameMatch || brandMatch || catMatch || pluMatch;
        });
    };

    const updateStock = (id: number, quantity: number | Decimal) => {
        const product = products.value.find(p => p.id === id);
        if (product) {
            const delta = quantity instanceof Decimal ? quantity : new Decimal(quantity);
            product.stock = product.stock.plus(delta);
            product.updatedAt = new Date().toISOString();

            // Check for low stock notification
            if (product.stock.lt(product.minStock) && !product.notifiedLowStock) {
                const notificationsStore = useNotificationsStore();
                notificationsStore.addNotification({
                    type: 'inventory',
                    icon: 'inventory_2',
                    title: `Stock Bajo: ${product.name}`,
                    message: `Quedan ${product.stock.toFixed(product.measurementUnit === 'un' ? 0 : 2)} ${product.measurementUnit}`,
                    isRead: false,
                    metadata: {
                        productId: String(product.id),
                    },
                });
                product.notifiedLowStock = true;
            }

            // Reset flag if stock is restored above min
            if (product.stock.gte(product.minStock) && product.notifiedLowStock) {
                product.notifiedLowStock = false;
            }

            return product;
        }
        return null;
    };

    // Initialize with sample data if empty
    const initializeSampleData = () => {
        if (products.value.length === 0) {
            // Import dynamically to avoid circular deps  
            import('../data/sampleData').then(({ SAMPLE_PRODUCTS }) => {
                SAMPLE_PRODUCTS.forEach(product => addProduct(product));
                console.log('[Inventory] Initialized with', SAMPLE_PRODUCTS.length, 'sample products');
            });
        }
    };

    return {
        products,
        nextId,
        totalProducts,
        lowStockProducts,
        productsByCategory,
        addProduct,
        updateProduct,
        deleteProduct,
        getProductById,
        getProductByPLU,
        searchProducts,
        updateStock,
        initializeSampleData,
    };
}, {
    persist: {
        key: 'tienda-inventory',
        storage: localStorage,
        serializer: inventorySerializer,
    },
});

