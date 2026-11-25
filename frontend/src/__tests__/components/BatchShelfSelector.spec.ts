import { describe, it, expect, afterEach } from 'vitest';
import { mount, enableAutoUnmount, flushPromises } from '@vue/test-utils';
import BatchShelfSelector from '../../components/inventory/BatchShelfSelector.vue';
import type { InventoryBatch } from '../../stores/batches';

enableAutoUnmount(afterEach);

const makeBatch = (overrides: Partial<InventoryBatch>): InventoryBatch => ({
  id: 'b-1',
  product_id: 'p-1',
  quantity_initial: 10,
  quantity_remaining: 5,
  cost_unit: 2000,
  sale_price: 3500,
  is_active: true,
  created_at: '2026-11-20T10:00:00Z',
  expiration_date: null,
  ...overrides,
});

describe('BatchShelfSelector.vue (WO-OLA2-C3-001)', () => {
  it('con 0 o 1 lote activo permanece invisible en el DOM y autoselecciona el único lote', async () => {
    const single = makeBatch({ id: 'batch-only', quantity_remaining: 4 });
    const zero = makeBatch({ id: 'batch-empty', quantity_remaining: 0 });

    const w1 = mount(BatchShelfSelector, {
      props: { batches: [single, zero], modelValue: null, unit: 'un' },
    });
    await flushPromises();

    expect(w1.find('[data-testid="batch-shelf-selector"]').exists()).toBe(false);
    expect(w1.emitted('update:modelValue')?.[0]).toEqual(['batch-only']);

    const w0 = mount(BatchShelfSelector, {
      props: { batches: [zero], modelValue: 'batch-only', unit: 'un' },
    });
    await flushPromises();
    expect(w0.find('[data-testid="batch-shelf-selector"]').exists()).toBe(false);
    expect(w0.emitted('update:modelValue')?.[0]).toEqual([null]);
  });

  it('con 2+ lotes activos muestra lenguaje de estantería FIFO, vencimiento y emite el lote elegido', async () => {
    const older = makeBatch({
      id: 'batch-old',
      created_at: '2026-11-01T08:00:00Z',
      quantity_remaining: 3,
      cost_unit: 1800,
      expiration_date: '2026-12-01',
    });
    const newer = makeBatch({
      id: 'batch-new',
      created_at: '2026-11-22T08:00:00Z',
      quantity_remaining: 8,
      cost_unit: 2200,
      expiration_date: '2027-01-15',
    });

    const wrapper = mount(BatchShelfSelector, {
      props: { batches: [newer, older], modelValue: null, unit: 'un' },
    });
    await flushPromises();

    expect(wrapper.find('[data-testid="batch-shelf-selector"]').exists()).toBe(true);
    // Autoselecciona el más antiguo (FIFO)
    expect(wrapper.emitted('update:modelValue')?.[0]).toEqual(['batch-old']);

    const text = wrapper.text();
    expect(text).toContain('Lote anterior (adelante en estantería)');
    expect(text).toContain('Lote reciente (atrás en estantería)');
    expect(text).toContain('Precio: $ 3.500');
    expect(text).toContain('Costo: $ 1.800');
    expect(text).toContain('Vence: 2026-12-01');
    expect(text).toContain('Vence: 2027-01-15');

    await wrapper.find('[data-testid="shelf-batch-option-1"]').trigger('click');
    const emitted = wrapper.emitted('update:modelValue') || [];
    expect(emitted[emitted.length - 1]).toEqual(['batch-new']);
  });
});
