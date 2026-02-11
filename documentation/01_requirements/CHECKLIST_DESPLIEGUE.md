# ✅ Checklist de Despliegue a Producción

Este documento guía el proceso de "Release" para asegurar que nada se olvide.

## 1. Preparación del Código (Local)
- [x] **Limpieza de Logs:** Ejecutar búsqueda global de `console.log` y reemplazar por `logger`.
- [x] **Audit Mode OFF:** Verificar en `src/utils/audit.ts` que el modo auditoría no se active accidentalmente.
- [x] **Lint Final:** Ejecutar `npm run lint` y asegurar 0 errores.
- [x] **Type Check:** Ejecutar `npm run type-check` (o build con tsc) para asegurar consistencia de tipos.

## 2. Seguridad y Entorno
- [x] **Variables de Entorno:** Crear `.env.production` localmente para probar el build.
- [x] **API Keys:** Verificar que `VITE_SUPABASE_ANON_KEY` sea la correcta de producción.
- [x] **Supabase RLS:** Ejecutar script de auditoría SQL en el dashboard de producción.
- [x] **Base de Datos:** Verificar que las migraciones estén aplicadas en la instancia de producción (`remote`).

## 3. Build y Performance
- [x] **Ejecutar Build:** `npm run build`.
- [x] **Verificar Dist:** Revisar la carpeta `dist/`. ¿El tamaño es razonable? (index.js < 500kb idealmente, o chunks divididos).
- [x] **Prueba Local de Producción:** Ejecutar `npm run preview`. Esto levanta el servidor local pero sirviendo los archivos de `dist/`.
    - [x] ¿Carga la página blanca? (Error común de rutas relativas).
    - [x] ¿Funcionan los logins?
    - [x] ¿Se ven logs en la consola? (No deberían).

## 4. Despliegue (Hosting)
- [x] **Subir a Git:** Hacer commit con tag `v1.0.0`.
- [ ] **Conectar CI/CD (Netlify/Vercel):**
    - [ ] Configurar variables de entorno en el panel del hosting.
    - [ ] Comando de build: `npm run build`.
    - [ ] Carpeta de salida: `dist`.
- [ ] **Verificar Dominio:** Configurar DNS si aplica.

## 5. Post-Despliegue (Smoke Test)
- [ ] **Login Admin:** Entrar con cuenta real.
- [ ] **Ciclo Crítico:** Crear un producto, hacer una venta, cerrar caja.
- [ ] **Logs de Servidor:** Revisar Supabase logs si algo falla.
