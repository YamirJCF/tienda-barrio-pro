# Reporte de Auditoría UX/UI (Atomic Checklist)

> **Estado:** 🚧 En Progreso
> **Responsable:** Equipo UX/UI (@[/ux])
> **Fecha Inicio:** 2026-01-28
> **Referencia:** `WORK_REQUEST_UX_UI.md`, `QA_ADDENDUM_UX_UI.md` y FRDs

## 1. Resumen Ejecutivo
Este documento desglosa los FRDs en **Tareas Atómicas de Verificación**. Cada fila representa un punto de chequeo binario (Pasa/No Pasa).

**Instrucciones:**
1.  Verificar cada item en la UI.
2.  Marcar estado (✅/❌).
3.  Si falla (❌), crear una entrada en la sección "Hallazgos de Discrepancia".

---

## 2. Checklists Atómicos por Módulo

### 2.1 Autenticación (001, 002, 013)
| ID | FRD | Punto de Verificación Atómico | Estado | Nota |
|----|-----|-------------------------------|--------|------|
| AU-01 | 001 | Login pide Alias y PIN (no email) para empleados | ✅ | Logica detecta @ correctamente |
| AU-02 | 001 | PIN type="password" (enmascarado) | ✅ | |
| AU-03 | 001 | Teclado numérico virtual disponible en login | ❌ | Usa teclado sistema (BaseInput) |
| AU-04 | 001 | Mensaje "Esperando aprobación" si no tiene pase | ✅ | Captura error GATEKEEPER_PENDING |
| AU-05 | 001 | Botón "Reenviar alerta" (max 3 veces) visible en espera | ❌ | Solo muestra texto de error |
| AU-06 | 002 | Registro de tienda pide Nombre, Slug, Email Admin | ✅ | Slug auto-generado (ok) |
| AU-07 | 002 | Registro valida contraseña fuerte visualmente | ❌ | Solo valida longitud > 6 |
| AU-08 | 013 | Cierre de sesión redirige a Login y limpia credenciales | ✅ | Store reset state ok |

### 2.2 Gestión de Personal (003)
| ID | FRD | Punto de Verificación Atómico | Estado | Nota |
|----|-----|-------------------------------|--------|------|
| PE-01 | 003 | Lista muestra empleados con indicador Activo/Inactivo | ✅ | Visual diferenciado y Toggle |
| PE-02 | 003 | Botón "Nuevo Empleado" bloqueado si hay >=5 activos | ✅ | Lógica correcta en FAB y EmptyState |
| PE-03 | 003 | Formulario nuevo emp. pide: Nombre, Alias, PIN, Permisos | ✅ | Campos completos y validan |
| PE-04 | 003 | Input PIN fuerza 4 dígitos exactos | ✅ | Maxlength 4 y filtro numérico |
| PE-05 | 003 | Opción "Desactivar" muestra confirmación (modal) | ❌ | Toggle es instantáneo (falta confirmar) |
| PE-06 | 003 | "Restablecer PIN" permite asignar nuevo PIN sin el anterior | ✅ | Modal directo para Admin |

### 2.3 Caja y POS (004, 007)
| ID | FRD | Punto de Verificación Atómico | Estado | Nota |
|----|-----|-------------------------------|--------|------|
| PO-01 | 004 | Pantalla de Venta bloqueada si caja cerrada | ✅ | BlockingOverlay funciona |
| PO-02 | 004 | Apertura de caja pide PIN de seguridad | ❌ | Solo pide monto, falta PIN confirmación |
| PO-03 | 004 | Apertura de caja pide Monto Base inicial | ✅ | Input numérico presente |
| PO-04 | 004 | Cierre de caja muestra resumen esperado vs real | ✅ | Cálculo de diferencia OK |
| PO-05 | 007 | Buscador de productos por nombre y PLU funciona | ✅ | SearchModal y Numpad OK |
| PO-06 | 007 | Agregar producto valida stock disponible (no negativo) | ✅ | CartStore bloquea si no hay stock |
| PO-07 | 007 | Carrito muestra subtotales redondeados | ✅ | RoundToNearest50 implementado |
| PO-08 | 007 | Checkout permite pago mixto o efectivo simple | ✅ | Implementado (Lista Acumulativa) |
| PO-09 | 007 | Pago con efectivo calcula vueltas automáticamente | ✅ | UI muestra vueltas en verde |
| PO-10 | 007 | Botón "Cobrar" deshabilita tras primer click | ✅ | Estado loading bloquea |

### 2.4 Inventario (006)
| ID | FRD | Punto de Verificación Atómico | Estado | Nota |
|----|-----|-------------------------------|--------|------|
| IN-01 | 006 | Lista muestra Stock, Precio y Unidad | ✅ | Cards completas |
| IN-02 | 006 | Campo "Costo" oculto si no es Admin | ❌ | ProductFormModal lo muestra siempre |
| IN-03 | 006 | Formulario producto valida precio > 0 | ✅ | isValid incluye check > 0 |
| IN-04 | 006 | Input stock inicial no permite negativos | ✅ | min="0" en input |
| IN-05 | 006 | Kardex visible por producto (historial movimientos) | ✅ | Botón history e implementación ok |

### 2.5 Clientes y Créditos (009)
| ID | FRD | Punto de Verificación Atómico | Estado | Nota |
|----|-----|-------------------------------|--------|------|
| CL-01 | 009 | Lista clientes muestra Balance y Cupo | ❌ | Falta mostrar Cupo |
| CL-02 | 009 | Indicador visual de deuda (Rojo/Verde) funciona | ✅ | Bordes y textos de color ok |
| CL-03 | 009 | Crear Cliente asigna cupo predeterminado | ❌ | No asigna valor por defecto |
| CL-04 | 009 | Checkout "Fiado" bloqueado si cupo excedido | ✅ | hasEnoughCredit computado en POS |
| CL-05 | 009 | Registrar Abono valida monto <= deuda total | ❌ | Permite abono mayor a deuda (saldo neg) |
| CL-06 | 009 | Botón "Eliminar" deshabilitado si tiene deuda | ❌ | Permite eliminar deudores sin check |

### 2.6 Reportes y Finanzas (FRD-007)
| ID | FRD | Punto de Verificación Atómico | Estado | Nota |
|----|-----|-------------------------------|--------|------|
| RE-01 | 007 | Vista de Gastos permite registrar salidas | ✅ | ExpensesView funciona |
| RE-02 | 007 | Reporte de Ventas Diarias visible | ❌ | No existe vista de reportes |
| RE-03 | 007 | Reporte de Ganancias (Margen) visible | ❌ | No existe vista de reportes |
| RE-04 | 007 | Historial de Ventas General | ❌ | Solo existe en Cierre de Caja |

### 2.7 UX Transversal (011, 012, QA)
| ID | FRD | Punto de Verificación Atómico | Estado | Nota |
|----|-----|-------------------------------|--------|------|
| UX-01 | 012 | Indicador "Offline" visible al desconectar red | ✅ | OfflineBanner implementado |
| UX-02 | 012 | Notificación "Conexión restablecida" aparece al volver | ✅ | useNetworkStatus notifica |
| UX-03 | QA | Skeletons visibles durante carga de datos | ❌ | No se usan skeletons, solo spinners o nada |
| UX-04 | QA | Toasts usados para éxitos/errores ligeros | ✅ | ToastNotification global |
| UX-05 | QA | Modales usados para confirmaciones destructivas | ✅ | BaseModal usado extensivamente |

---

## 3. Hallazgos de Discrepancia (The Punch List)

*Registrar aquí ÚNICAMENTE los items que fallaron en el checklist anterior.*

| ID Check | Módulo | Descripción del Fallo (Esperado vs Real) | Severidad | Estado |
|----------|--------|------------------------------------------|-----------|--------|
| AU-03 | Auth | **Falta Keypad en Login**: El usuario debe usar teclado del sistema. Se requiere `PinKeypad` para UX POS. | 🟠 Media | ⬜ Pendiente |
| AU-05 | Auth | **Falta Sala de Espera**: Al recibir `GATEKEEPER_PENDING`, solo muestra un texto rojo. Debería mostrar pantalla de espera con botón de reintento. | 🔴 Alta | ⬜ Pendiente |
| AU-07 | Auth | **Password Débil**: Registro permite "123456”. FRD exige 8 caracteres + alfanumérico. | 🟠 Media | ⬜ Pendiente |
| PE-05 | Personal | **Falta Confirmación al Desactivar**: El toggle de estado es instantáneo. FRD exige modal de confirmación para evitar accidentes. | 🔵 Baja | ⬜ Pendiente |
| PO-02 | POS | **Falta PIN en Apertura Caja**: El cajero puede abrir caja solo con el monto. Se requiere confirmar PIN para auditoría. | 🟠 Media | ⬜ Pendiente |
| IN-02 | Inventario | **Costo Visible sin Permisos**: El formulario de producto muestra el campo Costo a todos los usuarios. Debe ocultarse para empleados sin rol Administrativo. | 🟠 Media | ⬜ Pendiente |
| CL-01 | Clientes | **Falta Cupo en Lista**: La tarjeta de cliente en lista solo muestra el Balance, pero no el Cupo de Crédito asignado. | 🔵 Baja | ⬜ Pendiente |
| CL-06 | Clientes | **Eliminación Insegura**: El sistema permite eliminar clientes con deuda pendiente sin validación previa. Riesgo de pérdida financiera. | 🔴 Alta | ⬜ Pendiente |
| RE-02 | Reportes | **Falta Módulo de Reportes**: No existe una vista dedicada para consultar historial de ventas o ganancias fuera del cierre de caja. | 🔴 Alta | ⬜ Pendiente |
| UX-03 | UX | **Falta Feedback de Carga (Skeletons)**: Las listas (Inventario, Clientes) no muestran estado de carga, pareciendo vacías hasta que llegan los datos. | 🔵 Baja | ⬜ Pendiente |
