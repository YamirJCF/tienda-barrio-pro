import path from 'path';
import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';


export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', '');
  return {
    server: {
      port: 3000,
      host: '0.0.0.0',
    },
    plugins: [vue()],
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
