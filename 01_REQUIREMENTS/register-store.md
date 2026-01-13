# Registro de Tienda (RegisterStoreView)

## Descripción
Vista de onboarding para crear una nueva cuenta de tienda. Permite a un nuevo dueño registrar su negocio con credenciales de acceso y un PIN de seguridad.

## Ruta
`/register` (inferida del flujo de autenticación)

---

## Flujo de Usuario

### Proceso de Registro (3 Pasos)

**Paso 1: Tu Negocio**
1. Usuario ingresa **Nombre de la Tienda** (aparecerá en recibos)
2. Usuario ingresa **Nombre del Dueño**

**Paso 2: Tus Credenciales**
3. Usuario ingresa **Correo Electrónico**
4. Usuario ingresa **Contraseña** (mínimo 6 caracteres)

**Paso 3: Seguridad**
5. Usuario crea **PIN de 6 dígitos** usando el keypad visual
6. Click en **"Abrir mi Tienda"**
7. Sistema valida y registra la tienda
8. Auto-login como Admin → Redirige a Dashboard (`/`)

---

## Campos del Formulario

| Campo | ID | Tipo | Validación | Mensaje Helper |
|-------|-----|------|------------|----------------|
| Nombre Tienda | `storeName` | `text` | Mín. 3 caracteres | "Así aparecerá en tus recibos digitales" |
| Nombre Dueño | `ownerName` | `text` | Requerido (> 0 chars) | "Para dirigirnos a ti personalmente" |
| Email | `email` | `email` | Regex válido | - |
| Contraseña | `password` | `password` | Mín. 6 caracteres | "Mínimo 6 caracteres" |
| PIN | `pin` | `keypad` | Exactamente 6 dígitos | "Tu llave rápida para abrir la tienda" |

---

## Reglas de Validación

```typescript
// Regex de email
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Validaciones computadas
isStoreNameValid = storeName.trim().length >= 3
isOwnerNameValid = ownerName.trim().length > 0
isEmailValid     = emailRegex.test(email.trim())
isPasswordValid  = password.length >= 6
isPinComplete    = /^\d{6}$/.test(pin)

// Formulario puede enviarse
canSubmit = isStoreNameValid && isOwnerNameValid && isEmailValid 
            && isPasswordValid && isPinComplete && !isLoading
```

---

## Datos de Salida (Hacia Stores)

### useAuthStore

| Método | Parámetros | Descripción |
|--------|------------|-------------|
| `registerStore()` | `{ storeName, ownerName, email, password, pin }` | Crea nueva tienda y auto-login |

---

## Estructura de StoreAccount

```typescript
interface StoreAccount {
    id: string;          // Auto-generado
    storeName: string;
    ownerName: string;
    email: string;
    password: string;
    pin: string;
    createdAt: string;   // ISO timestamp
}
```

---

## Lógica de Registro (authStore.registerStore)

1. **Verificación de duplicados**: Compara email en minúsculas
2. Si email existe → Retorna `null`
3. Si email es nuevo:
   - Genera ID único
   - Crea objeto `StoreAccount`
   - Agrega al array `stores`
   - **Auto-login como Admin** via `loginAsAdmin()`
4. Retorna el objeto `StoreAccount` creado

### Auto-Login Post-Registro

```typescript
// Método interno
loginAsAdmin(store: StoreAccount) {
    currentUser = {
        id: store.id,
        name: store.ownerName,
        email: store.email,
        type: 'admin',
        storeId: store.id
    };
    isAuthenticated = true;
}
```

---

## Estados de Error

| Error | Trigger | Mensaje UI |
|-------|---------|------------|
| Email duplicado | `registerStore()` retorna `null` | "Este correo electrónico ya está registrado." |
| Error de sistema | Exception en localStorage | "Error del sistema. Por favor, intenta nuevamente." |

---

## Navegación

### Desde
| Origen | Acción | Ruta |
|--------|--------|------|
| Login | Click "Crear cuenta" | `/register` |
| Splash | Primera carga sin tiendas | `/register` |

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Anterior | Botón ← | `router.back()` |
| Dashboard | Registro exitoso | `/` |

---

## Componentes UI

### Keypad de PIN
- Grid 3x4 (números 1-9, espacio vacío, 0, backspace)
- Display de 6 círculos para visualizar PIN ingresado
- Indicador visual del dígito actual
- Animación `popIn` al ingresar cada dígito

### Interacción del Keypad

| Tecla | Acción |
|-------|--------|
| `0-9` | Agrega dígito si `pin.length < 6` |
| `backspace` | Elimina último dígito |

---

## Feedback Visual

| Estado del Campo | Indicador |
|------------------|-----------|
| Nombre tienda válido | Ícono ✓ verde a la derecha |
| PIN completo | 6 círculos verdes llenos |
| Botón habilitado | Verde esmeralda con sombra |
| Botón deshabilitado | Gris sin sombra |

---

## Estados de Carga

| Estado | Comportamiento |
|--------|---------------|
| `isLoading = true` | Botón deshabilitado, previene doble-click |
| Delay 600ms | Asegura que localStorage complete escritura |

---

## Stores Utilizados
- `useAuthStore`

## Persistencia
```typescript
persist: {
    key: 'tienda-auth'
}
```

---

## Términos de Servicio
Al crear cuenta, el usuario acepta los términos de servicio (link en texto inferior).
