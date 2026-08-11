# DICT-003: Daily Pass Status (Estado del Pase Diario)

**Versión:** 1.0  
**Fecha:** 2026-08-11  
**Autor:** Arquitecto de Producto  
**FRD Relacionado:** [FRD-001: Seguridad Diaria](../FRD/FRD_001_SEGURIDAD_DIARIA.md)

---

## Dominio

Controla el ciclo de vida del Pase Diario de seguridad para un empleado, dictaminando su derecho a interactuar con el sistema según POL-SEG-02.

---

## Valores Permitidos

### `pass_status`

Define el estado actual de un pase diario de un empleado.

| Valor Técnico | Término de Negocio | Semántica |
|---------------|-------------------|-----------|
| `'pending'` | Pendiente | Pase solicitado, esperando aprobación del Administrador. |
| `'approved'` | Aprobado | Pase validado; el empleado puede operar el sistema. |
| `'rejected'` | Rechazado | El Administrador denegó el acceso explícitamente. |
| `'expired'` | Expirado | El pase sobrepasó su límite de vigencia temporal estricto de 24 horas. |

---

## Reglas de Negocio

### 1. Transiciones de Estado
- Un pase nace obligatoriamente en `'pending'`.
- De `'pending'` puede pasar a `'approved'` o `'rejected'`.
- De `'approved'` pasa a `'expired'` al cumplirse 24 horas exactas desde el momento de su aprobación.
- Un pase `'rejected'` o `'expired'` es un estado terminal (inmutable). No puede ser revivido, reactivado, ni reciclado. 

### 2. Autorización de Acceso
Únicamente el estado `'approved'` otorga permisos para entrar al sistema en modo operativo. Cualquier otro estado resulta en un bloqueo a nivel de Interfaz y de API (Sala de Espera).

---

## Valores NO Permitidos

| Valor Incorrecto | Razón |
|------------------|-------|
| `'active'` | Usar `'approved'` para reflejar explícitamente la acción de autorización. |
| `'waiting'` | Usar `'pending'`. |
| `'closed'` | Usar `'expired'` ya que el cierre no es una acción manual sino una caducidad temporal estricta. |
