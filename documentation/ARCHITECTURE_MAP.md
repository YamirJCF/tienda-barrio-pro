# Mapa de Arquitectura del Sistema - Tienda de Barrio Pro

> **Versión:** 1.0  
> **Fecha:** 15 de Febrero, 2026  
> **Enfoque:** Arquitectura Backend-First & Módulos de Inteligencia

---

## 1. Visión General y Stack Tecnológico

El sistema sigue una arquitectura **Backend-First**, donde Supabase (PostgreSQL) actúa como la única fuente de verdad, gestionando la lógica de negocio crítica, cálculos financieros y seguridad mediante RLS (Row Level Security) y RPCs (Remote Procedure Calls). El Frontend es un cliente ligero enfocado en UX.

### Tech Stack

| Capa | Tecnología | Rol Principal |
|------|------------|---------------|
| **Frontend** | **Vue 3** (Composition API) | Framework reactivo de UI. |
| **Estado** | **Pinia** | Gestión de estado local (Store). |
| **Estilos** | **Tailwind CSS v4** | Diseño utilitario y responsivo. |
| **Backend** | **Supabase** (PostgreSQL 15) | Base de datos, Auth, Realtime, Storage. |
| **Lógica** | **PL/pgSQL (RPCs & Triggers)** | Reglas de negocio, transacciones, libros mayores. |
| **Infra** | **Vercel** / **Edge Network** | Despliegue y distribución global. |

---

## 2. Diagrama de Módulos Principales

El sistema se divide en **Capas Funcionales** que interactúan a través de Stores y RPCs.

```mermaid
graph TD
    subgraph "Cliente (Frontend)"
        User((Usuario))
        
        subgraph "Capa de Presentación (Views)"
            POS[📍 POS (Punto de Venta)]
            Admin[🛠️ Admin Hub]
            Dash[📊 Dashboard]
            History[📜 Historial y Auditoría]
        end

        subgraph "Capa de Lógica UX (Stores/Composables)"
            AuthStore[🔐 Auth UseStore]
            SalesStore[💰 Sales UseStore]
            RepStore[📈 Reports UseStore]
            HistComp[🧩 useHistory Composable]
        end
    end

    subgraph "Servidor (Supabase)"
        subgraph "API & Seguridad"
            RPC[⚡ RPCs (Funciones)]
            RLS[🛡️ RLS Policies]
        end

        subgraph "Base de Datos"
            Tables[(postgreSQL DB)]
            Triggers[⚙️ Triggers (Kardex/Stock)]
        end
    end

    %% Relaciones
    User --> POS
    User --> Admin
    
    POS --> SalesStore
    Admin --> RepStore
    History --> HistComp
    
    SalesStore -->|"rpc('procesar_venta')"| RPC
    RepStore -->|"rpc('get_daily_summary')"| RPC
    HistComp -->|"rpc('get_history_*')"| RPC
    
    RPC --> Tables
    Tables -->|"Trigger Updates"| Triggers
    Triggers --> Tables
```

---

## 3. Flujo de Datos Arquitectónico

El flujo de datos obedece estrictamente al principio de **"Backend Authority"**.

1.  **Lectura (Read)**:
    *   **UI** solicita datos al **Store**.
    *   **Store** invoca cliente Supabase (`.select()` o `.rpc()`).
    *   **RLS** filtra los datos según el rol del usuario (Ej. Vendedores no ven costos).
    *   Datos retornan a la UI.

2.  **Escritura (Write / Action)**:
    *   Usuario ejecuta acción (Ej. "Cobrar").
    *   **Store** llama a una **RPC Transaccional** (Ej. `procesar_venta`).
    *   **Base de Datos** ejecuta la lógica ACID:
        *   Resta inventario.
        *   Crea registro de venta.
        *   Calcula cambio.
        *   Dispara Triggers (Kardex, Alertas).
    *   **Respuesta**: Éxito/Fallo retorna al Frontend.

---

## 4. Enfoque: Reportes e Historiales

Estos módulos representan la "Capa de Inteligencia" y tienen una ubicación específica en la arquitectura actual.

### 4.1. Módulo de Reportes ("Inteligencia en Tiempo Real")

*   **Ubicación UI**: `AdminHubView.vue` (Pestaña "Reportes") -> `SmartDailySummary.vue`.
*   **Gestión de Estado**: `stores/reports.ts` (`useReportsStore`).
*   **Fuente de Datos**: RPC `get_daily_summary`.
*   **Estrategia**:
    *   No se calculan totales en el frontend.
    *   El backend responde con un objeto **"pre-digerido"** listo para renderizar, incluyendo lógica de semáforos y alertas.
    *   **Payload Típico**:
        ```typescript
        interface DailySummary {
            traffic_light: { status: 'green'|'red', message: 'Ventas estables' };
            hero_number: 1500000; // Total vendido
            alerts: [{ type: 'stock_low', message: 'Leche se acaba' }];
        }
        ```

### 4.2. Módulo de Historiales ("Trazabilidad y Auditoría")

*   **Ubicación UI**: `HistoryView.vue`.
*   **Lógica de Negocio**: `composables/useHistory.ts`.
*   **Fuente de Datos**: Múltiples RPCs especializados según la pestaña activa.
    *   `rpc('get_history_ventas')`
    *   `rpc('get_history_caja')`
    *   `rpc('get_history_compras')`
*   **Patrón de Diseño**:
    *   **Lazy Loading**: Solo carga el historial del tipo seleccionado (Ventas, Caja, Auditoría).
    *   **Filtrado en Servidor**: Los filtros de fecha y empleado se envían como parámetros a la RPC, optimizando la transferencia de datos.
    *   **Unificación Visual**: El frontend normaliza las respuestas distintas en una interfaz común `HistoryItem` (Icono, Título, Subtítulo, Monto, Color).

---

## 5. Mapeo de Componentes Clave

| Módulo | Vista Principal | Store/Composable | Tabla/RPC Principal |
|--------|-----------------|------------------|---------------------|
| **POS** | `POSView.vue` | `useCartStore`, `useSalesStore` | `procesar_venta()` |
| **Caja** | `CashControlView.vue` | `useCashRegisterStore` | `cash_registers` |
| **Reportes** | `AdminHubView.vue` | `useReportsStore` | `get_daily_summary` |
| **Historial** | `HistoryView.vue` | `useHistory` | `get_history_*` |
| **Auth** | `LoginView.vue` | `useAuthStore` | `auth.users`, `employees` |

