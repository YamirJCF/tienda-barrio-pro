/**
 * useDataIntegrity.ts
 * 
 * Composable para verificar y sanitizar datos de localStorage antes
 * de que la aplicación intente leerlos. Previene crashes por datos corruptos.
 */

// ============================================
// TIPOS Y CONFIGURACIÓN
// ============================================

interface StorageKeyConfig {
    key: string;
    validator: (data: unknown) => boolean;
    description: string;
}

// Definición de claves críticas y sus validadores
const CRITICAL_STORAGE_KEYS: StorageKeyConfig[] = [
    {
        key: 'tienda-auth',
        description: 'Autenticación y tiendas',
        validator: (data: unknown): boolean => {
            if (typeof data !== 'object' || data === null) return false;
            const obj = data as Record<string, unknown>;
            // Debe tener un array de 'stores'
            return Array.isArray(obj.stores);
        }
    },
    {
        key: 'tienda-cart',
        description: 'Carrito de compras',
        validator: (data: unknown): boolean => {
            if (typeof data !== 'object' || data === null) return false;
            const obj = data as Record<string, unknown>;
            // Debe tener un array de 'items'
            return Array.isArray(obj.items);
        }
    },
    {
        key: 'tienda-inventory',
        description: 'Inventario de productos',
        validator: (data: unknown): boolean => {
            if (typeof data !== 'object' || data === null) return false;
            const obj = data as Record<string, unknown>;
            // Debe tener un array de 'products'
            return Array.isArray(obj.products);
        }
    },
    {
        key: 'tienda-sales',
        description: 'Historial de ventas',
        validator: (data: unknown): boolean => {
            if (typeof data !== 'object' || data === null) return false;
            const obj = data as Record<string, unknown>;
            // Debe tener un array de 'sales'
            return Array.isArray(obj.sales);
        }
    },
    {
        key: 'tienda-clients',
        description: 'Clientes y fiados',
        validator: (data: unknown): boolean => {
            if (typeof data !== 'object' || data === null) return false;
            const obj = data as Record<string, unknown>;
            // Debe tener un array de 'clients'
            return Array.isArray(obj.clients);
        }
    },
    {
        key: 'tienda-employees',
        description: 'Empleados',
        validator: (data: unknown): boolean => {
            if (typeof data !== 'object' || data === null) return false;
            const obj = data as Record<string, unknown>;
            // Debe tener un array de 'employees'
            return Array.isArray(obj.employees);
        }
    },
    {
        key: 'tienda-expenses',
        description: 'Gastos',
        validator: (data: unknown): boolean => {
            if (typeof data !== 'object' || data === null) return false;
            const obj = data as Record<string, unknown>;
            // Debe tener un array de 'expenses'
            return Array.isArray(obj.expenses);
        }
    },
    {
        key: 'tienda-store-status',
        description: 'Estado de la tienda',
        validator: (data: unknown): boolean => {
            if (typeof data !== 'object' || data === null) return false;
            // Solo necesita ser un objeto válido
            return true;
        }
    }
];

// ============================================
// RESULTADO DE LA VERIFICACIÓN
// ============================================

export interface IntegrityCheckResult {
    wasCorrupted: boolean;
    repairedKeys: string[];
    validKeys: string[];
    timestamp: string;
}

// ============================================
// FUNCIÓN PRINCIPAL
// ============================================

/**
 * Verifica la integridad de los datos en localStorage.
 * Si encuentra datos corruptos, los elimina automáticamente.
 * 
 * @returns Resultado de la verificación con detalles de las reparaciones
 */
export function checkDataIntegrity(): IntegrityCheckResult {
    const result: IntegrityCheckResult = {
        wasCorrupted: false,
        repairedKeys: [],
        validKeys: [],
        timestamp: new Date().toISOString()
    };

    console.group('🔍 Data Integrity Check');
    console.log('Iniciando verificación de integridad...');

    for (const config of CRITICAL_STORAGE_KEYS) {
        const rawData = localStorage.getItem(config.key);

        // Si la clave no existe, es válido (datos vacíos)
        if (rawData === null) {
            console.log(`⬜ ${config.key}: No existe (OK)`);
            continue;
        }

        try {
            // Intentar parsear JSON
            const parsedData = JSON.parse(rawData);

            // Validar estructura
            if (config.validator(parsedData)) {
                console.log(`✅ ${config.key}: Válido`);
                result.validKeys.push(config.key);
            } else {
                // Estructura inválida - purgar
                console.warn(`⚠️ ${config.key}: Estructura inválida - PURGANDO`);
                localStorage.removeItem(config.key);
                result.wasCorrupted = true;
                result.repairedKeys.push(config.key);
            }
        } catch (parseError) {
            // JSON corrupto - purgar
            console.warn(`❌ ${config.key}: JSON corrupto - PURGANDO`, parseError);
            localStorage.removeItem(config.key);
            result.wasCorrupted = true;
            result.repairedKeys.push(config.key);
        }
    }

    // Resumen
    if (result.wasCorrupted) {
        console.warn(`🔧 Reparación completada. Claves purgadas: ${result.repairedKeys.join(', ')}`);
    } else {
        console.log('✨ Todos los datos están íntegros');
    }

    console.groupEnd();

    return result;
}

/**
 * Hook composable para usar en componentes Vue.
 * Ejecuta la verificación y retorna el resultado reactivo.
 */
export function useDataIntegrity() {
    const integrityResult = checkDataIntegrity();

    return {
        wasCorrupted: integrityResult.wasCorrupted,
        repairedKeys: integrityResult.repairedKeys,
        validKeys: integrityResult.validKeys,
        checkDataIntegrity
    };
}

export default useDataIntegrity;
