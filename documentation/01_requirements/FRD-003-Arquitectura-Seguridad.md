# Estrategia de Arquitectura y Seguridad (Cumplimiento SaaS)

Para que el sistema sea extremadamente fácil de usar para los "tenderos" pero internamente robusto y auditado según las leyes colombianas (Ley 1581 de Habeas Data) e internacionales (Bases de ISO 27001 / GDPR), aplicaremos de manera estricta nuestro contrato de arquitectura: **Backend Define la Verdad, Frontend Define la Experiencia**.

## 1. Cumplimiento de la Ley 1581 (Habeas Data Colombia)

Dado que seremos un SaaS que procesa datos de terceros (los clientes del tendero), actuamos legalmente como **"Encargados del Tratamiento"**, mientras que el tendero es el **"Responsable"**. 

Nuestra arquitectura tecnológica para cumplir esto es:
- **Aislamiento Multi-Tenant Crítico (RLS):** Supabase será configurado con Políticas de Seguridad a Nivel de Fila (Row Level Security - RLS). Un tendero nunca podrá, ni inyectando código malicioso en el navegador, acceder a la base de datos de los clientes de otro tendero. La base de datos rechaza la consulta en la capa más baja.
- **Derecho al Olvido y Anónimidad:** Según la ley, si un comprador exige que borren sus datos, el sistema no puede afectar la contabilidad del tendero. La Base de Datos (Backend) implementará rutinas (RPC) que hagan un *Soft-Delete* de la cuenta del ciudadano, cambiando su nombre a "Usuario Anónimo" y desligando su cédula, para mantener la legalidad del ticket sin violar su derecho de Habeas Data.
- **Trazabilidad (Logs Auditables):** Todo borrado o descuento grande dejará una huella imborrable en el backend. 

## 2. Enfoque "Zero-Trust" en el Frontend (Anti-Fraude)

Para que la experiencia del tendero sea fluida (cero cuelgues, botones grandes, cajas rápidas) pero inmune a robos por empleados deshonestos:
- **La UI no piensa matemáticamente:** El frontend (Vue) jamás suma los precios de los productos en el carrito. Si el cajero manipula el Javascript del navegador para intentar vender algo más barato, no servirá de nada. El frontend solo envía la "intención" al Backend (`[id_producto_1, id_producto_2]`), y nuestro servidor en Supabase re-calcula las matemáticas financieras reales usando los precios encriptados de la tabla maestra.
- **Tokens Efímeros de Acceso:** Uso de JWT (JSON Web Tokens) que expiran corto tiempo. Si un empleado copia una sesión de la tablet de la tienda, será expulsada automáticamente.
- **Cierre de Caja en el Servidor:** El cuadre de efectivo se bloquea transaccionalmente; datos en vuelo se refutan contra la hora exacta del servidor (PostgreSQL timestamp), evitando trucos al cambiar la hora de las cajas registradoras de Windows Android.

## 3. Seguridad Internacional y Control de la Nube (ISO 27001/GDPR)
- **Principio de Mínimo Privilegio:** Ninguna conexión a Supabase se hace usando usuarios administradores generales (`postgres`). Toda conexión desde la App de Vue utiliza un rol anónimo sin privilegios, que obtiene permisos granulares únicamente al inyectar el Token (JWT) del usuario válido. 
- **Backups y Recuperación de Desastres:** Dado que las facturas deben reposar años para la DIAN, y el PT asume el documento, nosotros almacenamos los *links* validados a la nube. Si nuestro servidor cae, los enlaces al PT están salvaguardados en copias de seguridad continuas de Supabase (Point-in-Time Recovery - PITR).

---
### Resumen del Flujo de Protección de Punto a Punto

1. **El Tendero (UI Simple):** Presiona "Añadir Galletas" y confía en el sistema ciegamente. Nunca tiene que lidiar con permisos complejos, solo ve sus datos con un diseño premium.
2. **El Frontend (Vue):** Presenta una interfaz hermosa con estado transitorio en 'Pinia'. Transmite la acción del cajero.
3. **El Servidor (Supabase):** Verifica la sesión JWT $\to$ Valida Políticas RLS $\to$ Aplica lógicas financieras RPC $\to$ Escribe en disco la auditoría $\to$ Devuelve la orden sellada y segura al UI.
