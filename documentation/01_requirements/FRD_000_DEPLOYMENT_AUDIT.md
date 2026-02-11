# 🛡️ Reporte de Auditoría de Pre-Despliegue (FRD-000)

**Fecha:** 2026-02-11
**Versión:** 1.0.0
**Estado:** 🟡 REQUIERE AJUSTES

---

## 1. Resumen Ejecutivo (Arquitecto de Producto)

El sistema se encuentra funcionalmente completo para la versión 1.0, pero **NO está listo para un despliegue seguro a producción**. Se han detectado vulnerabilidades críticas de seguridad y "basura técnica" que deben limpiarse antes de abrir el acceso público.

El objetivo de esta fase es **endurecer** la aplicación. No agregaremos nuevas funcionalidades, solo aseguraremos lo que ya existe.

---

## 2. Hallazgos de Seguridad (QA & Ciberseguridad)

### 🔴 CRÍTICO: Exposición de Credenciales
- **Archivo:** `vite.config.ts`
- **Problema:** Se está inyectando `GEMINI_API_KEY` directamente en el bundle del cliente (`define: { 'process.env.GEMINI_API_KEY': ... }`).
- **Riesgo:** Cualquier usuario puede extraer esta llave inspeccionando el código fuente (`Ctrl+U` o Sources tab) y usar tu cuota de Gemini para sus propios fines, generando costos o denegación de servicio.
- **Solución:** Mover la lógica de IA a una **Supabase Edge Function** y que el frontend solo llame a esa función. La llave NUNCA debe llegar al navegador.

### 🟠 ALTO: Verificación de RLS (Pendiente)
- **Problema:** No se pudo verificar automáticamente la robustez de las políticas Row Level Security (RLS) debido a problemas de conexión con la herramienta de auditoría.
- **Riesgo:** Si una tabla tiene `public` acceso o políticas permisivas (`true`), los datos de todos los clientes podrían ser descargados por cualquiera.
- **Acción:** Ejecutar script de validación SQL manual (ver Anexo A).

---

## 3. Calidad de Código y Performance (Arquitecto de Software)

### 🟡 MEDIO: Contaminación de Consola en Producción
Se detectaron múltiples `console.log` que quedarán visibles en el navegador del usuario final, dando una imagen poco profesional y potencialmente revelando lógica interna.

| Archivo | Línea | Mensaje / Código | Acción |
|---------|-------|------------------|--------|
| `src/init.ts` | 20 | "Audit Controls Loaded..." | Eliminar o usar logger condicional |
| `src/router/index.ts` | 210 | "Session expired..." | Cambiar a `logger.log` (se silencia en prod) |
| `src/router/index.ts` | 231 | "Stale shift detected..." | Cambiar a `logger.log` |

### 🔵 BAJO: Configuración de Build
- **Chunking:** `vite.config.ts` no tiene configuración explícita de `build.rollupOptions`. Para una app de este tamaño, se recomienda dividir `vendor` (Vue, Pinia, Supabase) del código de la app para mejorar el cacheo.

---

## 4. Plan de Acción Inmediato

1.  **Limpieza de Logs:** Reemplazar todos los `console.log` directos por `logger.log` o `logger.error` según corresponda.
2.  **Protección de Secretos:** Confirmar si `GEMINI_API_KEY` es necesaria en el cliente. Si es solo para pruebas, eliminarla del build de producción. Si es vital, refactorizar a Edge Function.
3.  **Validación Manual RLS:** El orquestador debe correr los queries de validación en Supabase Dashboard.

---

## Anexo A: Script de Validación RLS (SQL)

Ejecutar en el SQL Editor de Supabase para confirmar seguridad:

```sql
-- Listar tablas que NO tienen RLS habilitado (Debería estar vacío)
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND rowsecurity = false;

-- Listar políticas que son "demasiado abiertas" (revisar manualmente)
SELECT tablename, policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE schemaname = 'public';
```
