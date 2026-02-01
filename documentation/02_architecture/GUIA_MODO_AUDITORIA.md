# 🛡️ Guía Técnica: Modo Auditoría y Simulación (AuditShield)

**Versión:** 1.0.0
**Rol Responsable:** QA & Seguridad
**Propósito:** Definir el alcance, arquitectura y protocolo de uso del entorno aislado de pruebas.

---

## 1. Resumen Ejecutivo

El **Modo Auditoría (Audit Mode)** es un entorno de ejecución segregado dentro de la aplicación de producción. Permite a los auditores, desarrolladores y QAs realizar pruebas destructivas, simulaciones de ventas masivas y verificaciones de flujo de usuario (UX) garantizando matemáticamente el **"Principio de Cero Contaminación"** sobre los datos reales.

> **Garantía de Seguridad:** En este modo, la aplicación es físicamente incapaz de comunicarse con la base de datos de producción (Supabase).

---

## 2. Arquitectura de Aislamiento (El Muro de QA)

El sistema opera bajo una arquitectura de "Gemelo Digital Aislado". Al activarse, ocurren tres cambios sistémicos simultáneos:

### A. Segregación de Almacenamiento (Storage Sharding)
El adaptador de almacenamiento (`localStorageAdapter`) inyecta dinámicamente el prefijo `audit-` a todas las operaciones de lectura y escritura.
*   **Producción:** `tienda-sales`, `tienda-inventory`
*   **Auditoría:** `audit-tienda-sales`, `audit-tienda-inventory`

**Resultado:** Dos universos de datos paralelos que nunca se tocan.

### B. Desconexión de Red (Network Killswitch)
El cliente de base de datos (`supabaseClient`) entra en estado `forceOffline`.
*   Cualquier intento de autenticación real devuelve `null`.
*   Cualquier consulta de datos reales es rechazada internamente antes de salir a la red.

### C. Intercepción de Sincronización (SyncQueue Firewall)
El bus de eventos (`syncQueue`), encargado de subir datos cuando hay conexión, activa un "Muro de Seguridad":
*   Intercepta las peticiones de escritura (`CREATE_SALE`, `UPDATE_STOCK`).
*   **Destruye el payload** de forma segura.
*   Devuelve un `ack` (acuse de recibo) falso positivo a la UI para simular que la operación fue exitosa.

---

## 3. Alcance Funcional

| Módulo | Comportamiento en Auditoría |
| :--- | :--- |
| **Login** | **Simulado**. No requiere contraseña real. Crea sesión de "Empleado Demo". |
| **Inventario** | **Local**. Inicia vacío o con datos precargados localmente. Los cambios no persisten en la nube. |
| **Ventas (POS)** | **Full Simulation**. Permite flujo completo de caja, cálculo de vueltos e impresión de tickets. |
| **Clientes** | **Aislado**. Se pueden crear clientes ficticios sin ensuciar el CRM real. |
| **Reportes** | **Local**. Genera reportes basados solo en las ventas de la sesión de auditoría actual. |

---

## 4. Protocolo de Uso (Comandos Globales)

Para facilitar la gestión, se han expuesto controles globales en la consola del navegador (`window.Audit`).

### 🟢 Activar Modo Auditoría
Comando para "entrar a la Matrix" (Simulador):
```javascript
Audit.on()
```
*La aplicación se recargará automáticamente y verá el indicador de seguridad.*

### 🔴 Desactivar (Volver a Producción)
Comando para regresar al entorno real:
```javascript
Audit.off()
```
*Precaución: Al volver, estarás operando con datos reales de dinero e inventario.*

### 🔍 Verificar Estado
Para confirmar en qué universo se encuentra:
```javascript
Audit.status()
```

---

## 5. Preguntas Frecuentes (FAQ)

**P: ¿Si creo una venta de 10 millones en Auditoría, se suma al reporte diario real?**
R: **Absolutamente no.** El reporte real lee de `tienda-sales`, mientras que usted está escribiendo en `audit-tienda-sales`. Son invisibles entre sí.

**P: ¿Puedo usar el Modo Auditoría sin internet?**
R: **Sí.** De hecho, está diseñado para ser "Offline-First". Es el entorno ideal para probar la App en zonas sin cobertura.

**P: ¿Cómo borro los datos de prueba?**
R: Actualmente, los datos de `audit-` persisten en su navegador para permitir pruebas de varios días. Si desea limpiar todo, puede usar `localStorage.clear()` (esto borrará también la sesión real, requiriendo re-login).

---

## 6. Protocolo de Corrección de Errores (Fix Workflow)

Una duda común es: *"¿Si arreglo un bug en modo auditoría, tengo que arreglarlo también en producción?"*

**Respuesta Corta:** No. **El código es único.**

### Principio de "Código Compartido"
El Modo Auditoría cambia **dónde se guardan los datos**, pero usa **exactamente el mismo código** (Vue components, lógica de negocio, estilos) que el modo Producción.

### Flujo de Trabajo Recomendado:
1.  **Detectar**: Encuentras un error visual o de cálculo mientras estás en `Audit.on()`.
2.  **Corregir**: Modificas el archivo `.vue` o `.ts` correspondiente en tu editor.
3.  **Verificar**: Pruebas la corrección inmediatamente en el simulador.
4.  **Desplegar**: Al hacer `git push`, esa corrección viaja a producción automáticamente.

> **Beneficio:** Puedes arreglar bugs críticos de lógica financiera sin miedo a corromper datos reales mientras pruebas tu solución.

---

**Firma Digital de Validación:**
*AntiGravity Agent - Lead Architect*
