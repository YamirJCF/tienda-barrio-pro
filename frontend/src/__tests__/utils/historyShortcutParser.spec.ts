import { describe, it, expect } from 'vitest';
import { parseHistoryShortcuts } from '../../utils/historyShortcutParser';

describe('historyShortcutParser', () => {
  const mockEmployees = [
    { id: 'emp-1', name: 'Carlos Mendoza' },
    { id: 'emp-2', name: 'Ana Gómez' },
  ];

  it('devuelve freeText intacto y 0 patches cuando no hay atajos', () => {
    const res = parseHistoryShortcuts('ticket #1042');
    expect(res.freeText).toBe('ticket #1042');
    expect(res.matchedCount).toBe(0);
    expect(res.patches).toEqual({});
  });

  it('reconoce atajos de dominio (ventas, caja, compras, gastos, creditos, precios, auditoria)', () => {
    expect(parseHistoryShortcuts('ventas').patches.domain).toBe('sales');
    expect(parseHistoryShortcuts('caja').patches.domain).toBe('cash');
    expect(parseHistoryShortcuts('compras').patches.domain).toBe('inventory');
    expect(parseHistoryShortcuts('gastos').patches.domain).toBe('expenses');
    expect(parseHistoryShortcuts('creditos').patches.domain).toBe('credits');
    expect(parseHistoryShortcuts('fiados').patches.domain).toBe('credits');
    expect(parseHistoryShortcuts('precios').patches.domain).toBe('prices');
    expect(parseHistoryShortcuts('auditoria').patches.domain).toBe('audit');
    expect(parseHistoryShortcuts('seguridad').patches.domain).toBe('audit');
  });

  it('reconoce atajos de período (hoy, ayer, semana, mes, 7d, 30d)', () => {
    expect(parseHistoryShortcuts('hoy').patches.datePreset).toBe('today');
    expect(parseHistoryShortcuts('ayer').patches.datePreset).toBe('yesterday');
    expect(parseHistoryShortcuts('semana').patches.datePreset).toBe('week');
    expect(parseHistoryShortcuts('7d').patches.datePreset).toBe('week');
    expect(parseHistoryShortcuts('mes').patches.datePreset).toBe('month');
    expect(parseHistoryShortcuts('30d').patches.datePreset).toBe('month');
  });

  it('reconoce atajos de método de pago (efectivo, digital, nequi, daviplata)', () => {
    expect(parseHistoryShortcuts('efectivo').patches.paymentMethod).toBe('CASH');
    expect(parseHistoryShortcuts('digitales').patches.paymentMethod).toBe('DIGITAL');
    expect(parseHistoryShortcuts('nequi').patches.paymentMethod).toBe('NEQUI');
    expect(parseHistoryShortcuts('daviplata').patches.paymentMethod).toBe('DAVIPLATA');
  });

  it('reconoce atajos de subtipo de evento (anuladas, creaciones, entradas, ajustes, apertura, cierre)', () => {
    expect(parseHistoryShortcuts('anuladas').patches.eventType).toBe('cancellations');
    expect(parseHistoryShortcuts('creaciones').patches.eventType).toBe('creations');
    expect(parseHistoryShortcuts('entradas').patches.eventType).toBe('entries');
    expect(parseHistoryShortcuts('ajustes').patches.eventType).toBe('adjustments');
    expect(parseHistoryShortcuts('apertura').patches.eventType).toBe('APERTURA');
    expect(parseHistoryShortcuts('cierre').patches.eventType).toBe('CIERRE');
  });

  it('reconoce atajos de empleado con sintaxis empleado:nombre o cajero:nombre', () => {
    const res1 = parseHistoryShortcuts('empleado:carlos', mockEmployees);
    expect(res1.patches.employeeId).toBe('emp-1');
    expect(res1.patches.employeeName).toBe('Carlos Mendoza');

    const res2 = parseHistoryShortcuts('cajero:ana', mockEmployees);
    expect(res2.patches.employeeId).toBe('emp-2');
    expect(res2.patches.employeeName).toBe('Ana Gómez');
  });

  it('soporta comillas en el nombre de empleado ej: empleado:"carlos mendoza"', () => {
    const res = parseHistoryShortcuts('empleado:"carlos mendoza"', mockEmployees);
    expect(res.patches.employeeId).toBe('emp-1');
    expect(res.patches.employeeName).toBe('Carlos Mendoza');
    expect(res.freeText).toBe('');
  });

  it('combina múltiples atajos y extrae el texto libre restante limpiamente', () => {
    const res = parseHistoryShortcuts('ventas hoy efectivo leche colanta', mockEmployees);
    expect(res.patches.domain).toBe('sales');
    expect(res.patches.datePreset).toBe('today');
    expect(res.patches.paymentMethod).toBe('CASH');
    expect(res.freeText).toBe('leche colanta');
    expect(res.matchedCount).toBe(3);
  });

  it('ignora mayúsculas y acentos en las palabras clave', () => {
    const res = parseHistoryShortcuts('VENTAS CRÉDITOS AUDITORÍA AYER');
    expect(res.patches.datePreset).toBe('yesterday');
    expect(res.matchedCount).toBeGreaterThan(0);
  });
});
