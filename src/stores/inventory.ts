import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';

export interface Product {
    id: number;
    name: string;
    brand?: string;
    category?: string;
    plu?: string;
    price: Decimal;
    cost?: Decimal;
    saleMode: 'unit' | 'weight'; // unit = por unidad, weight = por peso/valor
    stock: number;
    minStock: number;
    unit: string;
    createdAt: string;
    updatedAt: string;
}

// Serialization helpers
function serializeProduct(product: Product) {
    return {
        ...product,
        price: product.price.toString(),
        cost: product.cost?.toString(),
    };
}

function deserializeProduct(data: any): Product {
    return {
        ...data,
        price: new Decimal(data.price),
        cost: data.cost ? new Decimal(data.cost) : undefined,
    };
}

export const useInventoryStore = defineStore('inventory', () => {
    const products = ref<Product[]>([]);
    const nextId = ref(1);

    // Computed
    const totalProducts = computed(() => products.value.length);

    const lowStockProducts = computed(() =>
        products.value.filter(p => p.stock <= p.minStock)
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

    const updateStock = (id: number, quantity: number) => {
        const product = products.value.find(p => p.id === id);
        if (product) {
            product.stock += quantity;
            product.updatedAt = new Date().toISOString();
            return product;
        }
        return null;
    };

    // Initialize with some sample data if empty
    const initializeSampleData = () => {
        if (products.value.length === 0) {
            const sampleProducts = [
                {
                    name: 'Coca Cola 1.5L',
                    brand: 'Coca Cola',
                    category: 'Bebidas',
                    plu: '101',
                    price: new Decimal(4500),
                    cost: new Decimal(3200),
                    saleMode: 'unit' as const,
                    stock: 24,
                    minStock: 6,
                    unit: 'un',
                },
                {
                    name: 'Pan Bimbo Blanco',
                    brand: 'Bimbo',
                    category: 'Panadería',
                    plu: '102',
                    price: new Decimal(3800),
                    cost: new Decimal(2800),
                    saleMode: 'unit' as const,
                    stock: 15,
                    minStock: 5,
                    unit: 'un',
                },
                {
                    name: 'Huevos AA x12',
                    brand: 'Santa Reyes',
                    category: 'Lácteos y Huevos',
                    plu: '103',
                    price: new Decimal(600),
                    cost: new Decimal(450),
                    saleMode: 'unit' as const,
                    stock: 30,
                    minStock: 12,
                    unit: 'un',
                },
                {
                    name: 'Leche Entera 1L',
                    brand: 'Alpina',
                    category: 'Lácteos y Huevos',
                    plu: '104',
                    price: new Decimal(3200),
                    cost: new Decimal(2400),
                    saleMode: 'unit' as const,
                    stock: 18,
                    minStock: 6,
                    unit: 'un',
                },
                {
                    name: 'Arroz Diana 500g',
                    brand: 'Diana',
                    category: 'Despensa',
                    plu: '105',
                    price: new Decimal(2100),
                    cost: new Decimal(1600),
                    saleMode: 'unit' as const,
                    stock: 20,
                    minStock: 8,
                    unit: 'un',
                },
                {
                    name: 'Aceite Girasol 1L',
                    brand: 'Gourmet',
                    category: 'Despensa',
                    plu: '106',
                    price: new Decimal(8500),
                    cost: new Decimal(6800),
                    saleMode: 'unit' as const,
                    stock: 12,
                    minStock: 4,
                    unit: 'un',
                },
                {
                    name: 'Azúcar 1kg',
                    brand: 'Manuelita',
                    category: 'Despensa',
                    plu: '107',
                    price: new Decimal(3500),
                    cost: new Decimal(2700),
                    saleMode: 'unit' as const,
                    stock: 25,
                    minStock: 10,
                    unit: 'un',
                },
                {
                    name: 'Sal 500g',
                    brand: 'Refisal',
                    category: 'Despensa',
                    plu: '108',
                    price: new Decimal(1200),
                    cost: new Decimal(900),
                    saleMode: 'unit' as const,
                    stock: 40,
                    minStock: 15,
                    unit: 'un',
                },
            ];

            sampleProducts.forEach(product => addProduct(product));
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
        serializer: {
            serialize: (state) => {
                return JSON.stringify({
                    products: state.products.map(serializeProduct),
                    nextId: state.nextId,
                });
            },
            deserialize: (value) => {
                const data = JSON.parse(value);
                return {
                    products: data.products.map(deserializeProduct),
                    nextId: data.nextId,
                };
            },
        },
    },
});
