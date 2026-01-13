# Recuperación de Contraseña (ForgotPasswordView)

## Descripción
Vista para solicitar la recuperación de contraseña mediante correo electrónico. Permite a los usuarios que olvidaron su contraseña recibir un enlace seguro para restablecerla.

## Ruta
`/forgot-password`

---

## Flujo de Usuario

### Solicitar Recuperación
1. Usuario accede desde Login → "¿Olvidaste tu contraseña?"
2. Ve formulario con campo de correo electrónico
3. Ingresa el email asociado a su tienda
4. Click **"Enviar Enlace de Recuperación"**
5. Sistema muestra spinner de carga (1.5s simulado)
6. Vista cambia a estado de éxito

### Estado de Éxito
1. Usuario ve confirmación: "¡Correo enviado!"
2. Instrucciones: "Revisa tu bandeja de entrada (y spam)"
3. Click **"Volver al inicio"** → Redirige a Login

---

## Estados de la Vista

| Estado | Condición | Contenido |
|--------|-----------|-----------|
| **Input** | `isSuccess === false` | Formulario de email |
| **Éxito** | `isSuccess === true` | Confirmación de envío |

---

## Campo del Formulario

| Campo | ID | Tipo | Placeholder | Validación HTML |
|-------|----|------|-------------|-----------------|
| Email | `email` | `email` | "ejemplo@tienda.com" | `required` |

---

## Estado Interno

| Estado | Tipo | Valor Inicial | Descripción |
|--------|------|---------------|-------------|
| `email` | `string` | `''` | Email ingresado por usuario |
| `isSuccess` | `boolean` | `false` | ¿Se envió el correo? |
| `isLoading` | `boolean` | `false` | ¿Procesando solicitud? |

---

## Métodos

| Método | Descripción |
|--------|-------------|
| `handleSubmit()` | Simula envío de email y cambia a estado de éxito |
| `goBackToLogin()` | Navega a `/login` |
| `goToHome()` | Navega a `/login` |

---

## Lógica de Envío

```typescript
handleSubmit() {
    if (!email) return;
    
    isLoading = true;
    
    // Simula llamada a API (1.5 segundos)
    await delay(1500);
    
    isLoading = false;
    isSuccess = true;
    
    console.log('Password recovery email sent to:', email);
}
```

> [!NOTE]
> Actualmente la lógica es **simulada**. No hay integración real con backend para envío de emails.

---

## Navegación

### Desde
| Origen | Acción | Ruta |
|--------|--------|------|
| Login | Click "¿Olvidaste tu contraseña?" | `/forgot-password` |

### Hacia
| Destino | Acción | Ruta |
|---------|--------|------|
| Login | "Volver al Login" (formulario) | `/login` |
| Login | "Volver al inicio" (éxito) | `/login` |

---

## Diseño Visual

### Estado Input
| Elemento | Descripción |
|----------|-------------|
| Línea decorativa | Barra azul (primary) en la parte superior |
| Icono | `lock_open` en círculo azul |
| Título | "Recuperar Acceso" |
| Descripción | Explicación del proceso |
| Campo email | Input con icono de sobre |
| Botón primario | "Enviar Enlace de Recuperación" |
| Botón secundario | "Volver al Login" |

### Estado Éxito
| Elemento | Descripción |
|----------|-------------|
| Línea decorativa | Barra verde en la parte superior |
| Icono | `check_circle` en círculo verde |
| Título | "¡Correo enviado!" |
| Descripción | "Revisa tu bandeja de entrada (y spam)" |
| Botón | "Volver al inicio" |

---

## Estados de Carga

| Estado | Comportamiento |
|--------|---------------|
| `isLoading = false` | Botón muestra texto normal |
| `isLoading = true` | Botón muestra spinner + deshabilitado |

---

## Animaciones

| Elemento | Animación |
|----------|-----------|
| Estado éxito | `fadeIn` (0.3s ease-out) |
| Botón submit | `scale(0.98)` al hacer click |

---

## Stores Utilizados
- Ninguno (flujo simulado)

---

## Limitaciones Actuales

> [!WARNING]
> Esta vista es actualmente un **mock/placeholder**:
> - No envía emails reales
> - No valida si el email existe en el sistema
> - No genera tokens de recuperación
> 
> Para producción requiere:
> - Integración con `authStore` para validar email
> - Backend con servicio de email (SendGrid, etc.)
> - Generación y validación de tokens seguros
> - Vista adicional para restablecer contraseña con token
