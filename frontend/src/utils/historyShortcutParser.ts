import type { HistoryType, DatePreset } from '../composables/useHistory';

export type PaymentMethodShortcut = 'ALL' | 'CASH' | 'DIGITAL' | 'NEQUI' | 'DAVIPLATA' | 'CREDIT';

export interface HistoryFilterPatches {
  domain?: HistoryType;
  datePreset?: DatePreset;
  paymentMethod?: PaymentMethodShortcut;
  eventType?: string;
  employeeId?: string | null;
  employeeName?: string | null;
}

export interface ParseHistoryShortcutsResult {
  freeText: string;
  patches: HistoryFilterPatches;
  matchedCount: number;
}

export interface EmployeeRef {
  id: string;
  name: string;
}

function stripAccents(str: string): string {
  return str.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

/**
 * Parser de atajos de texto para Historial y Auditoría.
 * Extrae tokens reservados de dominio, período, medio de pago, subtipo de evento
 * o empleado, dejando únicamente el texto libre de búsqueda.
 */
export function parseHistoryShortcuts(
  input: string,
  employees?: EmployeeRef[]
): ParseHistoryShortcutsResult {
  const patches: HistoryFilterPatches = {};
  let matchedCount = 0;

  if (!input || !input.trim()) {
    return { freeText: '', patches, matchedCount: 0 };
  }

  // Tokenizar preservando strings entre comillas
  const rawTokens = input.match(/[^\s"]+|"[^"]*"/g) || [];
  const parsedTokens: string[] = [];

  for (let i = 0; i < rawTokens.length; i++) {
    const t = rawTokens[i];
    if (t.endsWith(':') && i + 1 < rawTokens.length && rawTokens[i + 1].startsWith('"')) {
      parsedTokens.push(`${t}${rawTokens[i + 1]}`);
      i++;
    } else {
      parsedTokens.push(t);
    }
  }

  const freeTextTokens: string[] = [];

  for (const token of parsedTokens) {
    const rawToken = token.trim();
    if (!rawToken) continue;

    const normalized = stripAccents(rawToken).toLowerCase();

    // 1. Dominios
    if (normalized === 'ventas' || normalized === 'venta') {
      patches.domain = 'sales';
      matchedCount++;
      continue;
    }
    if (normalized === 'caja' || normalized === 'turnos') {
      patches.domain = 'cash';
      matchedCount++;
      continue;
    }
    if (normalized === 'compras' || normalized === 'inventario') {
      patches.domain = 'inventory';
      matchedCount++;
      continue;
    }
    if (normalized === 'gastos' || normalized === 'gasto') {
      patches.domain = 'expenses';
      matchedCount++;
      continue;
    }
    if (normalized === 'creditos' || normalized === 'credito' || normalized === 'fiados' || normalized === 'fiado') {
      patches.domain = 'credits';
      matchedCount++;
      continue;
    }
    if (normalized === 'precios' || normalized === 'precio') {
      patches.domain = 'prices';
      matchedCount++;
      continue;
    }
    if (normalized === 'auditoria' || normalized === 'seguridad') {
      patches.domain = 'audit';
      matchedCount++;
      continue;
    }

    // 2. Períodos (FRD-005 Regla 6)
    if (normalized === 'hoy') {
      patches.datePreset = 'today';
      matchedCount++;
      continue;
    }
    if (normalized === 'ayer') {
      patches.datePreset = 'yesterday';
      matchedCount++;
      continue;
    }
    if (normalized === 'semana' || normalized === '7d' || normalized === 'ultimos-7-dias') {
      patches.datePreset = 'week';
      matchedCount++;
      continue;
    }
    if (normalized === 'mes' || normalized === '30d' || normalized === 'ultimos-30-dias') {
      patches.datePreset = 'month';
      matchedCount++;
      continue;
    }

    // 3. Métodos de Pago (FRD-021)
    if (normalized === 'efectivo') {
      patches.paymentMethod = 'CASH';
      matchedCount++;
      continue;
    }
    if (normalized === 'digital' || normalized === 'digitales') {
      patches.paymentMethod = 'DIGITAL';
      matchedCount++;
      continue;
    }
    if (normalized === 'nequi') {
      patches.paymentMethod = 'NEQUI';
      matchedCount++;
      continue;
    }
    if (normalized === 'daviplata') {
      patches.paymentMethod = 'DAVIPLATA';
      matchedCount++;
      continue;
    }

    // 4. Subtipos de Evento
    if (normalized === 'anuladas' || normalized === 'anulacion' || normalized === 'anulaciones') {
      patches.eventType = 'cancellations';
      matchedCount++;
      continue;
    }
    if (normalized === 'creaciones' || normalized === 'creacion' || normalized === 'ventas-activas') {
      patches.eventType = 'creations';
      matchedCount++;
      continue;
    }
    if (normalized === 'entradas' || normalized === 'entrada') {
      patches.eventType = 'entries';
      matchedCount++;
      continue;
    }
    if (normalized === 'ajustes' || normalized === 'ajuste') {
      patches.eventType = 'adjustments';
      matchedCount++;
      continue;
    }
    if (normalized === 'apertura') {
      patches.eventType = 'APERTURA';
      matchedCount++;
      continue;
    }
    if (normalized === 'cierre') {
      patches.eventType = 'CIERRE';
      matchedCount++;
      continue;
    }

    // 5. Empleado (empleado:nombre o cajero:nombre)
    if (normalized.startsWith('empleado:') || normalized.startsWith('cajero:')) {
      const prefixLength = normalized.startsWith('empleado:') ? 9 : 7;
      const targetName = rawToken.slice(prefixLength).replace(/^"|"$/g, '').trim();
      const normTarget = stripAccents(targetName).toLowerCase();

      if (normTarget && employees && employees.length > 0) {
        const found = employees.find((emp) =>
          stripAccents(emp.name).toLowerCase().includes(normTarget)
        );
        if (found) {
          patches.employeeId = found.id;
          patches.employeeName = found.name;
          matchedCount++;
          continue;
        }
      }
    }

    // Si no es un atajo reservado, es texto libre de búsqueda
    freeTextTokens.push(rawToken.replace(/^"|"$/g, ''));
  }

  return {
    freeText: freeTextTokens.join(' ').trim(),
    patches,
    matchedCount,
  };
}
