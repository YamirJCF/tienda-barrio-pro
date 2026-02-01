# ARCH_002: Estándar de Estructura de Repositorio

## Contexto
El proyecto ha crecido y requiere una separación clara entre **Código Fuente**, **Documentación de Proyecto** y **Configuración de Infraestructura**. Actualmente, carpetas de gestión (01, 02, 03, 04) conviven en la raíz con el código (SRC), lo que dificulta la legibilidad y el despliegue.

## Principios de Organización
1.  **Separación de Responsabilidades**: El código desplegable debe vivir aislado de la documentación de gestión.
2.  **Estándar de Industria**: Uso de minúsculas y nombres convencionales (`frontend`, `backend`, `docs`).
3.  **Preparación para CI/CD**: Facilitar la creación de pipelines apuntando a carpetas específicas.

## Estructura Propuesta

### 1. `/documentation` (La Biblioteca)
Mover todas las carpetas numeradas que corresponden a la gestión del proyecto y conocimiento.
- `/documentation/01_requirements`
- `/documentation/02_architecture`
- `/documentation/03_ui_ux_design`
- `/documentation/04_dev_orchestration`
- `/documentation/legacy` (Archivos sueltos antiguos)

### 2. `/app` o `/frontend` (El Cliente)
Renombrar `SRC` a `clients/web` o simplemente `frontend`.
- Contiene el proyecto Vite/Vue.
- `package.json` propio.

### 3. `/backend` o `/supabase` (El Servidor)
Mantener la carpeta `supabase` como el núcleo del backend.
- Migraciones, Seeds, Config.
- Functions (Edge Functions).

### 4. Raíz Limpia
La raíz solo debe contener archivos de configuración global del repositorio.
- `.git`
- `.gitignore`
- `README.md`
- `package.json` (opcional, para scripts globales de orquestación)

---

## Plan de Migración (Script de Reorganización)

### Paso 1: Crear directorios base
```bash
mkdir documentation
mkdir frontend
```

### Paso 2: Mover Artefactos de Gestión
```bash
mv 01_REQUIREMENTS documentation/01_requirements
mv 02_ARCHITECTURE documentation/02_architecture
mv 03_UI_UX_DESIGN documentation/03_ui_ux_design
mv 03_UX_DESIGN documentation/03_legacy_ux
mv 04_DEV_ORCHESTRATION documentation/04_dev_orchestration
mv ADDENDUM_*.md documentation/
mv MAPA_RIESGOS_*.md documentation/
mv ORDENES_WE_TRABAJO.md documentation/
```

### Paso 3: Mover Código Fuente
```bash
mv SRC/* frontend/
rm -rf SRC
# Nota: La carpeta 'supabase' se queda en raíz o se mueve a 'backend' si se desea simetría.
# Recomendación: Dejar 'supabase' en raíz es estándar para Supabase CLI, pero para orden visual 'backend/supabase' es mejor.
# Por ahora, mantendremos 'supabase' en raíz para no romper la CLI si no es necesario reconfigurar.
```

### Paso 4: Unificar Docs Técnicos
La carpeta `docs` actual contiene guías de supabase.
```bash
mv docs documentation/technical_guides
```

---

## Estructura Final Visual
```text
/
├── .git/
├── .gitignore
├── README.md
├── documentation/          <-- Todo el conocimiento (NO SE DESPLIEGA)
│   ├── 01_requirements/
│   ├── 02_architecture/
│   ├── ...
├── frontend/               <-- Código Vue (SE DESPLIEGA A VERCEL/NETLIFY)
│   ├── src/
│   ├── index.html
│   ├── package.json
│   └── vite.config.ts
├── supabase/               <-- Código Backend (SE DESPLIEGA A SUPABASE)
│   ├── migrations/
│   ├── functions/
│   └── config.toml
└── scripts/                <-- Orquestación local (Opcional)
```
