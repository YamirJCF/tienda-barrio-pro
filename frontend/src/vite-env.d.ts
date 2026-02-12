/// <reference types="vite/client" />
/// <reference types="vite-plugin-pwa/client" />


// Vite environment variables type definitions
interface ImportMetaEnv {
  readonly VITE_APP_TITLE?: string;
  // Add more env variables as needed
}

interface ImportMeta {
  readonly env: ImportMetaEnv & {
    readonly DEV: boolean;
    readonly PROD: boolean;
    readonly MODE: string;
    readonly BASE_URL: string;
    readonly SSR: boolean;
  };
}
