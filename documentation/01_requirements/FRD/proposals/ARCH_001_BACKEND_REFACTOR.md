# Propuesta Técnica: Estrategia de Alineación Arquitectónica (Mirror Architecture)

**Ref:** ARCH-001 | **Fecha:** 2026-02-11 | **Rol:** Arquitecto de Sistema

## 1. Diagnóstico Económico-Técnico
El sistema actual sufre de **"Duplicidad Lógica No Gestionada"** (el "Arroz con Mango").
-   **Costo:** Cada regla de negocio (ej. "No vender sin stock") se implementa dos veces: SQL (Backend) y TypeScript (Frontend).
-   **Riesgo:** "Drift" (Desviación). Si se actualiza SQL y se olvida TS, la venta Offline se aprueba corruptamente y falla al sincronizar.
-   **Deuda Técnica:** Alta. El mantenimiento requiere revisar dos lenguajes distintos para un solo cambio funcional.

## 2. Filosofía de Solución: "Arquitectura de Espejo"
No podemos eliminar la lógica del Frontend porque el requisito **Offline-First** es innegociable. El Frontend *debe* poder validar sin red.
**La Solución no es eliminar, es Estandarizar.**

### Principio Rector: "Backend Legisla, Frontend Vigila"
1.  **Backend (Data Architect)**: Define la Ley (Tablas, RPCs, Constraints).
2.  **Frontend (UX)**: Actúa como el Policía Local. Conoce la ley (cacheada) y la hace cumplir preventivamente.
3.  **Protocolo Común**: Un Sistema de Códigos de Error Unificado.

---

## 3. Pilares de la Estrategia

### A. Diccionario de Datos Dinámico (Unhardcoding)
*Problema:* `payment_method = 'efectivo'` está quemado en código.
*Solución:* Datos Maestros en Base de Datos.

1.  **Backend**: Crear tablas `payment_methods`, `transaction_types`, `tax_rules`.
2.  **API**: RPC `get_system_config()` que retorna estos maestros al iniciar sesión.
3.  **Frontend**: UI dinámica. Si agregas "Nequi" en BD, aparece el botón en la Caja automáticamente.

### B. Validadores Espejo (Mirror Validators)
*Problema:* Validación dispersa en `saleRepository.ts`.
*Solución:* Módulos de Validación Aislados.

1.  Crear `src/logic/validators/SalesValidator.ts`.
    -   Entrada: `SalePayload`, `Context (Stock, Cliente)`.
    -   Salida: `ValidationResult` (Success / ErrorCode).
2.  **Regla de Oro**: Este validador debe replicar *exactamente* las condiciones del `rpc_procesar_venta_v2`.
3.  **Test**: Unit Tests que aseguren que `SalesValidator` rechaza lo mismo que el RPC.

### C. Protocolo de Errores Unificado
Estandarizar la comunicación para que el Frontend sepa *exactamente* qué falló sin parsear texto.

| Código Error | Significado | Acción UI |
|--------------|-------------|-----------|
| `STOCK_INSUFFICIENT` | Cantidad > Stock Disponible | Mostrar alerta stock, ofrecer Venta Forzada (si online). |
| `CREDIT_LIMIT_EXCEEDED` | Deuda + Venta > Cupo | Bloquear venta fiada. |
| `CLIENT_LOCKED` | Cliente bloqueado por mora | Bloquear venta fiada. |
| `SYNC_REQUIRED` | Configuración obsoleta | Forzar recarga de `system_config`. |

---

## 4. Plan de Ejecución (Fases)

### Fase 1: Cimientos (Data Layer)
*Objetivo:* Limpiar esquema y preparar tablas de configuración.
1.  Migración DB: Extraer ENUMs a Tablas (`payment_methods`).
2.  RPC: `rpc_get_system_config`.
3.  Frontend Store: `useConfigStore` (persiste en LocalStorage).

### Fase 2: Lógica Compartida (Validation Layer)
*Objetivo:* Centralizar la "inteligencia" del frontend.
1.  Refactor: Extraer lógica de `saleRepository.ts` a `SalesValidator.ts`.
2.  Implementar códigos de error estándar en RPCs existentes.

### Fase 3: Limpieza Final (Cleanup)
*Objetivo:* Eliminar deuda técnica.
1.  Refactorizar `saleRepository` para usar `SalesValidator`.
2.  Eliminar validaciones "ad-hoc" en componentes UI.

---

## 5. Beneficio Esperado
-   **Escalabilidad**: Agregar un tipo de pago toma minutos (insert SQL), no horas de compilación.
-   **Robustez**: La sincronización Offline fallará menos porque el Frontend valida con las mismas reglas que el Backend.
-   **Mantenibilidad**: Código limpio y predecible.
