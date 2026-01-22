# Checklist de Despliegue y Handover (v1.0-RC1)

> **Fecha**: 2026-01-21  
> **Versión**: v1.0.0-RC1 (Release Candidate)  
> **Estado**: Listo para Producción

---

## 1. Verificación de Build (Frontend)
- [x] Ejecutar `npm run build` sin errores.
- [x] Verificar carpeta `dist/`:
  - [x] `index.html` presente.
  - [x] `assets/` contiene JS y CSS minificados.
  - [x] Tamaño de bundle principal < 500KB (Gzip).

## 2. Configuración Inicial (Entorno Cliente)
- [ ] **Limpieza**: Ejecutar `localStorage.clear()` en el navegador del cliente antes de entregar.
- [ ] **Configuración**:
  - Ingresar a AdminHub -> Configuración.
  - Cargar Logo del cliente.
  - establecer NIT y Régimen.
  - Definir mensaje de pie de ticket.

## 3. Handover al Equipo de Backend (Data Team)
- [ ] Entregar carpeta `02_ARCHITECTURE/`.
- [ ] Entregar archivo `src/types/supabase.ts` (Contrato de Tipos).
- [ ] **Instrucción Crítica**: El equipo de backend DEBE implementar las tablas descritas en `architecture-supabase.md` antes de conectar la app real.

## 4. Handover al Equipo de Infraestructura
- [ ] Subir contenido de `dist/` a CDN (Netlify, Vercel, AWS S3).
- [ ] **HTTPS Habilitado**: Obligatorio para funcionamiento de PWA/Service Workers.
- [ ] Configurar variables de entorno (Crear `.env` en servidor si es necesario).
- [ ] Configurar reglas de SPA (Redirigir 404 a index.html).
- [ ] Habilitar compresión Brotli/Gzip en servidor.

---

## 5. Known Issues (Para Futuras Versiones)
- La sincronización es simulada (frontend-only). Se requiere conectar Supabase para multi-dispositivo real.
- El reporte de "Estancados" está marcado como "Próximamente".

---

> **Firma de Aceptación Técnica**: __________________________
