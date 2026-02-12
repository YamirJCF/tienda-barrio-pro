# Guía de Despliegue en Vercel (Paso a Paso)

Sigue estos pasos cuidadosamente para desplegar la versión `v1.1.0` sin errores.

## 1. Importar Proyecto
1. En el dashboard de Vercel, haz clic en **"Importar"** (o "Add New..." > "Project").
2. Selecciona tu proveedor de Git (GitHub, GitLab, etc.).
3. Busca el repositorio `tienda-barrio-pro` y haz clic en **Import**.

## 2. Configuración del Proyecto (⚠️ CRÍTICO)

Esta es la parte donde ocurren el 90% de los errores. Asegúrate de configurar esto exactamente así:

### A. Directorio Raíz (Root Directory)
Vercel intentará detectar el proyecto. Como tu código está en una subcarpeta:
- Haz clic en **Edit** junto a "Root Directory".
- Selecciona la carpeta **`frontend`**.
- **NO** lo dejes en la raíz (`/`).

### B. Framework Preset
- Debería detectar automáticamente **Vite**. Si no, selecciónalo manualment.

### C. Build and Output Settings
(Si seleccionaste Vite, esto se llena solo, pero verifica):
- **Build Command:** `npm run build`
- **Output Directory:** `dist`

### D. Variables de Entorno (Environment Variables)
Despliega la sección "Environment Variables" y agrega las siguientes claves (copia los valores de tu `.env` local o de Supabase):

| Clave (Key) | Valor (Value) |
|---|---|
| `VITE_SUPABASE_URL` | *Tu URL de Supabase* |
| `VITE_SUPABASE_ANON_KEY` | *Tu Anon Key de Supabase* |
| `VITE_SUPABASE_ENABLED` | `true` |

> **Nota:** No agregues claves de Gemini ni otras si no las estás usando en el frontend (recuerda que eliminamos el uso directo de API Keys).

### E. Configurar URL del Sitio (Site URL) - ⚠️ CRÍTICO PARA REDIRECCIONES
Para que los correos de confirmación y recuperación de contraseña funcionen (y no te manden a `localhost`):
1.  En Vercel, copia la **URL de tu despliegue** (ej. `https://tienda-barrio-pro.vercel.app`).
2.  Agrega esta URL como variable de entorno `VITE_SITE_URL` en Vercel (opcional, pero recomendado).

## 3. Configuración en Supabase (OBLIGATORIO)

Para corregir el error de "redirección a localhost":

1.  Ve a tu Dashboard de Supabase.
2.  Entra a **Authentication** > **URL Configuration**.
3.  En **Site URL**, pega la URL de tu proyecto en Vercel (ej. `https://tienda-barrio-pro.vercel.app`).
4.  En **Redirect URLs**, asegúrate de agregar también:
    -   `https://tienda-barrio-pro.vercel.app/`
    -   `https://tienda-barrio-pro.vercel.app/**`
5.  Guarda los cambios.


## 4. Desplegar
1. Haz clic en **Deploy**.
2. Espera a que termine el build (debería tomar ~1-2 minutos).
3. Si ves fuegos artificiales 🎊, ¡Felicidades!


## 6. Personalización de Correos (Para que dejen de verse en inglés)

Hemos creado plantillas profesionales en español para que tus correos se vean bien.

1.  Ve a `documentation/email_templates` en este proyecto para ver los códigos HTML.
2.  Ve al Dashboard de Supabase > **Authentication** > **Email Templates**.

### A. Confirmar Registro (Confirm Signup)
-   **Subject**: `Confirma tu cuenta en Tienda de Barrio Pro`
-   **Body**: Copia el contenido de `documentation/email_templates/confirm_signup.html` y pégalo en la pestaña "Source".

### B. Recuperar Contraseña (Reset Password)
-   **Subject**: `Restablece tu contraseña - Tienda de Barrio Pro`
-   **Body**: Copia el contenido de `documentation/email_templates/reset_password.html` y pégalo en la pestaña "Source".

### C. Invitación de Usuario (Invite User)
-   **Subject**: `Te han invitado a Tienda de Barrio Pro`
-   **Body**: Copia el contenido de `documentation/email_templates/invite_user.html` y pégalo en la pestaña "Source".


Si quieres cambiar la dirección `tienda-barrio-pro.vercel.app`, tienes dos opciones:

### A. Cambiar solo el subdominio (Gratis)
Si solo quieres cambiar el nombre (ej. `mi-tienda-nueva.vercel.app`):
1. Ve a **Settings > Domains**.
2. Haz clic en el botón **"Edit"** del dominio actual.
3. Escribe el nuevo nombre y dale a **Save**.
4. Vercel actualizará la URL automáticamente.

### B. Agregar un Dominio Propio (ej. `.com`, `.com.co`)
Si compraste un dominio en otro sitio (GoDaddy, Namecheap, etc.):
1. Ve a **Settings > Domains**.
2. Escribe tu dominio (ej. `www.mitienda.com`) y dale a **Add**.
3. Vercel te dará unos registros **DNS** (A y CNAME).
4. Copia esos valores en el panel de control de donde compraste el dominio.
5. Espera unos minutos a que se propaguen y ¡listo!
