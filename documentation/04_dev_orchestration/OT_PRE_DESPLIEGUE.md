# 📋 Órdenes de Trabajo: Pre-Despliegue (v1.0.0)

Documento maestro de orquestación para la fase de endurecimiento y despliegue.

---

## 🛑 OT-001: Hardening de Seguridad (Critical)

**Objetivo:** Eliminar la exposición de `GEMINI_API_KEY` en el cliente y asegurar la configuración de Vite.

### Estado Git
- **Rama Base:** `main` (o `develop`)
- **Rama de Trabajo:** `fix/security-hardening`
- **Comando:** `git checkout -b fix/security-hardening`

### Plan de Acción Atómico
1.  Modificar `vite.config.ts`: Eliminar la sección `define` que inyecta `process.env.GEMINI_API_KEY` y `API_KEY`.
2.  Crear `documentation/02_architecture/SECURITY_ADVISORY.md`: Documentar que la IA se ha deshabilitado temporalmente en producción hasta implementar Edge Functions (o documentar el workaround si existe).
3.  Verificar `.env.example`: Asegurar que no tenga valores reales.

### Prompt para Antigravity (Ejecución)
```markdown
# Role: Security Engineer
Target File: `vite.config.ts`

Action:
1. Locate the `define` object in the `defineConfig`.
2. REMOVE the lines injecting `process.env.API_KEY` and `process.env.GEMINI_API_KEY`.
3. Leave `define` empty or remove it if not used for other things.

Reason: These keys are being exposed to the browser client, which is a critical security vulnerability.
```

---

## 🧹 OT-002: Limpieza de Logs (Production Cleanup)

**Objetivo:** Asegurar que la consola del navegador esté limpia en producción.

### Estado Git
- **Rama Base:** `fix/security-hardening` (Merge después de OT-001)
- **Rama de Trabajo:** `chore/prod-cleanup`
- **Comando:** `git checkout -b chore/prod-cleanup`

### Plan de Acción Atómico
1.  Editar `src/init.ts`: Comentar o eliminar el `console.log` de "Audit Controls Loaded" o envolverlo en `if (import.meta.env.DEV)`.
2.  Editar `src/router/index.ts`: Reemplazar `console.log` por importación y uso de `logger.log` (que ya filtra por DEV).
    - Líneas aprox: 210, 231.
3.  Verificar `src/utils/audit.ts`: Asegurar que `initAuditMode` fuerce `false` en producción de manera robusta.

### Prompt para Antigravity (Ejecución)
```markdown
# Role: Code Cleaner
Target Files: `src/init.ts`, `src/router/index.ts`

Action:
1. In `src/init.ts`: Wrap the "Audit Controls Loaded" log in a check for `import.meta.env.DEV` or use the `logger` utility.
2. In `src/router/index.ts`: Import `logger` from `../utils/logger`.
3. Replace direct `console.log` calls with `logger.log()` within the router guards (lines ~210, ~231).

Constraint: ensure `logger` is imported correctly.
```

---

## 🚀 OT-003: Release Candidate & Build Verification

**Objetivo:** Generar el build de producción y validar su viabilidad.

### Estado Git
- **Rama Base:** `chore/prod-cleanup`
- **Rama de Trabajo:** `release/v1.0.0-rc1`
- **Comando:** `git checkout -b release/v1.0.0-rc1`

### Plan de Acción Atómico
1.  Ejecutar `npm run type-check` (si disponible) o validación manual.
2.  Ejecutar `npm run build`.
3.  Analizar tamaño de `dist/`.
4.  Crear script de validación RLS `supabase/rls_validation.sql` con los queries del FRD-000 para que el usuario o el pipeline los ejecute.

### Prompt para Antigravity (Ejecución)
```markdown
# Role: Build Engineer
Target: Terminal & New File

Action:
1. Create `supabase/migrations/20260211000000_security_audit.sql` containing the SQL queries from FRD-000 for RLS validation.
2. Run `npm run build` in the terminal to verify the build process completes without errors.
```
