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

## 3. Desplegar
1. Haz clic en **Deploy**.
2. Espera a que termine el build (debería tomar ~1-2 minutos).
3. Si ves fuegos artificiales 🎊, ¡Felicidades!

## 4. Verificación Post-Deploy
1. Entra a la URL que te da Vercel.
2. Intenta hacer Login.
3. Verifica que NO aparezcan errores de "Connection refused" en la consola.
