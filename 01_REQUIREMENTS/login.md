# Login (LoginView)

## Descripción
Pantalla de autenticación unificada que soporta acceso tanto para Dueños/Admins como para Empleados usando el mismo formulario.

## Ruta
`/login`

---

## Flujo de Autenticación (Cascada de Validación)

> [!IMPORTANT]
> **SPEC-005 (Próxima versión):** Este flujo será reemplazado por el sistema de autenticación unificada con Gatekeeper de 3 capas e integración IAM. Ver [auth-unificada-iam.md](file:///c:/Users/Windows%2011/OneDrive/Desktop/prueba/01_REQUIREMENTS/auth-unificada-iam.md)

La lógica de login sigue un patrón de **cascada** con 3 pasos:

```
1. ¿Existe tienda registrada? → No → Error "No se detecta tienda"
                              ↓ Sí
2. ¿Es Admin (email+password)? → Sí → loginAsAdmin() → Dashboard
                              ↓ No
3. ¿Es Empleado (username+pin)? → Sí → loginAsEmployee() → Dashboard
                              ↓ No
4. Error "Credenciales inválidas"
```

---

## Flujo de Usuario

### Paso 1: Validación Preventiva
- Sistema verifica `authStore.hasStores`
- Si no hay tiendas registradas → Error inmediato
- Esto protege contra uso en dispositivos sin configurar

### Paso 2: Intento de Login como Admin
1. Usuario ingresa **email** y **contraseña**
2. Sistema llama `authStore.loginWithCredentials(email, password)`
3. Si coincide → Login como Admin → Redirige a Dashboard (`/`)

### Paso 3: Fallback a Empleado
1. Si Admin falla, sistema busca la primera tienda registrada
2. Llama `employeesStore.validatePin(username, password)`
3. Si el empleado existe y PIN coincide → Login como Empleado
4. Redirige a Dashboard (`/`)

### Paso 4: Error Final
Si ambos intentos fallan → Mensaje de error genérico

---

## Campos del Formulario

| Campo | Tipo | Placeholder | Uso |
|-------|------|-------------|-----|
| `username` | `text` | "Tu usuario o correo" | Email (admin) o username (empleado) |
| `password` | `password` | "••••••••" | Contraseña (admin) o PIN (empleado) |

> [!NOTE]
> El mismo campo `password` acepta tanto contraseñas alfanuméricas (Admin) como PINs numéricos (Empleado).

---

## Datos de Entrada

| Campo | Tipo | Validación UI |
|-------|------|---------------|
| `username` | `Ref<string>` | Ninguna explícita |
| `password` | `Ref<string>` | Ninguna explícita |

---

## Datos de Salida (Hacia Stores)

### useAuthStore
| Método | Parámetros | Retorno | Descripción |
|--------|------------|---------|-------------|
| `loginWithCredentials()` | `email, password` | `boolean` | Valida admin |
| `loginAsEmployee()` | `employee, storeId` | `boolean` | Autentica empleado |
| `getFirstStore()` | - | `StoreAccount \| null` | Obtiene primera tienda |
| `hasStores` | - | `boolean` (computed) | Verifica existencia |

### useEmployeesStore
| Método | Parámetros | Retorno | Descripción |
|--------|------------|---------|-------------|
| `validatePin()` | `username, pin` | `Employee \| null` | Valida credenciales empleado |

---

## Estados de Error

| Condición | Mensaje |
|-----------|---------|
| No hay tiendas registradas | "No se detecta una tienda registrada en este dispositivo." |
| Admin y Empleado fallan | "Credenciales inválidas o cuenta no autorizada" |

---

## Navegación

### Desde
| Origen | Condición |
|--------|-----------|
| Logout | `authStore.logout()` |
| Sesión expirada | Router guard |
| Splash | Primera carga sin autenticación |

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Dashboard | Login exitoso | `/` |
| Recuperar Contraseña | Click "¿Olvidaste tu contraseña?" | `/forgot-password` |
| Registro | Click "Crea tu tienda aquí" | `/register-store` |

---

## Diferencias de Acceso por Rol

| Aspecto | Admin (Dueño) | Empleado |
|---------|---------------|----------|
| Credenciales | Email + Contraseña | Username + PIN |
| Validación | `authStore.loginWithCredentials` | `employeesStore.validatePin` |
| `currentUser.type` | `'admin'` | `'employee'` |
| Permisos | Todos (implícito) | Basados en `employee.permissions` |

---

## Secuencia de Login (Código)

```typescript
handleLogin() {
    // 1. Guard: ¿Existe tienda?
    if (!authStore.hasStores) {
        error = "No se detecta tienda";
        return;
    }

    // 2. Intento Admin
    if (authStore.loginWithCredentials(username, password)) {
        router.push('/');
        return;
    }

    // 3. Fallback Empleado
    const store = authStore.getFirstStore();
    const employee = employeesStore.validatePin(username, password);
    if (employee) {
        authStore.loginAsEmployee(employee, store.id);
        router.push('/');
        return;
    }

    // 4. Error
    error = "Credenciales inválidas";
}
```

---

## Componentes UI

- Icono de tienda (lucide `Store`)
- Input de usuario con icono (lucide `User`)
- Input de contraseña con toggle de visibilidad (lucide `Lock`, `Eye`, `EyeOff`)
- Mensaje de error con fondo rojo
- Botón "Ingresar"
- Links a recuperar contraseña y registro

---

## Estados de Carga

| Estado | Comportamiento |
|--------|---------------|
| `isLoading = true` | Delay de 300ms para UX |
| Error mostrado | `isLoading = false` |

---

## Stores Utilizados
- `useAuthStore`
- `useEmployeesStore`

---

## Conexión con Registro

Si el usuario no tiene cuenta, hay un enlace a `/register-store` con el texto "Crea tu tienda aquí".
