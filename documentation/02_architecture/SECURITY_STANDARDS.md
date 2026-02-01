# Especificación Técnica de Seguridad y Encriptación (Security Standards)

> **Rol:** @[/architect] & @[/qa]
> **Versión:** 1.0 (Definitive)
> **Estado:** ESTÁNDAR APROBADO
> **Propósito:** Definir la arquitectura de seguridad para garantizar escalabilidad, rendimiento (<200ms) y confianza del cliente.

---

## 1. Principios de Diseño de Seguridad

Para ganar la confianza del cliente sin sacrificar la velocidad del sistema, adoptamos el modelo de **"Seguridad en Profundidad sin Fricción"**.

1.  **Velocidad es Seguridad:** Un sistema lento hace que los usuarios busquen "atajos" inseguros. La encriptación no debe degradar el UX.
2.  **Aislamiento Lógico (Tenant Isolation):** Cada tienda es un silo de datos impenetrable para otras tiendas.
3.  **Cero Confianza en Red (Zero Trust):** Asumimos que la red es hostil; todo tráfico se encripta.

---

## 2. Estándares de Encriptación (Implementation Spec)

### 2.1 Encriptación en Tránsito (Data in Transit)
**Obligatorio** para toda comunicación Cliente ↔ Servidor.

*   **Protocolo:** TLS 1.3 (o mínimo TLS 1.2).
*   **Certificados:** Gestionados automáticamente por Vercel/Supabase (Let's Encrypt).
*   **HSTS (HTTP Strict Transport Security):** Habilitado para forzar HTTPS.
*   **Impacto:** Los datos de venta viajan cifrados. Un atacante en el WiFi de la tienda solo ve ruido.

### 2.2 Encriptación en Reposo (Data at Rest)
**Obligatorio** para la persistencia física del dato.

*   **Nivel:** Disco / Volumen (Full Disk Encryption).
*   **Algoritmo:** AES-256.
*   **Gestión:** Delegada al proveedor de infraestructura (Supabase sobre AWS).
*   **Impacto:** Si alguien roba físicamente el disco duro del servidor, los datos son ilegibles.

### 2.3 Hashing de Credenciales (Application Level)
**Obligatorio** para contraseñas, PINs y tokens de acceso.

*   **Algoritmo:** `bcrypt` (Blowfish).
*   **Costo de Trabajo (Work Factor):**
    *   `Admin Password`: Costo 10 (Balance seguridad/tiempo).
    *   `Employee PIN`: Costo 6 (Optimizado para desbloqueo rápido en POS, mitigado por Rate Limiting).
*   **Salting:** Automático vía `pgcrypto` (`gen_salt('bf')`).
*   **Regla:** JAMÁS almacenar credenciales en texto plano.

### 2.4 Política de Encriptación de Columnas (PII)
**Decisión Arquitectónica:** NO IMPLEMENTAR en campos operativos.

*   **Alcance:** Nombres de clientes, direcciones, teléfonos, nombres de productos.
*   **Justificación Técnica:** La encriptación de columna (PGP) deshabilita la indexación B-Tree estándar.
    *   *Sin encriptar:* Búsqueda "Marí" → 0.05ms (Index Scan).
    *   *Encriptado:* Búsqueda "Marí" → 500ms+ (Full Table Scan + Decryption CPU).
*   **Compensación de Seguridad:** La privacidad se garantiza mediante políticas RLS estrictas (ver Sección 3).

---

## 3. Arquitectura de Aislamiento (Row Level Security)

Nuestra principal barrera de defensa no es la encriptación ilegible, sino la **Segregación de Datos**.

### 3.1 El Modelo de Aislamiento
Cada consulta SQL debe pasar por un "filtro invisible" forzado por el motor de base de datos.
```sql
-- Ejemplo Técnico de la Política Implementada
CREATE POLICY "tenant_isolation" ON all_tables
USING (store_id = current_user_store_id());
```

### 3.2 Garantía de Rendimiento
A diferencia de la encriptación de columnas, RLS utiliza índices estándar.
*   **Escalabilidad:** O(log n). El rendimiento se mantiene estable aunque tengamos 1 millón de tiendas.

---

## 4. Gestión de Secretos y Llaves

### 4.1 Frontend (Variables de Entorno)
*   `VITE_SUPABASE_URL`: Pública.
*   `VITE_SUPABASE_ANON_KEY`: Pública. **Solo** permite iniciar el handshake; por sí sola no da acceso a datos (gracias a RLS).

### 4.2 Backend (Variables de Entorno)
*   `SERVICE_ROLE_KEY`: **TOP SECRET**. Da acceso "Dios".
    *   *Uso:* Solo en Edge Functions o Scripts de Administración en CI/CD.
    *   *Prohibición:* NUNCA incluir en el código del cliente (`.js`, `.vue`).

---

## 5. Cumplimiento y Confianza del Cliente (Compliance)

Esta arquitectura prepara el terreno para certificaciones futuras:

*   **GDPR / CCPA:** "Derecho al Olvido". Al no tener datos encriptados con llaves perdidas, podemos ejecutar borrados físicos reales (`DELETE`) cuando un usuario lo solicite.
*   **PCI-DSS (Pagos):** No tocamos números de tarjeta de crédito. Delegamos el procesamiento a pasarelas (Wompi/Bold) vía SDK. Nuestra BD nunca ve el PAN (Primary Account Number).

---

## 6. Auditoría Continua

El sistema debe auto-protegerse:
1.  **Rate Limiting:** Bloqueo de PIN tras 5 intentos (Implementado en RPC `login_empleado_unificado`).
2.  **Logs de Auditoría:** Registro inmutable en `cash_control_events` de quién abrió/cerró la caja (Implementado).

---
**Firma:**
*Arquitectura de Software & QA Team*
*Tienda de Barrio Pro*
