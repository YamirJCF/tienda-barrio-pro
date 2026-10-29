export interface ShortcutFilters {
  onlyLowStock?: boolean;
  stockRule?: { op: '<' | '<=' | '>' | '>=' | '='; value: number };
  priceRule?: { op: '<' | '<=' | '>' | '>=' | '='; value: number };
  brandFilter?: string;
  pluFilter?: string;
  includeInactive?: boolean;
}

export interface ParseShortcutsResult {
  freeText: string;
  filters: ShortcutFilters;
  errors: string[];
  warnings: string[];
}

export interface ParseShortcutsOptions {
  isAdmin?: boolean;
}

function stripAccents(str: string): string {
  return str.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function parseNumber(raw: string): number | null {
  const clean = raw.trim().replace(/\./g, '');
  if (!clean || !/^-?\d+(\.\d+)?$/.test(clean)) {
    return null;
  }
  const n = Number(clean);
  return isNaN(n) ? null : n;
}

export function parseShortcuts(
  input: string,
  options?: ParseShortcutsOptions
): ParseShortcutsResult {
  const errors: string[] = [];
  const warnings: string[] = [];
  const filters: ShortcutFilters = {};
  const freeTextTokens: string[] = [];

  if (!input || !input.trim()) {
    return { freeText: '', filters, errors, warnings };
  }

  // Comprobar comillas no cerradas
  const quoteCount = (input.match(/"/g) || []).length;
  if (quoteCount % 2 !== 0) {
    errors.push('Error de sintaxis: comillas sin cerrar');
    return { freeText: input.trim(), filters, errors, warnings };
  }

  // Tokenizar respetando comillas dobles
  const tokenRegex = /[^\s"]+|"([^"]*)"/g;
  const tokens: string[] = [];
  let match: RegExpExecArray | null;

  // Si hay tokens combinados como marca:"aseo general"
  // Hacemos un tokenizado preservando key:"quoted"
  const rawTokens = input.match(/[^\s"]+|"[^"]*"/g) || [];
  
  // Reensamblar si venía prefijado ej: marca:"algo"
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

  for (const token of parsedTokens) {
    const rawToken = token.trim();
    if (!rawToken) continue;

    // Normalizar para evaluación de clave
    const normalized = stripAccents(rawToken).toLowerCase();

    // 1. Atajo cat: (Excluido deliberadamente en favor del dropdown)
    if (normalized === 'cat:' || normalized.startsWith('cat:')) {
      errors.push("El atajo 'cat:' no está disponible. Usa el desplegable de Categoría.");
      continue;
    }

    // 2. Palabras clave de estado
    if (normalized === 'bajo') {
      filters.onlyLowStock = true;
      continue;
    }

    if (normalized === 'agotado') {
      filters.stockRule = { op: '=', value: 0 };
      continue;
    }

    if (normalized === 'inactivo') {
      if (options?.isAdmin) {
        filters.includeInactive = true;
      } else {
        warnings.push("El filtro 'inactivo' requiere permisos de administrador y fue ignorado.");
      }
      continue;
    }

    // 3. Atajo marca:
    if (normalized.startsWith('marca:')) {
      const valuePart = rawToken.slice(6).trim();
      const cleanVal = valuePart.replace(/^"|"$/g, '').trim();
      if (!cleanVal) {
        errors.push("El filtro 'marca:' no puede tener un valor vacío.");
      } else {
        filters.brandFilter = cleanVal.toLowerCase();
      }
      continue;
    }

    // 4. Atajo plu:
    if (normalized.startsWith('plu:')) {
      const cleanVal = rawToken.slice(4).trim().replace(/^"|"$/g, '');
      if (!cleanVal) {
        errors.push("El filtro 'plu:' no puede tener un valor vacío.");
      } else {
        filters.pluFilter = cleanVal;
      }
      continue;
    }

    // 5. Comparadores de Stock (ej. stock<10, stock<=5, stock=0)
    const stockMatch = normalized.match(/^stock(<=|>=|<|>|=)(.*)$/);
    if (stockMatch) {
      const op = stockMatch[1] as '<' | '<=' | '>' | '>=' | '=';
      const num = parseNumber(stockMatch[2]);
      if (num === null) {
        errors.push(`El filtro de stock requiere un valor numérico válido (recibido: '${stockMatch[2]}').`);
      } else {
        filters.stockRule = { op, value: num };
      }
      continue;
    }

    // 6. Comparadores de Precio (ej. precio<5000, precio>=10.000)
    const priceMatch = normalized.match(/^precio(<=|>=|<|>|=)(.*)$/);
    if (priceMatch) {
      const op = priceMatch[1] as '<' | '<=' | '>' | '>=' | '=';
      const num = parseNumber(priceMatch[2]);
      if (num === null) {
        errors.push(`El filtro de precio requiere un valor numérico válido (recibido: '${priceMatch[2]}').`);
      } else {
        filters.priceRule = { op, value: num };
      }
      continue;
    }

    // 7. Detección de claves desconocidas que tienen forma de atajo (contienen : o comparadores)
    if (rawToken.includes(':') || /^[a-zA-Z]+(<=|>=|<|>|=)/.test(rawToken)) {
      errors.push(`Atajo desconocido o mal formado: '${rawToken}'.`);
      continue;
    }

    // 8. Es texto libre ordinario
    freeTextTokens.push(rawToken.replace(/^"|"$/g, ''));
  }

  return {
    freeText: freeTextTokens.join(' ').trim(),
    filters,
    errors,
    warnings,
  };
}
