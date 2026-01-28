# TECH_SPEC: Implementación de Manejo de Errores

> **Basado en:** FRD_011_MANEJO_ERRORES  
> **Audiencia:** Equipo de Desarrollo  
> **Fecha:** 2026-01-27

---

## Propósito

Este documento especifica los detalles técnicos de implementación para el manejo de errores definido en FRD_011. Contiene constantes, patrones de código y estructura de datos.

---

## Constantes del Sistema

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `OFFLINE_NOTIFICATION_DELAY` | `60000` (ms) | Tiempo antes de notificar "sin internet" |
| `MAX_RETRY_ATTEMPTS` | `3` | Intentos máximos de reenvío |
| `SYNC_CHECK_INTERVAL` | `5000` (ms) | Frecuencia de verificación de conexión |
| `NOTIFICATION_DURATION_SUCCESS` | `3000` (ms) | Duración de notificaciones de éxito |
| `NOTIFICATION_DURATION_WARNING` | `0` (persistente) | Duración de notificaciones de advertencia |

---

## Códigos de Error

| Código | Tipo | Acción del Sistema |
|--------|------|-------------------|
| `NETWORK_ERROR` | Conectividad | Activar modo offline + temporizador |
| `INSUFFICIENT_STOCK` | Negocio | Mostrar stock disponible |
| `CREDIT_LIMIT_EXCEEDED` | Negocio | Mostrar cupo disponible |
| `ACCOUNT_DISABLED` | Acceso | Cerrar sesión local → Redirigir inicio |
| `VALIDATION_ERROR` | Datos | Resaltar campo con error |
| `DATA_CORRUPTION` | Sistema | Reparar/Resetear + Notificar |
| `UNKNOWN_ERROR` | Sistema | Log interno + Mensaje genérico |

---

## Patrones de Implementación

### 1. Idempotencia de Ventas

```typescript
// Generar UUID antes de enviar
const saleId = crypto.randomUUID();

// Incluir en payload
await processSale({ saleId, items, paymentMethod });

// Backend debe verificar existencia antes de crear
```

```sql
-- Validación en backend
IF EXISTS (SELECT 1 FROM sales WHERE id = p_sale_id) THEN
  RETURN (SELECT row_to_json(s) FROM sales s WHERE id = p_sale_id);
END IF;
-- Continuar con creación...
```

### 2. Handler Global de Errores

```typescript
// main.ts
app.config.errorHandler = (err, vm, info) => {
  // Log interno (nunca al usuario)
  console.error('[Global Error]', err, info);
  
  // Mensaje genérico
  showToast({
    type: 'error',
    message: 'Ocurrió un error inesperado. Por favor, intenta de nuevo.',
    actions: [
      { label: 'Reintentar', action: () => location.reload() },
      { label: 'Volver al inicio', action: () => router.push('/') }
    ]
  });
};
```

### 3. Sanitización de Datos Locales

```typescript
function sanitizeStore(storeKey: string): void {
  try {
    const data = localStorage.getItem(storeKey);
    const parsed = JSON.parse(data);
    
    // Intentar reparar
    const repaired = parsed.filter(item => isValid(item));
    
    if (repaired.length < parsed.length) {
      localStorage.setItem(storeKey, JSON.stringify(repaired));
      notify("Se corrigieron algunos datos locales");
    }
  } catch (e) {
    // Corrupto irrecuperable: resetear
    localStorage.removeItem(storeKey);
    notify("Detectamos un problema. Algunos datos se reiniciaron.");
    logError(storeKey, e);
  }
}
```

### 4. Temporizador de Notificación Offline

```typescript
let offlineTimer: number | null = null;
let offlineNotificationShown = false;

function onNetworkLost(): void {
  // Activar modo offline inmediatamente
  setOfflineMode(true);
  
  // Iniciar temporizador
  offlineTimer = window.setTimeout(() => {
    showNotification({
      type: 'warning',
      message: 'Estás trabajando sin internet',
      persistent: true
    });
    offlineNotificationShown = true;
  }, OFFLINE_NOTIFICATION_DELAY); // 60000ms
}

function onNetworkRestored(): void {
  // Cancelar temporizador si existe
  if (offlineTimer) {
    clearTimeout(offlineTimer);
    offlineTimer = null;
  }
  
  // Solo notificar si se mostró la advertencia
  if (offlineNotificationShown) {
    showNotification({
      type: 'success',
      message: 'Conexión restablecida',
      duration: 5000
    });
    offlineNotificationShown = false;
  }
  
  // Sincronizar pendientes
  syncPendingSales();
}
### 5. Validación de Estado de Cuenta

```typescript
// En cada llamada al servidor (wrapper de Supabase)
async function callRPC(functionName: string, params: any): Promise<any> {
  const response = await supabase.rpc(functionName, params);
  
  if (response.error?.code === 'ACCOUNT_DISABLED') {
    // Cerrar sesión local
    authStore.clearSession();
    
    // Notificar
    showToast({
      type: 'error',
      message: 'Tu cuenta ha sido desactivada'
    });
    
    // Redirigir
    router.push('/');
    
    throw new AccountDisabledError();
  }
  
  return response;
}
```

```sql
-- En CADA RPC del backend (validar al inicio)
CREATE OR REPLACE FUNCTION rpc_any_operation(...)
RETURNS ...
AS $$
DECLARE
  v_employee_status TEXT;
BEGIN
  -- Validar estado del empleado
  SELECT status INTO v_employee_status
  FROM employees
  WHERE user_id = auth.uid();
  
  IF v_employee_status IS NOT NULL AND v_employee_status != 'active' THEN
    RAISE EXCEPTION 'ACCOUNT_DISABLED';
  END IF;
  
  -- Continuar con operación normal...
END;
$$ LANGUAGE plpgsql;
```

---

## Estructura de Respuesta de Errores (Backend)

```typescript
interface ErrorResponse {
  success: false;
  code: string;          // Código de error (ver tabla)
  message?: string;      // Mensaje técnico (solo para logs)
  data?: {               // Datos contextuales
    [key: string]: any;
  };
}

// Ejemplo: Stock insuficiente
{
  success: false,
  code: "INSUFFICIENT_STOCK",
  data: {
    productId: "abc-123",
    productName: "Arroz Diana 1kg",
    requested: 5,
    available: 2
  }
}
```

---

## Archivos Afectados

| Archivo | Modificación |
|---------|--------------|
| `main.ts` | Handler global de errores |
| `useNotifications.ts` | Notificaciones de conexión |
| `salesStore.ts` | Generación de UUID, cola offline |
| `useDataIntegrity.ts` | Sanitización con notificación |
| `authStore.ts` | Manejo de ACCOUNT_DISABLED |
| `supabaseClient.ts` | Detección de timeout, wrapper RPC |

---

## Pruebas Sugeridas

| Escenario | Método |
|-----------|--------|
| Modo offline | Desactivar red en DevTools |
| Venta duplicada | Enviar misma venta 2 veces |
| Stock agotado | Modificar stock entre agregar y pagar |
| Cuenta desactivada | Desactivar empleado y operar con su sesión |
| Datos corruptos | Modificar localStorage manualmente |
