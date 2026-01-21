# Estrategia de Despliegue (Deployment Strategy)

> **Documento Arquitectónico**
> **Rol:** @[/architect]
> **Propósito:** Guía conceptual para publicar "Tienda de Barrio Pro" en internet.

---

## 1. Concepto: De "Local" a "La Nube"

Hasta ahora, tu aplicación vive en tu computadora (`localhost`). Para que sea accesible al público (el dueño de la tienda desde su tablet, el cajero desde su celular), debemos moverla a servidores públicos.

No usaremos un "servidor único" tradicional. Usaremos una **Arquitectura Serverless (Sin Servidor)**, que es más económica y robusta.

### La Separación Vital
Tu aplicación tiene dos partes físicas separadas:

1.  **Frontend (La "Fachada"):** Los archivos `.html`, `.js`, `.css` que ve el usuario.
2.  **Backend (El "Almacén"):** Tu base de datos y reglas de seguridad en Supabase.

---

## 2. Estrategia Económica (Plan de Austeridad)

Siguiendo nuestros principios de eficiencia, no pagaremos por servidores dedicados (VPS) ni gestión de infraestructura compleja.

| Componente | Proveedor Recomendado | Costo Inicial | Por qué lo elegimos |
|------------|-----------------------|---------------|---------------------|
| **Frontend** | **Vercel** (o Netlify) | **$0/mes** | Son redes globales (CDN). Tu app carga rápido en cualquier lugar. Se conectan directo a GitHub. |
| **Backend** | **Supabase** | **$0/mes** | Ya lo tienes. El plan gratuito soporta hasta 500MB y 50k usuarios mensuales, sobrado para una tienda. |

---

## 3. El Flujo de Despliegue (Cómo funciona)

No subiremos archivos manualmente por FTP (eso es obsoleto). Usaremos **Integración Continua (CI/CD)**.

```mermaid
graph LR
    A[Tu Computadora] -->|git push| B[GitHub]
    B -->|Detecta cambio| C[Vercel]
    C -->|1. Descarga código| D[Construcción (Build)]
    D -->|2. Compila Vue| E[Archivos Estáticos]
    E -->|3. Publica| F(Internet: tu-tienda.vercel.app)
    F -.->|Conecta Datos| G[Supabase Cloud]
```

1.  **Tú programas y guardas:** Haces `git commit` y `git push`.
2.  **GitHub avisa:** "¡Hey Vercel, hay código nuevo!".
3.  **Vercel trabaja:** Construye la nueva versión de tu sitio automáticamente.
4.  **Publicación:** En ~1 minuto, la nueva versión está en vivo.

---

## 4. Pasos para la Puesta en Producción

### Fase A: Preparación del Backend (Supabase)
Ya lo tienes listo, pero asegúrate de:
1.  **RLS Activo:** Tus tablas deben tener seguridad (Row Level Security). *Lo revisamos en la auditoría.*
2.  **URL de Producción:** Asegúrate de que `VITE_SUPABASE_URL` en tu código apunte a tu proyecto real en Supabase (no a un localhost dockerizado, a menos que uses self-hosting).

### Fase B: Configuración del Frontend (Vercel)
*Recomendado por ser los creadores del tooling moderno web.*

1.  **Crear cuenta en Vercel:** Con tu usuario de GitHub.
2.  **Importar Proyecto:** Vercel verá tus repositorios. Selecciona `tienda-barrio-pro`.
3.  **Configurar Build:**
    *   Framework Preset: `Vite` (lo detecta solo).
    *   Root Directory: `SRC` (⚠️ Importante: tu código está en la subcarpeta `SRC`, no en la raíz).
4.  **Variables de Entorno (Environment Variables):**
    *   Aquí copias los valores de tu `.env` local.
    *   `VITE_SUPABASE_URL`: `https://...`
    *   `VITE_SUPABASE_ANON_KEY`: `eyJ...`

### Fase C: El Primer Despliegue
Al dar clic en "Deploy", Vercel ejecutará `npm install` y `npm run build`. Si todo sale verde, te dará una URL: `https://tienda-barrio-pro.vercel.app`.

---

## 5. Mantenimiento y Actualizaciones

¿Cómo actualizas la app en el futuro?
**Simplemente haces `git push`.**
No hay paso 2. El sistema se encarga de todo.

---

## 6. Siguiente Paso Sugerido
Si estás listo para probar esto, el comando sería **conectar este repositorio a un remoto en GitHub** (si no lo está ya) y proceder a la configuración en Vercel.

---

## 7. Aprobación y Endoso de Seguridad (QA Audit)

> **Auditor:** @[/qa]
> **Dictamen:** ✅ **ESTRATEGIA SEGURA** (Bajo condiciones)

Esta arquitectura es **intrínsecamente segura** porque reduce la superficie de ataque al no gestionar servidores. Sin embargo, para mantener el sello de seguridad, se deben cumplir estas reglas inquebrantables:

### 🛡️ Reglas de Oro de Seguridad en Despliegue

1.  **Nunca Exponer Service Role Key**: En Vercel, la variable `VITE_SUPABASE_ANON_KEY` es pública (va al navegador). **JAMÁS** pongas la `SERVICE_ROLE_KEY` en las variables de entorno del Frontend. Si lo haces, cualquiera puede borrar tu base de datos.
2.  **RLS es tu único Firewall**: Como el Frontend es público, **toda** la seguridad recae en las Políticas RLS de Supabase. Si una tabla no tiene RLS, es insegura.
3.  **Logs de Producción**: Vercel guarda logs. No imprimas información sensible (`console.log(usuario.password)`) y menos en producción.

### Matriz de Riesgos de Despliegue

| Amenaza | Mitigación Arquitectónica | Acción Requerida |
|---------|---------------------------|------------------|
| **DDoS al Frontend** | Vercel Edge Network (CDN) | Ninguna (automático) |
| **Robo de Datos** | RLS + Supabase Auth | **CRÍTICO:** Auditar RLS antes de cada deploy. |
| **Costos Inflados** | Límites de gasto en Vercel | Configurar "Spend Management" en Vercel para evitar facturas sorpresa. |

