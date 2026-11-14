import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import { Decimal } from 'decimal.js';
import WeightCalculatorModal from '../../components/WeightCalculatorModal.vue';
import type { Product } from '../../types';

describe('WeightCalculatorModal - Opción A y Validaciones SPEC-010/011', () => {
  const makeProduct = (overrides: Partial<Product> = {}): Product => ({
    id: 'prod-weight-1',
    name: 'prueba7',
    price: new Decimal(1300),
    stock: new Decimal(20),
    measurementUnit: 'lb',
    minStock: 2,
    isWeighable: true,
    storeId: 'store-1',
    ...overrides,
  });

  const mountModal = (product: Product = makeProduct()) =>
    mount(WeightCalculatorModal, {
      props: {
        modelValue: true,
        product,
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });

  const findButtonByExactText = (wrapper: ReturnType<typeof mountModal>, label: string) =>
    wrapper.findAll('button').find((b) => b.text().trim() === label);

  const findButtonIncludingText = (wrapper: ReturnType<typeof mountModal>, snippet: string) =>
    wrapper.findAll('button').find((b) => b.text().includes(snippet));

  it('inicia en modo Por Valor ocultando el selector kg/Libras/Gramos y mostrando la unidad base', () => {
    const wrapper = mountModal();

    expect(wrapper.text()).toContain('$ 1.300 / Libras');
    expect(wrapper.text()).not.toContain('Vender en:');
    expect(findButtonByExactText(wrapper, 'kg')).toBeUndefined();
    expect(findButtonByExactText(wrapper, 'Libras')).toBeUndefined();
    expect(findButtonByExactText(wrapper, 'Gramos')).toBeUndefined();
  });

  it('muestra los botones kg, Libras y Gramos únicamente al cambiar a Por Peso y permite seleccionar unidad', async () => {
    const wrapper = mountModal();

    const porPesoBtn = findButtonIncludingText(wrapper, 'Por Peso');
    expect(porPesoBtn).toBeDefined();
    await porPesoBtn!.trigger('click');

    expect(wrapper.text()).toContain('Vender en:');
    const kgBtn = findButtonByExactText(wrapper, 'kg');
    const lbBtn = findButtonByExactText(wrapper, 'Libras');
    const gBtn = findButtonByExactText(wrapper, 'Gramos');
    expect(kgBtn).toBeDefined();
    expect(lbBtn).toBeDefined();
    expect(gBtn).toBeDefined();

    await kgBtn!.trigger('click');
    expect(wrapper.text()).toContain('Kilogramos');
    expect(wrapper.text()).toContain('Cantidad (kg)');
  });

  it('al volver de Por Peso a Por Valor oculta las unidades y restaura sellUnit a la unidad base del producto', async () => {
    const wrapper = mountModal(makeProduct({ price: new Decimal(1300), measurementUnit: 'lb' }));

    await findButtonIncludingText(wrapper, 'Por Peso')!.trigger('click');
    await findButtonByExactText(wrapper, 'kg')!.trigger('click');
    expect(wrapper.text()).toContain('Kilogramos');

    await findButtonIncludingText(wrapper, 'Por Valor')!.trigger('click');

    expect(wrapper.text()).not.toContain('Vender en:');
    expect(findButtonByExactText(wrapper, 'kg')).toBeUndefined();
    expect(wrapper.text()).toContain('$ 1.300 / Libras');
  });

  it('deshabilita el botón Agregar cuando en Por Valor el monto ingresado redondea a $ 0 (ej. $ 1 o $ 25)', async () => {
    const wrapper = mountModal();

    await findButtonByExactText(wrapper, '1')!.trigger('click');
    const confirmBtn1 = findButtonIncludingText(wrapper, 'Agregar');
    expect(confirmBtn1).toBeDefined();
    expect(confirmBtn1!.text()).toContain('Agregar $ 0');
    expect(confirmBtn1!.attributes('disabled')).toBeDefined();

    // Limpiar y probar $ 25 (también redondea hacia abajo a $ 0 según SPEC-010)
    await findButtonByExactText(wrapper, '2')!.trigger('click'); // "12"
    await findButtonByExactText(wrapper, '5')!.trigger('click'); // "125" -> borrar hasta dejar "25"
    await wrapper.setProps({ modelValue: false });
    await wrapper.setProps({ modelValue: true });
    await findButtonByExactText(wrapper, '2')!.trigger('click');
    await findButtonByExactText(wrapper, '5')!.trigger('click');

    const confirmBtn25 = findButtonIncludingText(wrapper, 'Agregar');
    expect(confirmBtn25!.text()).toContain('Agregar $ 0');
    expect(confirmBtn25!.attributes('disabled')).toBeDefined();
    expect(wrapper.emitted('confirm')).toBeUndefined();
  });

  it('calcula peso con máximo 2 decimales (SPEC-011), habilita el botón y emite subtotal $ 2.000 para producto de $ 1.300 / lb', async () => {
    const wrapper = mountModal(makeProduct({ price: new Decimal(1300), measurementUnit: 'lb' }));

    await findButtonByExactText(wrapper, '2')!.trigger('click');
    await findButtonByExactText(wrapper, '0')!.trigger('click');
    await findButtonByExactText(wrapper, '00')!.trigger('click');

    expect(wrapper.text()).toContain('= 1.54 lb');

    const confirmBtn = findButtonIncludingText(wrapper, 'Agregar');
    expect(confirmBtn!.text()).toContain('Agregar $ 2.000');
    expect(confirmBtn!.attributes('disabled')).toBeUndefined();

    await confirmBtn!.trigger('click');
    const emitted = wrapper.emitted('confirm');
    expect(emitted).toBeDefined();
    expect(emitted).toHaveLength(1);
    const payload = emitted![0][0] as { product: Product; quantity: Decimal; subtotal: Decimal };
    expect(payload.subtotal.toNumber()).toBe(2000);
    expect(payload.quantity.toFixed(2)).toBe('1.54');
  });

  it('formatea gramos como enteros sin decimales (SPEC-011) y bloquea punto decimal en Gramos en Por Peso', async () => {
    const wrapper = mountModal(makeProduct({ price: new Decimal(3000), measurementUnit: 'kg' }));

    await findButtonIncludingText(wrapper, 'Por Peso')!.trigger('click');
    await findButtonByExactText(wrapper, 'Gramos')!.trigger('click');

    const dotBtn = findButtonByExactText(wrapper, '.');
    expect(dotBtn).toBeDefined();
    expect(dotBtn!.attributes('disabled')).toBeDefined();

    await dotBtn!.trigger('click');
    await findButtonByExactText(wrapper, '5')!.trigger('click');
    await findButtonByExactText(wrapper, '00')!.trigger('click');

    expect(wrapper.text()).toContain('500 g');
    const confirmBtn = findButtonIncludingText(wrapper, 'Agregar');
    expect(confirmBtn!.text()).toContain('Agregar $ 1.500');
  });
});
