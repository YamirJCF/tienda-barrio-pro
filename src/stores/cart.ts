import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';

export interface Product {
  id: number;
  name: string;
  price: Decimal;
  quantity: number;
  unit: string;
}

// Helper functions for serialization
function serializeProduct(product: Product) {
  return {
    ...product,
    price: product.price.toString(),
  };
}

function deserializeProduct(data: any): Product {
  return {
    ...data,
    price: new Decimal(data.price),
  };
}

export const useCartStore = defineStore('cart', () => {
  const items = ref<Product[]>([]);

  const total = computed(() => {
    return items.value.reduce((acc, item) => {
      return acc.plus(item.price.times(item.quantity));
    }, new Decimal(0));
  });

  const formattedTotal = computed(() => {
    return `$ ${total.value.toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")}`;
  });

  const addItem = (product: Product) => {
    const existing = items.value.find(i => i.id === product.id);
    if (existing) {
      existing.quantity += 1;
    } else {
      items.value.push({ ...product, quantity: 1 });
    }
  };

  const removeItem = (id: number) => {
    const index = items.value.findIndex(i => i.id === id);
    if (index !== -1) {
      items.value.splice(index, 1);
    }
  };

  const clearCart = () => {
    items.value = [];
  };

  return {
    items,
    total,
    formattedTotal,
    addItem,
    removeItem,
    clearCart
  };
}, {
  persist: {
    key: 'tienda-cart',
    storage: localStorage,
    serializer: {
      serialize: (state) => {
        return JSON.stringify({
          items: state.items.map(serializeProduct),
        });
      },
      deserialize: (value) => {
        const data = JSON.parse(value);
        return {
          items: data.items.map(deserializeProduct),
        };
      },
    },
  },
});