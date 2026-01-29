## Orden de Trabajo - Exportación de Reportes (RE-03)

### Contexto
El reporte de auditoría (RE-03) menciona que los administradores necesitan extraer la data para contabilidad externa. Actualmente no hay opción de exportar los reportes de ventas.
**Objetivo**: Permitir descargar el reporte de ventas actual en formato PDF (para impresión) y Excel (para análisis).

### Estado Git Actual
- Rama a crear: `feat/re-03-export-reports`
- Comando: `git checkout -b feat/re-03-export-reports`

---

### Plan de Acción Atómico

#### Tarea 1: Instalación de Dependencias
- `jspdf`: Generación de PDF.
- `jspdf-autotable`: Tablas en PDF.
- `xlsx`: Exportación a Excel.
- Comando: `npm install jspdf jspdf-autotable xlsx`

#### Tarea 2: Composable de Exportación
**Archivo**: `src/composables/useReportExport.ts` (Nuevo)
- Crear funciones:
    - `exportToPDF(data: any[], title: string)`:
        - Crear documento A4.
        - Agregar título, fecha, y totales.
        - Generar tabla con columnas: Fecha, ID, Empleado, Método, Total.
    - `exportToExcel(data: any[], fileName: string)`:
        - Crear hoja "Ventas".
        - Mapear datos a formato plano.
        - Guardar archivo `.xlsx`.

#### Tarea 3: Integración UI
**Archivo**: `src/components/ReportsContent.vue`
- Agregar botones de exportación en el header (junto a los filtros).
- Botón "PDF" (Icono FileText).
- Botón "Excel" (Icono Sheet/Table).
- Conectar con `useReportExport`.

### Bloque de Prompt para Antigravity

```markdown
## Prompt para RE-03 (Exportación)

### Contexto
- Nuevo Composable: `src/composables/useReportExport.ts`
- Vista: `src/components/ReportsContent.vue`

### Requerimientos
1. **Composable**:
   - `exportSalesToPDF(sales, dateRange)`
   - `exportSalesToExcel(sales, dateRange)`
   - Usar `jspdf` y `xlsx`.
2. **UI**:
   - Agregar botones flotantes o en header para "Exportar PDF" y "Exportar Excel".
   - Deshabilitar si `isLoading` o no hay datos.
```

### Comandos de Consola
```bash
git checkout -b feat/re-03-export-reports
npm install jspdf jspdf-autotable xlsx
```
