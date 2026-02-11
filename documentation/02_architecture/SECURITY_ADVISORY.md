# 🛡️ Aviso de Seguridad: Gestión de Secretos

**Referencia:** OT-001
**Fecha:** 2026-02-11

## 🚫 Lógica de IA Deshabilitada en Cliente

Se ha eliminado intencionalmente la inyección de `GEMINI_API_KEY` en `vite.config.ts`.

### Motivo
Inyectar variables de entorno con `define` en Vite hace un reemplazo estático de texto. Esto significa que la llave API queda **hardcodeada** en el archivo JavaScript final (`index.js`) que descarga el navegador del usuario. Cualquier persona puede leerla.

### Nueva Arquitectura Requerida
Para reactivar funcionalidades de IA, se debe implementar el patrón **Backend-for-Frontend (BFF)**:

1.  **Cliente:** Envía el prompt a Supabase Edge Function.
2.  **Edge Function:**
    *   Valida autenticación del usuario.
    *   Lee `GEMINI_API_KEY` de las variables de entorno del servidor (Deno).
    *   Llama a Google Gemini.
    *   Retorna solo la respuesta procesada.

**NUNCA volver a exponer llaves API en el código del cliente.**
