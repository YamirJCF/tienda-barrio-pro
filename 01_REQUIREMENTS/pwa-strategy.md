# Documento de Requisitos Funcionales (FRD)

## PWA Strategy: "App Instalable y Offline-Ready"

> **Rol:** @[/architect]
> **Estado:** FINAL (Especificación Aprobada)
> **Versión:** 1.0

### 1. Descripción
Transformar la aplicación web en una **Progressive Web App (PWA)**. Esto permitirá que los usuarios (dueños y cajeros) **instalen** la tienda en sus dispositivos (Android, iOS, Windows) como si fuera una app nativa, sin pasar por App Stores, y (futuramente) operar sin internet.

### 2. Reglas de Negocio

1.  **Instalación Universal**: La app debe ser instalable desde el navegador (Chrome/Safari/Edge) en cualquier S.O.
2.  **Modo Standalone**: Al abrirse instalada, NO debe mostrar barra de direcciones ni botones de navegador. Debe parecer nativa.
3.  **Offline Shell**: La interfaz gráfica (esqueleto) debe cargar instantáneamente incluso sin internet. (Los datos pueden requerir conexión inicialmente).
4.  **Actualización Silenciosa**: El usuario debe recibir mejoras sin tener que "bajar" nada nuevo manualmente.

### 3. Especificaciones Técnicas (The "Manifesto")

Para que el navegador habilite el botón "Instalar", debemos cumplir con el **Web Manifest**:

#### A. Identidad de App
| Propiedad | Valor | Razón |
|-----------|-------|-------|
| `name` | "Tienda de Barrio Pro" | Nombre completo en splash screen. |
| `short_name` | "TiendaPro" | Nombre en icono de home screen (max 12 chars). |
| `theme_color` | `#ffffff` | Color de la barra de estado del sistema. |
| `background_color` | `#ffffff` | Color de fondo mientras carga la app. |
| `display` | `standalone` | Elimina la UI del navegador. |
| `orientation` | `portrait` | Bloquea rotación (ideal para POS móvil) o `any`. |

#### B. Iconografía (Assets Requeridos)
Necesitamos generar iconos en múltiples tamaños (Png):
- 192x192 (Android Home)
- 512x512 (Splash Screen)
- 64x64 (Favicon)
- *Maskable Icon* (Para que Android lo recorte en círculo/cuadrado adaptativo).

#### C. Service Worker (Especificación de Caché Estricta)
Usaremos `vite-plugin-pwa` con `workbox`. La configuración DEBE seguir estas reglas literales:

**1. Precaching (Instalación)**
Se descargarán e instalarán **inmediatamente** los siguientes archivos al visitar la web por primera vez:
- `index.html`
- `*.js` (Lógica de aplicación)
- `*.css` (Estilos)
- `*.woff2` (Fuentes)
- `*.ico`, `*.png`, `*.svg` (Assets en `/public` y `/assets`)

**2. Runtime Caching (Reglas en Ejecución)**
Se deben configurar los siguientes handlers en orden de prioridad:

| Prioridad | Recurso (Regex) | Estrategia | Razón Técnica |
|-----------|-----------------|------------|---------------|
| **1 (Alta)** | `^https://.*supabase\\.co/.*` | **NetworkOnly** | ⛔ **PROHIBIDO CACHEAR API**. Datos de inventario/ventas deben ser siempre frescos. Si falla la red, el fetch debe fallar para que la App maneje el error, no servir un JSON viejo. |
| **2** | `^https://.*googleapis\\.com/.*` | **StaleWhileRevalidate** | Fuentes de Google Fonts. |
| **3** | `.*\.(png|jpg|jpeg|svg|gif|webp)$` | **CacheFirst** | Imágenes de productos. Expiración: 30 días. Max Entries: 100. |
| **4 (Baja)** | `.*` (Cualquier otro) | **NetworkFirst** | Fallback seguro. |

> **⚠️ ADVERTENCIA DE ARQUITECTO:**
> Bajo NINGUNA circunstancia se debe usar `StaleWhileRevalidate` o `CacheFirst` para endpoints de API (`supabase.co`). Esto causaría "Ventas Fantasma" (vender stock que ya no existe porque el navegador sirvió un dato de hace 5 minutos). **Violación de esta regla es causa de reversión inmediata.**

### 4. Casos de Uso

- **Actor:** Cajero
- **Escenario:** Internet se cae en la tienda.
- **Comportamiento Esperado:** La app NO muestra el dinosaurio de Chrome. Muestra la interfaz de caja. (Nota: Procesar la venta offline requiere sincronización compleja futura (SPEC-011), por ahora el requisito es que la *interfaz* no colapse).

### 5. Impacto en el Sistema

| Componente | Modificación |
|------------|--------------|
| `vite.config.ts` | Agregar plugin PWA y configuración de generación de manifiesto. |
| `index.html` | Referencias a iconos y meta tags de Apple (iOS requiere trato especial). |
| `public/` | Adición de iconos `pwa-192.png`, `pwa-512.png`, `favicon.ico`. |
| `src/main.ts` | Registro del Service Worker y manejo de "Nueva versión disponible". |

---

## Lista de Tareas de Implementación (High Level)

1.  [ ] Instalar `vite-plugin-pwa`.
2.  [ ] Generar set de iconos (puedo usar IA para crear un logo base si no existe).
3.  [ ] Configurar `manifest.webmanifest` en Vite config.
4.  [ ] Implementar componente de "Actualizar App" (Toast que avisa cuando hay nuevo SW).
