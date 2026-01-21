# Análisis de Viabilidad de Encriptación

> **Rol:** @[/architect] & @[/qa]
> **Fecha:** 2026-01-20
> **Propósito:** Responder a la pregunta: "¿Qué tan viable es implementar encriptación en Tienda de Barrio Pro?"

---

## 🚀 Resumen Ejecutivo

**Veredicto:** La encriptación es **100% Viable y Obligatoria** en ciertas capas, pero **Desaconsejada** en otras por razones de rendimiento y usabilidad.

| Capa | Tipo de Encriptación | Estado Actual | Veredicto |
|------|----------------------|---------------|-----------|
| **Tránsito** | TLS/HTTPS (SSL) | ✅ Implementado (Vercel/Supabase) | **Mantener**. Cero costo. |
| **Credenciales** | Hashing (Bcrypt) | ✅ Implementado (`pgcrypto`) | **Mantener**. Obligatorio. |
| **Repositorio (Disco)** | TDE (Transparent Data Encryption) | ✅ Gestionado por AWS/Supabase | **Mantener**. Transparente. |
| **Datos Sensibles** | Column-Level Encryption (PGP) | ❌ No implementado | ⚠️ **No Recomendado** (Ver análisis). |

---

## 1. Lo que YA tienes (Seguridad Base)

Tu proyecto ya cumple con los estándares industriales básicos sin costo extra:

### A. Encriptación en Tránsito (HTTPS)
Gracias a Vercel y Supabase, toda la comunicación viaja por un túnel seguro (SSL).
- **Riesgo Mitigado:** "Man in the middle" (Alguien interceptando el WiFi de la tienda).
- **Costo:** $0.

### B. Hashing de Contraseñas (El estándar de oro)
En `supabase-schema.sql`, activamos la extensión `pgcrypto`.
```sql
pin = crypt(p_pin, gen_salt('bf'))
```
- **Esto NO es encriptación reversible**, es **Hashing**.
- **Diferencia:** Nadie (ni tú, ni yo, ni Supabase) puede "leer" el PIN original. Solo podemos verificar si un PIN ingresado *coincide* con el guardado.
- **Viabilidad:** Total. No afecta el rendimiento notablemente para logins.

---

## 2. El Dilema: Encriptación de Columnas (Datos de Clientes)

La pregunta real suele ser: *"¿Debería encriptar los nombres y teléfonos de mis clientes en la base de datos?"*

### Análisis Económico (Costo-Beneficio)

**Propuesta:** Usar `pgp_sym_encrypt` para guardar el nombre del cliente encriptado.

#### 🔴 Los Costos (Desventajas)
1.  **Pérdida de Búsquedas:** No puedes hacer `SELECT * FROM clients WHERE name LIKE '%Juan%'`. La base de datos ve basura ininteligible (`xc897sfd...`).
2.  **Lentitud:** Cada lectura requiere desencriptar CPU-intensivamente.
3.  **Complejidad de Claves:** Si pierdes la clave de encriptación, **pierdes todos los datos para siempre**.

#### 🟢 Los Beneficios
1.  **Privacidad Extrema:** Si un hacker roba la base de datos completa (`pg_dump`), no ve nombres ni teléfonos.

### ⚖️ Veredicto del Arquitecto
Para un **Sistema POS (Punto de Venta)**, la velocidad y la búsqueda son vitales. El cajero necesita escribir "Marí" y ver "María", "Mario", "Maribel" al instante.

**Recomendación:** **NO IMPLEMENTAR encriptación de columnas** para datos operativos (Nombres, Productos).
**Razón:** El impacto en la UX (búsqueda lenta o inexistente) destruiría la eficiencia del cajero. La protección de estos datos se debe delegar a **RLS (Row Level Security)**, que ya impide que un usuario vea datos de otra tienda.

---

## 3. Plan de Acción Recomendado

Mantener el enfoque de **"Seguridad en Capas"** sin sacrificar funcionalidad:

1.  **Transporte:** Confiar en HTTPS (Automático).
2.  **Secretos:** Seguir usando `crypt()` para PINs y Passwords.
3.  **Datos Personales:**
    *   No encriptar a nivel de columna (para permitir búsquedas).
    *   **Blindar con RLS:** Asegurar que solo el empleado autenticado de la tienda X pueda leer los clientes de la tienda X.
    *   (QA ya detectó que faltaba RLS en `stores`, ¡eso es más crítico que encriptar!).

## Conclusión
La encriptación "tipo Hollywood" (todo ilegible) no es viable para un sistema de búsqueda rápida como un POS. La estrategia actual de **HTTPS + Hashing + RLS** es la mezcla correcta de seguridad y eficiencia económica.
