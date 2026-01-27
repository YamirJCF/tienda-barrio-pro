# Límites y Exclusiones del Sistema

> **Documento de Arquitectura** | Versión 1.0  
> Última actualización: 2026-01-27

## Propósito

Este documento define explícitamente qué funcionalidades **ESTÁN FUERA** del alcance del sistema. Su objetivo es:

1. **Prevenir scope creep** durante el desarrollo
2. **Alinear expectativas** de stakeholders
3. **Guiar decisiones técnicas** cuando surjan dudas
4. **Documentar el razonamiento** detrás de cada exclusión

---

## Definición del Sistema

> **"Libreta Digital con Funciones Avanzadas"**
> 
> El sistema es una herramienta de administración y contabilidad parcial diseñada específicamente para tiendas de barrio colombianas. Reemplaza la libreta física tradicional con una interfaz móvil-first que permite llevar control de ventas, inventario, empleados y crédito de clientes (fiado).

### Mercado Objetivo

| Característica | Descripción |
|----------------|-------------|
| **Usuario** | Tendero colombiano con confianza en dispositivos móviles |
| **Negocio** | Tienda de barrio pequeña (régimen simplificado o informal) |
| **Dispositivo** | Smartphone Android (81% del mercado según estudio) |
| **Operación** | Una sola tienda, operada por dueño y/o empleados de confianza |

---

## Exclusiones Permanentes

Estas funcionalidades **NO serán implementadas** en ninguna versión del sistema por decisión estratégica.

### Facturación y Cumplimiento Fiscal

| Exclusión | Justificación |
|-----------|---------------|
| ❌ Generación de facturas electrónicas (DIAN) | El mercado objetivo no requiere facturación legal |
| ❌ Validación de NIT con dígito verificador | No hay obligación fiscal que lo requiera |
| ❌ Integración con software contable externo | El sistema es autónomo por diseño |

> [!IMPORTANT]
> Los tickets/recibos generados son **comprobantes internos** para control del tendero, NO documentos fiscales válidos ante la DIAN.

### Integraciones Externas

| Exclusión | Justificación |
|-----------|---------------|
| ❌ Pasarelas de pago (Nequi, Daviplata, PSE) | El tendero cobra en efectivo o registra el método manualmente |
| ❌ Conexión con bancos | Fuera del alcance de una libreta digital |
| ❌ APIs de terceros (Google, redes sociales) | Responsabilidad externa del tendero |

### Exportación de Datos

| Exclusión | Justificación |
|-----------|---------------|
| ❌ Generación de reportes en Excel | Complejidad innecesaria para el usuario objetivo |
| ❌ Generación de reportes en PDF | Mismo criterio de simplicidad móvil-first |
| ❌ Exportación masiva de datos | No aplica para operación de tienda pequeña |

### Escalabilidad de Negocio

| Exclusión | Justificación |
|-----------|---------------|
| ❌ Multi-tienda (gestión de varias sucursales) | Una instancia del sistema = una tienda |
| ❌ Multi-propietario | Un dueño (Admin) por tienda |
| ❌ Franquicias o cadenas | Fuera del mercado objetivo |

### Funcionalidades Avanzadas

| Exclusión | Justificación |
|-----------|---------------|
| ❌ Alertas de vencimiento de productos | Complejidad de gestión de fechas por producto |
| ❌ Lectura de códigos de barras | Foco en entrada manual móvil |
| ❌ Etiquetas electrónicas de estantería (ESL) | Tecnología fuera del alcance económico del tendero |
| ❌ Programa de puntos/sellos para clientes | El "fiado" cumple la función de fidelización |
| ❌ Módulos de capacitación/tutoriales | La app debe ser intuitiva sin manual |

### Legal y Tributario

| Exclusión | Justificación |
|-----------|---------------|
| ❌ Asesoría sobre RUT o regímenes tributarios | Requiere contador externo |
| ❌ Cálculo de impuestos (IVA, ICA) | El sistema no maneja obligaciones fiscales |
| ❌ Generación de declaraciones | Fuera del alcance de una libreta digital |

---

## Exclusiones de Esta Versión (Futuras)

Estas funcionalidades **podrían implementarse** en versiones posteriores, pero **NO están en el alcance actual**.

| Funcionalidad | Estado | Versión Tentativa |
|---------------|--------|-------------------|
| Backup/Exportación manual de datos | ⏸️ Pendiente | v2.0 |
| Tema oscuro | ⏸️ Pendiente | v2.0 |
| Soporte multi-idioma | ⏸️ Pendiente | v3.0 |

---

## Funcionalidad Offline

> [!WARNING]
> El sistema NO es 100% offline.

| Módulo | ¿Funciona Offline? |
|--------|-------------------|
| Punto de Venta (POS) | ✅ Sí - Ventas se sincronizan después |
| Inventario | ❌ No - Requiere conexión |
| Empleados | ❌ No - Requiere conexión |
| Clientes | ❌ No - Requiere conexión |
| Reportes | ❌ No - Requiere conexión |
| Control de Caja | ❌ No - Requiere conexión |

**Justificación:** El modo offline se diseñó para no perder ventas cuando hay problemas de conectividad, no para operar indefinidamente sin internet.

---

## Funcionalidades Confirmadas (Dentro del Alcance)

Para claridad, estas funcionalidades **SÍ están incluidas**:

- ✅ Control de inventario (productos, stock, precios)
- ✅ Punto de venta con múltiples métodos de pago
- ✅ Gestión de empleados y roles (Admin/Empleado)
- ✅ Sistema de crédito/fiado para clientes
- ✅ Control de caja (apertura, cierre, movimientos)
- ✅ Historial de ventas y transacciones
- ✅ **Historial de cambios de precio** (con fecha y valores) ← *Requiere FRD*
- ✅ Notificaciones internas (alertas de stock bajo, etc.)
- ✅ Datos de la tienda (nombre, NIT informativo, dirección)

---

## Referencias

- **Estudio Base:** Plan Estratégico para la Optimización de Operaciones y Gestión en Tiendas Minoristas
- **Fuentes:** DANE, Fenalco, investigación de habilidades digitales del tendero colombiano

---

## Historial de Cambios

| Fecha | Versión | Cambio |
|-------|---------|--------|
| 2026-01-27 | 1.0 | Documento inicial |
