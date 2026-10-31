# Plan de Ejecución — SDD-013 v3.1.0 (Verificación Continua de Sesión)

- [ ] **Paso 0 — Git:** Crear rama `feat/session-continuous-verification-sdd-013` y commitear documentación formal.
- [ ] **Paso 1.1 — SQL:** Crear y aplicar migración `20261031000000_session_continuous_verification_sdd_013.sql` con `rpc_verificar_estado_sesion` y unificación de `check_daily_pass_status`.
- [ ] **Paso 2.1 — Repositorio:** Integrar `verifySessionAccessState` en `frontend/src/data/repositories/authRepository.ts`.
- [ ] **Paso 2.2 — Purga:** Eliminar archivo muerto `frontend/src/composables/useSessionManager.ts` (D-SES-05).
- [ ] **Paso 2.3 — Store:** Implementar `verifySessionWithServer` y BroadcastChannel en `frontend/src/stores/auth.ts`.
- [ ] **Paso 3.1 — Composable:** Crear `frontend/src/composables/useSessionGuard.ts` con deduplicación de fallos, eventos de foco/red y sync multiventana.
- [ ] **Paso 3.2 — UI/Router:** Integrar guardia en `frontend/src/router/index.ts` y montar listener en `frontend/src/App.vue`.
- [ ] **Paso 4 — Verificación:** Ejecutar `npm run type-check`, `npm run build` y pruebas de integración.
