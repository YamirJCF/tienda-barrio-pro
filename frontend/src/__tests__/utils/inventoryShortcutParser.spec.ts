import { describe, it, expect } from 'vitest';
import { parseShortcuts } from '../../utils/inventoryShortcutParser';

describe('inventoryShortcutParser (TDD - Parser de Atajos Internos)', () => {
  describe('Atajos de Estado y Palabras Clave', () => {
    it('debe reconocer "bajo" y activar onlyLowStock', () => {
      const res = parseShortcuts('bajo');
      expect(res.filters.onlyLowStock).toBe(true);
      expect(res.freeText).toBe('');
      expect(res.errors).toHaveLength(0);
    });

    it('debe reconocer "agotado" y definir stockRule { op: "=", value: 0 }', () => {
      const res = parseShortcuts('agotado');
      expect(res.filters.stockRule).toEqual({ op: '=', value: 0 });
      expect(res.freeText).toBe('');
      expect(res.errors).toHaveLength(0);
    });

    it('debe normalizar mayúsculas y acentos (ej. "BAJO", "Ágotado")', () => {
      const res = parseShortcuts('BAJO Ágotado');
      expect(res.filters.onlyLowStock).toBe(true);
      expect(res.filters.stockRule).toEqual({ op: '=', value: 0 });
      expect(res.errors).toHaveLength(0);
    });
  });

  describe('Atajos de Atributos (marca, plu)', () => {
    it('debe extraer marca simple y marca con comillas', () => {
      const res1 = parseShortcuts('marca:alpina');
      expect(res1.filters.brandFilter).toBe('alpina');
      expect(res1.freeText).toBe('');

      const res2 = parseShortcuts('marca:"aseo general"');
      expect(res2.filters.brandFilter).toBe('aseo general');
      expect(res2.freeText).toBe('');
    });

    it('debe extraer plu', () => {
      const res = parseShortcuts('plu:1001');
      expect(res.filters.pluFilter).toBe('1001');
      expect(res.freeText).toBe('');
    });
  });

  describe('Comparadores Numéricos (stock, precio)', () => {
    it('debe parsear operadores de stock: <, <=, >, >=, =', () => {
      expect(parseShortcuts('stock<10').filters.stockRule).toEqual({ op: '<', value: 10 });
      expect(parseShortcuts('stock<=5').filters.stockRule).toEqual({ op: '<=', value: 5 });
      expect(parseShortcuts('stock>0').filters.stockRule).toEqual({ op: '>', value: 0 });
      expect(parseShortcuts('stock>=20').filters.stockRule).toEqual({ op: '>=', value: 20 });
      expect(parseShortcuts('stock=15').filters.stockRule).toEqual({ op: '=', value: 15 });
    });

    it('debe parsear operadores de precio aceptando puntos de miles', () => {
      expect(parseShortcuts('precio<5000').filters.priceRule).toEqual({ op: '<', value: 5000 });
      expect(parseShortcuts('precio<=12.000').filters.priceRule).toEqual({ op: '<=', value: 12000 });
      expect(parseShortcuts('precio>2500').filters.priceRule).toEqual({ op: '>', value: 2500 });
    });
  });

  describe('Permisos de Administrador (inactivo)', () => {
    it('debe activar includeInactive si isAdmin es true', () => {
      const res = parseShortcuts('inactivo', { isAdmin: true });
      expect(res.filters.includeInactive).toBe(true);
      expect(res.errors).toHaveLength(0);
      expect(res.warnings).toHaveLength(0);
    });

    it('debe rechazar inactivo con advertencia si isAdmin es false', () => {
      const res = parseShortcuts('inactivo', { isAdmin: false });
      expect(res.filters.includeInactive).toBeUndefined();
      expect(res.warnings.length).toBeGreaterThan(0);
      expect(res.warnings[0]).toContain('administrador');
    });
  });

  describe('Texto Libre Combinado y Reemplazo de Operadores', () => {
    it('debe aislar el texto libre y extraer los atajos', () => {
      const res = parseShortcuts('leche deslactosada bajo stock<10 marca:colanta');
      expect(res.freeText).toBe('leche deslactosada');
      expect(res.filters.onlyLowStock).toBe(true);
      expect(res.filters.stockRule).toEqual({ op: '<', value: 10 });
      expect(res.filters.brandFilter).toBe('colanta');
      expect(res.errors).toHaveLength(0);
    });

    it('debe reemplazar operadores duplicados con el último ingresado', () => {
      const res = parseShortcuts('stock<10 stock>2');
      expect(res.filters.stockRule).toEqual({ op: '>', value: 2 });
    });
  });

  describe('Ramas de Error Explícito (Cero Fallos Silenciosos)', () => {
    it('debe reportar error si se usa una clave desconocida con forma de atajo', () => {
      const res = parseShortcuts('stok<5');
      expect(res.errors.length).toBeGreaterThan(0);
      expect(res.errors[0]).toContain('desconocido');
    });

    it('debe reportar error si el comparador tiene un valor no numérico', () => {
      const res = parseShortcuts('stock<abc');
      expect(res.errors.length).toBeGreaterThan(0);
      expect(res.errors[0]).toContain('numérico');
    });

    it('debe reportar error si la clave tiene un valor vacío', () => {
      const res = parseShortcuts('marca:');
      expect(res.errors.length).toBeGreaterThan(0);
      expect(res.errors[0]).toContain('vacío');
    });

    it('debe reportar error si se intenta usar "cat:" indicando usar el desplegable', () => {
      const res = parseShortcuts('cat:lacteos');
      expect(res.errors.length).toBeGreaterThan(0);
      expect(res.errors[0]).toContain('desplegable de Categoría');
    });

    it('debe reportar error si hay comillas sin cerrar', () => {
      const res = parseShortcuts('marca:"arroz diana');
      expect(res.errors.length).toBeGreaterThan(0);
      expect(res.errors[0]).toContain('comillas');
    });
  });
});
