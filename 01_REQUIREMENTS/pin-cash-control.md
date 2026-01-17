# 🔐 Control de Caja con PIN de Autorización

**ID:** SPEC-006  
**Prioridad:** Alta  
**Estado:** ✅ Aprobado para Implementación  
**Fecha:** 2026-01-16  
**Revisado por:** Architect, UX, Data, QA

---

## 1. Resumen Ejecutivo

Sistema de autorización por PIN para operaciones de apertura y cierre de caja, con historial de auditoría completo. El PIN se configura en la administración de cuenta (no en el registro inicial) y se valida en cada operación de caja.

### Decisiones de Negocio Aprobadas

| # | Decisión | Resolución |
|---|----------|------------|
| 1.1 | ¿Quién puede abrir/cerrar caja? | **Admin + Empleados con permiso `canOpenCloseCash`** |
| 1.2 | ¿Qué PIN usan empleados autorizados? | **Su propio PIN de 4 dígitos** (el de login) |
| 1.3 | ¿Múltiples ciclos por día? | **Sí** (cierre por almuerzo permitido) |
| 1.4 | ¿Cómo recuperar PIN olvidado? | **Validar contraseña del admin** |
| 1.5 | ¿Abrir sin cerrar día anterior? | **Advertir y permitir continuar** |
| 1.6 | ¿Empleado sin permiso ve botón? | **No** (oculto en UI) |

---

## 2. Política de Acceso por Rol

### 2.1 Matriz de Permisos

| Rol | PIN Usado | Longitud | Puede Abrir/Cerrar | Ve Botón |
|-----|-----------|----------|-------------------|----------|
| **Admin (Dueño)** | PIN de Caja propio | 6 dígitos | ✅ Siempre | ✅ Siempre |
| **Empleado con `canOpenCloseCash: true`** | Su PIN de login | 4 dígitos | ✅ Sí | ✅ Sí |
| **Empleado con `canOpenCloseCash: false`** | N/A | N/A | ❌ No | ❌ No (oculto) |

### 2.2 Nuevo Permiso de Empleados

```json
// Agregar a employees.permissions (JSONB)
{
  "canSell": true,
  "canViewInventory": true,
  "canViewReports": false,
  "canFiar": false,
  "canOpenCloseCash": false  // ← NUEVO
}
```

---

## 3. Cambios al Flujo de Registro

### 3.1 Eliminación del PIN del Formulario de Registro

| Antes | Después |
|-------|---------|
| Registro pedía: Nombre, Email, Contraseña, **PIN 6 dígitos** | Registro pide: Nombre, Email, Contraseña |
| PIN se creaba sin contexto de uso | PIN se crea cuando el usuario lo necesita |

**Justificación:** El PIN tiene un propósito específico (autorizar operaciones de caja). Pedirlo en el registro sin explicar su uso genera confusión.

### 3.2 Nueva Ubicación: Administración de Cuenta

El PIN se configura en una nueva sección dentro del perfil de administrador:

```
AdminHubView → Configuración de Cuenta → Seguridad → PIN de Caja
```

---

## 4. Flujo de Primera Vez (Onboarding)

Cuando el usuario intenta abrir caja por primera vez, el sistema ejecuta validaciones en cascada:

```
┌─────────────────────────────────────────────────────────────────┐
│ Usuario pulsa "Abrir Caja"                                      │
├─────────────────────────────────────────────────────────────────┤
│ VALIDACIÓN 0: ¿El usuario tiene permiso?                        │
│ ├─ Empleado sin canOpenCloseCash → Botón oculto (nunca llega)   │
│ └─ Admin o Empleado autorizado → Continuar                      │
├─────────────────────────────────────────────────────────────────┤
│ VALIDACIÓN 1: ¿Existe al menos 1 producto en inventario?        │
│ ├─ NO → Modal: "Registra tu primer producto antes de vender"    │
│ │         [Ir a Inventario]                                     │
│ └─ SÍ → Continuar                                               │
├─────────────────────────────────────────────────────────────────┤
│ VALIDACIÓN 2 (Solo Admin): ¿Tiene PIN configurado?              │
│ ├─ NO → Modal: "Configura tu PIN de Caja"                       │
│ │         - Keypad para crear PIN de 6 dígitos                  │
│ │         - Confirmar PIN (ingresar 2 veces)                    │
│ │         [Guardar PIN]                                         │
│ └─ SÍ → Continuar al flujo normal de apertura                   │
├─────────────────────────────────────────────────────────────────┤
│ VALIDACIÓN 3: ¿Existe caja anterior no cerrada?                 │
│ ├─ SÍ → Modal de advertencia:                                   │
│ │   "La caja del [fecha] no fue cerrada."                       │
│ │   [Cerrar Caja Anterior] [Continuar Sin Cerrar]               │
│ └─ NO → Continuar                                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Flujo de Apertura de Caja (2 Pantallas)

### 5.1 PANTALLA 1: Ingreso de Monto

```
1. Usuario pulsa botón "Abrir Caja"
2. Se muestra PANTALLA 1 (modal):
   ┌──────────────────────────────────────────┐
   │ 🏪 Apertura de Caja                    ✕ │
   │                                          │
   │ Monto inicial en caja:                   │
   │ ┌────────────────────────────────────┐   │
   │ │ $ 50.000                           │   │
   │ └────────────────────────────────────┘   │
   │                                          │
   │ [Keypad numérico 0-9]                    │
   │                                          │
   │ [🗑️ Borrar]              [✓ Aceptar]    │
   └──────────────────────────────────────────┘
3. Usuario ingresa monto con keypad
4. Botón "Borrar" → Limpia el campo completamente ($0)
5. Botón "Aceptar" → Avanza a PANTALLA 2
```

### 5.1.1 Validación de Monto $0

| Condición | Comportamiento |
|-----------|----------------|
| Monto = $0 | Modal de confirmación: "¿Abrir caja con $0? Esto es inusual." → [Cancelar] [Sí, Continuar] |
| Monto > 0 | Continúa normal |

### 5.2 PANTALLA 2: Confirmación con PIN

```
6. Se muestra PANTALLA 2 (mismo modal, nueva vista):
   ┌──────────────────────────────────────────┐
   │ 🔐 Confirmar Apertura                  ✕ │
   │                                          │
   │ Monto inicial: $50.000                   │
   │ ─────────────────────────────────────    │
   │                                          │
   │ Ingresa tu PIN:                          │
   │ ○ ○ ○ ○ ○ ○  (Admin: 6 dígitos)          │
   │ ○ ○ ○ ○      (Empleado: 4 dígitos)       │
   │                                          │
   │ [Keypad numérico 0-9]                    │
   │                                          │
   │ [← Volver]                               │
   └──────────────────────────────────────────┘
7. Usuario digita PIN
8. Al completar dígitos → Validación automática
9. Si PIN CORRECTO:
   ┌──────────────────────────────────────────┐
   │ ✅ ¡Caja Abierta!                        │
   │                                          │
   │ Monto inicial: $50.000                   │
   │ Registrado por: Juan Pérez               │
   │ Hora: 8:00 AM                            │
   │                                          │
   │ [Continuar]                              │
   └──────────────────────────────────────────┘
10. Si PIN INCORRECTO → Mensaje de error + Limpiar PIN
```

### 5.3 Comportamiento de Botones

| Botón | Acción |
|-------|--------|
| **✕ (Cerrar)** | Cancela operación y cierra modal |
| **Borrar** | Limpia el monto a $0 |
| **Aceptar** | Avanza a pantalla de PIN |
| **Volver** | Regresa a pantalla de monto (conserva el valor) |

---

## 6. Flujo de Cierre de Caja (2 Pantallas)

### 6.1 PANTALLA 1: Ingreso de Monto Contado

> **Cambio UX-01:** El "Efectivo esperado" NO se muestra aquí para evitar sesgo. Se muestra en Pantalla 2.

```
1. Usuario pulsa botón "Cerrar Caja"
2. Se muestra PANTALLA 1 (modal):
   ┌──────────────────────────────────────────┐
   │ 📋 Cierre de Caja                      ✕ │
   │                                          │
   │ Resumen del día:                         │
   │ • Ventas totales: $245.000               │
   │                                          │
   │ ¿Cuánto efectivo hay en caja?            │
   │ ┌────────────────────────────────────┐   │
   │ │ $ ________                         │   │
   │ └────────────────────────────────────┘   │
   │                                          │
   │ [Keypad numérico 0-9]                    │
   │                                          │
   │ [🗑️ Borrar]              [✓ Aceptar]    │
   └──────────────────────────────────────────┘
3. Usuario ingresa monto contado con keypad
4. Botón "Aceptar" → Avanza a PANTALLA 2
```

### 6.2 PANTALLA 2: Confirmación con PIN

> El monto esperado se revela DESPUÉS de que el usuario declaró el conteo.

```
6. Se muestra PANTALLA 2:
   ┌──────────────────────────────────────────┐
   │ 🔐 Confirmar Cierre                    ✕ │
   │                                          │
   │ Efectivo contado: $175.000               │
   │ Efectivo esperado: $180.000              │
   │ Diferencia: -$5.000 (Faltante)           │
   │ ─────────────────────────────────────    │
   │                                          │
   │ Ingresa tu PIN:                          │
   │ ○ ○ ○ ○ ○ ○                              │
   │                                          │
   │ [Keypad numérico 0-9]                    │
   │                                          │
   │ [← Volver]                               │
   └──────────────────────────────────────────┘
```

### 6.3 Visualización de Diferencia

| Diferencia | Color | Icono |
|------------|-------|-------|
| $0 (cuadrado) | Verde | ✅ |
| Positivo (sobrante) | Azul | ℹ️ |
| Negativo (faltante) | Rojo | ⚠️ |

---

## 7. Protección contra Fuerza Bruta

### 7.1 Límite de Intentos (Rate Limiting Exponencial)

| Intento | Bloqueo |
|---------|---------|
| 1-4 | Sin bloqueo, solo mensaje de error |
| 5 | **5 minutos** |
| 6 (después de desbloqueo) | **15 minutos** |
| 7+ | **1 hora** |

### 7.2 Comportamiento

```
Intento 1-4 (fallido):
  → "PIN incorrecto. Te quedan X intentos."
  → Limpiar campo PIN
  → Permitir reintentar

Intento 5 (fallido):
  → "Demasiados intentos. Espera 5 minutos."
  → Deshabilitar keypad
  → Mostrar contador regresivo

Timeout de red:
  → "Error de conexión. Intenta de nuevo."
  → NO cuenta como intento fallido
```

### 7.3 Notificación de Seguridad

> Al tercer intento fallido, enviar notificación al Admin (si es un empleado quien lo intenta).

---

## 8. Flujo "Olvidé mi PIN"

### 8.1 Ubicación

```
AdminHubView → Seguridad → Cambiar PIN de Caja → "¿Olvidaste tu PIN?"
```

### 8.2 Flujo

```
┌──────────────────────────────────────────┐
│ 🔐 Resetear PIN de Caja                  │
│                                          │
│ Ingresa tu contraseña actual:            │
│ ┌────────────────────────────────────┐   │
│ │ ••••••••••                         │   │
│ └────────────────────────────────────┘   │
│                                          │
│ [Cancelar]            [Continuar →]      │
└──────────────────────────────────────────┘
         ↓ (si contraseña correcta)
┌──────────────────────────────────────────┐
│ 🔑 Crea tu nuevo PIN de 6 dígitos        │
│                                          │
│ ○ ○ ○ ○ ○ ○                              │
│                                          │
│ [Keypad 0-9]                             │
│                                          │
│ Confirma tu nuevo PIN:                   │
│ ○ ○ ○ ○ ○ ○                              │
│                                          │
│ [Guardar Nuevo PIN]                      │
└──────────────────────────────────────────┘
```

---

## 9. Formulario para Cambiar PIN

### 9.1 Ubicación

```
AdminHubView → Mi Cuenta → Seguridad → Cambiar PIN de Caja
```

### 9.2 Flujo

```
┌──────────────────────────────────────────┐
│ 🔑 Cambiar PIN de Caja                   │
│                                          │
│ PIN actual:                              │
│ ○ ○ ○ ○ ○ ○                              │
│                                          │
│ Nuevo PIN:                               │
│ ○ ○ ○ ○ ○ ○                              │
│                                          │
│ Confirmar nuevo PIN:                     │
│ ○ ○ ○ ○ ○ ○                              │
│                                          │
│ [Cancelar]        [Guardar Cambios]      │
│                                          │
│ ¿Olvidaste tu PIN? →                     │
└──────────────────────────────────────────┘
```

### 9.3 Validaciones

| Validación | Mensaje de Error |
|------------|------------------|
| PIN actual incorrecto | "El PIN actual no es válido" |
| Nuevo PIN ≠ Confirmación | "Los PINs no coinciden" |
| Nuevo PIN = PIN actual | "El nuevo PIN debe ser diferente al actual" |

---

## 10. Estados de Error

| Escenario | Mensaje | Acción |
|-----------|---------|--------|
| PIN incorrecto | "PIN incorrecto. Te quedan X intentos." | Limpiar PIN, permitir reintentar |
| Cuenta bloqueada | "Demasiados intentos. Espera X minutos." | Mostrar countdown, deshabilitar keypad |
| Sin productos | "Registra tu primer producto antes de vender" | Botón [Ir a Inventario] |
| Sin PIN configurado | "Configura tu PIN de Caja" | Modal de configuración |
| Error de red | "Sin conexión. Intenta de nuevo." | NO cuenta como intento fallido |
| Caja ya abierta | "La caja ya está abierta" | Mostrar info de apertura actual |
| Caja ya cerrada | "La caja ya fue cerrada hoy" | Mostrar info de cierre |
| Caja anterior sin cerrar | "La caja del [fecha] no fue cerrada" | [Cerrar Anterior] [Continuar] |

---

## 11. Historial de Auditoría

### 11.1 Estructura de Tabla

```sql
CREATE TABLE IF NOT EXISTS cash_control_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('open', 'close')),
    
    -- Usuario que autorizó
    authorized_by_id UUID,
    authorized_by_type TEXT NOT NULL CHECK (authorized_by_type IN ('admin', 'employee')),
    authorized_by_name TEXT NOT NULL,
    
    -- Montos
    amount_declared DECIMAL(12,2) NOT NULL,
    amount_expected DECIMAL(12,2),
    difference DECIMAL(12,2),
    
    -- Metadatos
    pin_verified BOOLEAN DEFAULT true,
    device_fingerprint TEXT,
    ip_address INET,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 11.2 Múltiples Ciclos por Día

Los eventos se numeran automáticamente en el historial:
- Apertura #1: 8:00 AM
- Cierre #1: 12:00 PM (almuerzo)
- Apertura #2: 2:00 PM
- Cierre #2: 8:00 PM (fin del día)

---

## 12. Impacto en el Sistema

### 📂 Archivos a Modificar

| Capa | Archivo | Cambio |
|------|---------|--------|
| **Registro** | `RegisterStoreView.vue` | Eliminar campo PIN |
| **Registro** | `register-store.md` | Actualizar documentación |
| **Auth Store** | `auth.ts` | Eliminar `pin` de `StoreAccount` |
| **Employees Store** | `employees.ts` | Agregar permiso `canOpenCloseCash` |
| **Admin Hub** | `AdminHubView.vue` | Agregar sección "Seguridad" |
| **Nuevo** | `PinSetupModal.vue` | Modal para crear/cambiar PIN |
| **Nuevo** | `CashControlModal.vue` | Modal unificado apertura/cierre |
| **Nuevo** | `PinResetModal.vue` | Modal para recuperar PIN |
| **DB Schema** | `supabase-schema.sql` | Agregar tabla y campos |

### 📂 Nuevas Funciones RPC

| RPC | Descripción |
|-----|-------------|
| `validar_pin_admin()` | Valida PIN del dueño con rate limiting |
| `establecer_pin_admin()` | Crea o cambia PIN del dueño |
| `registrar_evento_caja()` | Registra apertura/cierre con auditoría |

---

## 13. Criterios de Aceptación

### Registro
- [ ] El formulario de registro NO pide PIN
- [ ] El usuario puede completar registro sin PIN

### Permisos
- [ ] Empleado sin `canOpenCloseCash` NO ve botón de apertura/cierre
- [ ] Empleado con permiso puede abrir/cerrar usando su PIN de 4 dígitos
- [ ] Admin usa PIN de 6 dígitos

### Primera Vez
- [ ] Al intentar abrir caja sin productos → Mensaje + Redirección a inventario
- [ ] Al intentar abrir caja sin PIN (Admin) → Modal de configuración
- [ ] El PIN debe ingresarse 2 veces para confirmar

### Apertura de Caja
- [ ] Modal Pantalla 1: Solo monto (sin "Efectivo esperado")
- [ ] Modal Pantalla 2: Monto confirmado + PIN
- [ ] Al completar PIN, validación automática
- [ ] PIN correcto → Caja se abre + Evento registrado + Mensaje éxito
- [ ] PIN incorrecto → Mensaje de error + Campo se limpia

### Cierre de Caja
- [ ] Modal Pantalla 1: Resumen + monto contado (SIN mostrar esperado)
- [ ] Modal Pantalla 2: Diferencia visible + PIN
- [ ] Se calcula y muestra la diferencia (faltante/sobrante)

### Seguridad
- [ ] Después de 5 intentos fallidos → Bloqueo exponencial
- [ ] El contador de intentos se muestra al usuario
- [ ] El PIN se almacena hasheado (nunca en texto plano)
- [ ] Error de red NO cuenta como intento fallido
- [ ] Notificación al Admin al 3er intento fallido de empleado

### Recuperación de PIN
- [ ] Existe flujo "Olvidé mi PIN"
- [ ] Requiere contraseña del admin para resetear
- [ ] Nuevo PIN debe confirmarse 2 veces

### Historial
- [ ] Cada apertura genera registro en `cash_control_events`
- [ ] Cada cierre incluye diferencia calculada
- [ ] Múltiples ciclos por día permitidos y numerados

---

## 14. Conexiones con Documentación

- **Autenticación:** [auth-unificada-iam.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/01_REQUIREMENTS/auth-unificada-iam.md)
- **Registro actual:** [register-store.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/01_REQUIREMENTS/register-store.md)
- **Control de caja actual:** [cash-control.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/01_REQUIREMENTS/cash-control.md)
- **Protocolos de seguridad:** [SECURITY_PROTOCOLS.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/02_ARCHITECTURE/SECURITY_PROTOCOLS.md)
- **Discusión de revisión:** [spec-006-review.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/01_REQUIREMENTS/discussions/spec-006-review.md)
- **Auditoría QA:** [spec-006-qa-audit.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/01_REQUIREMENTS/discussions/spec-006-qa-audit.md)

---

## 15. Registro de Aprobaciones

| Rol | Nombre | Fecha | Estado |
|-----|--------|-------|--------|
| Arquitecto Producto | Agente Architect | 2026-01-16 | ✅ Aprobado |
| UX/UI Designer | Agente UX | 2026-01-16 | ✅ Aprobado |
| Data Architect | Agente Data | 2026-01-16 | ✅ Aprobado |
| QA y Auditoría | Agente QA | 2026-01-16 | ✅ Aprobado |
