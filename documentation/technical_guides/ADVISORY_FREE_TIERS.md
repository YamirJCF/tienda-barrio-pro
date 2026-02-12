# Guía de Sostenibilidad: Capa Gratuita (Vercel & Supabase)

Para mantener los costos en **$0**, sigue estas recomendaciones técnicas basadas en los límites de 2026.

## 1. Supabase (El punto más crítico)

Supabase es generoso, pero tiene reglas estrictas de "Inactividad".

### 💡 Regla de Oro: ¡Manténlo despierto!
> [!IMPORTANT]
> Los proyectos gratuitos se **pausan automáticamente tras 7 días de inactividad**. Si nadie entra a la app en una semana, la base de datos se apagará.
> **Solución:** Entra al Dashboard de Supabase o abre la aplicación al menos una vez por semana.

### 📊 Gestión de Almacenamiento (Límite: 500 MB)
- **No guardes imágenes en la DB:** Usa el "Storage" de Supabase (1 GB gratis) para fotos de productos, no campos `base64`.
- **Limpieza de Logs:** Si implementas un sistema de auditoría, asegúrate de borrar registros de más de 30 días para no llenar el espacio.

### 📉 Transferencia de Datos (Límite: 2 GB Egress)
- **Consultas Selectivas:** En el código, evita usar `SELECT *`. Pide solo las columnas que necesites (ej. `.select('id, name, price')`).
- **Paginación:** Siempre usa filtros de límite (ej. `.limit(20)`) para no descargar miles de registros de un solo golpe.

---

## 2. Vercel (Hobby Plan)

Vercel es muy estable, pero vigila el ancho de banda.

### 🚀 Optimización de Assets (Límite: 100 GB Bandwidth)
- **Imágenes:** Usa formatos modernos como `.webp` o `.avif`.
- **No hostees videos:** Si necesitas tutoriales, usa YouTube o Vimeo y empótralos. El video consume el ancho de banda de Vercel muy rápido.

### 🛠️ Builds y Despliegues (Límite: 100/día)
- **No hagas push por cada coma:** Cada vez que haces `git push`, Vercel gasta "Build Minutes" (6,000 min/mes). Es mucho, pero en proyectos grandes puede sumar. Prueba tus cambios localmente antes de subirlos.

---

## 3. Resumen de Límites (Free Tier 2026)

| Servicio | Concepto | Límite | Riesgo |
|---|---|---|---|
| **Supabase** | DB Size | 500 MB | Alto (si guardas archivos pesados) |
| **Supabase** | Inactividad | 7 días | **MUY ALTO** (Se pausa el servicio) |
| **Supabase** | Usuarios Auth | 50,000 MAU | Bajo |
| **Vercel** | Bandwidth | 100 GB | Medio (cuidado con imágenes grandes) |
| **Vercel** | Edge Req | 1M / mes | Bajo |

## 4. ¿Cuándo deberías pagar?
Solo cuando tu tienda crezca mucho:
- Si tienes más de 10 sedes sincronizadas simultáneamente.
- Si superas los 50.000 clientes activos al mes.
- Si necesitas copias de seguridad cada hora (Supabase Free solo tiene copias diarias básicas).
