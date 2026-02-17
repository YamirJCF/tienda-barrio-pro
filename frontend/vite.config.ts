import path from 'path';
import { fileURLToPath } from 'url';
import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';
import { VitePWA } from 'vite-plugin-pwa';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', '');
  return {
    server: {
      port: 3002,
      host: '0.0.0.0',
    },
    plugins: [
      vue(),
      VitePWA({
        registerType: 'autoUpdate',
        includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'masked-icon.svg'],
        manifest: {
          name: 'Tienda de Barrio Pro',
          short_name: 'TiendaPro',
          description: 'Punto de Venta Profesional para Tiendas de Barrio',
          theme_color: '#ffffff',
          background_color: '#ffffff',
          display: 'standalone',
          orientation: 'portrait',
          icons: [
            {
              src: 'web-app-manifest-192x192.png',
              sizes: '192x192',
              type: 'image/png'
            },
            {
              src: 'web-app-manifest-512x512.png',
              sizes: '512x512',
              type: 'image/png'
            }
          ]
        },
        workbox: {
          runtimeCaching: [
            {
              // ⛔ PROHIBIDO CACHEAR API: Datos críticos de negocio
              urlPattern: /^https:\/\/.*supabase\.co\/.*/,
              handler: 'NetworkOnly',
            },
            {
              // Google Fonts
              urlPattern: /^https:\/\/.*googleapis\.com\/.*/,
              handler: 'StaleWhileRevalidate',
              options: {
                cacheName: 'google-fonts-stylesheets',
              },
            },
            {
              // Imágenes de productos y assets estáticos
              urlPattern: /.*\.(?:png|jpg|jpeg|svg|gif|webp)$/,
              handler: 'CacheFirst',
              options: {
                cacheName: 'images',
                expiration: {
                  maxEntries: 100,
                  maxAgeSeconds: 30 * 24 * 60 * 60, // 30 días
                },
              },
            },
            {
              // Fallback para otros recursos
              urlPattern: /.*/,
              handler: 'NetworkFirst',
              options: {
                cacheName: 'general-fallback',
              }
            }
          ]
        }
      })
    ],
    define: {
      // 🔒 SECURITY HARDENING (OT-001):
      // Removed process.env.GEMINI_API_KEY injection to prevent exposure in client bundle.
      // AI features must use Edge Functions.
    },
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      }
    }
  };
});
