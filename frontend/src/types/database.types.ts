export type Json =
    | string
    | number
    | boolean
    | null
    | { [key: string]: Json | undefined }
    | Json[]

export type Database = {
    // Allows to automatically instantiate createClient with right options
    // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
    __InternalSupabase: {
        PostgrestVersion: "14.1"
    }
    public: {
        Tables: {
            admin_profiles: {
                Row: {
                    created_at: string
                    id: string
                    is_verified: boolean | null
                    role: string
                    store_id: string
                }
                Insert: {
                    created_at?: string
                    id: string
                    is_verified?: boolean | null
                    role?: string
                    store_id: string
                }
                Update: {
                    created_at?: string
                    id?: string
                    is_verified?: boolean | null
                    role?: string
                    store_id?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "admin_profiles_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            audit_logs: {
                Row: {
                    actor_id: string | null
                    actor_role: string | null
                    created_at: string
                    event_type: string
                    id: string
                    ip_address: string | null
                    metadata: Json
                    severity: string
                    store_id: string
                    user_agent: string | null
                }
                Insert: {
                    actor_id?: string | null
                    actor_role?: string | null
                    created_at?: string
                    event_type: string
                    id?: string
                    ip_address?: string | null
                    metadata?: Json
                    severity?: string
                    store_id: string
                    user_agent?: string | null
                }
                Update: {
                    actor_id?: string | null
                    actor_role?: string | null
                    created_at?: string
                    event_type?: string
                    id?: string
                    ip_address?: string | null
                    metadata?: Json
                    severity?: string
                    store_id?: string
                    user_agent?: string | null
                }
                Relationships: [
                    {
                        foreignKeyName: "audit_logs_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            cash_movements: {
                Row: {
                    amount: number
                    created_at: string
                    description: string
                    id: string
                    movement_type: string
                    sale_id: string | null
                    session_id: string
                }
                Insert: {
                    amount: number
                    created_at?: string
                    description: string
                    id?: string
                    movement_type: string
                    sale_id?: string | null
                    session_id: string
                }
                Update: {
                    amount?: number
                    created_at?: string
                    description?: string
                    id?: string
                    movement_type?: string
                    sale_id?: string | null
                    session_id?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "cash_movements_sale_id_fkey"
                        columns: ["sale_id"]
                        isOneToOne: false
                        referencedRelation: "sales"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "cash_movements_session_id_fkey"
                        columns: ["session_id"]
                        isOneToOne: false
                        referencedRelation: "cash_sessions"
                        referencedColumns: ["id"]
                    },
                ]
            }
            cash_sessions: {
                Row: {
                    actual_balance: number | null
                    closed_at: string | null
                    closed_by: string | null
                    difference: number | null
                    expected_balance: number | null
                    id: string
                    opened_at: string
                    opened_by: string
                    opening_balance: number
                    status: string
                    store_id: string
                }
                Insert: {
                    actual_balance?: number | null
                    closed_at?: string | null
                    closed_by?: string | null
                    difference?: number | null
                    expected_balance?: number | null
                    id?: string
                    opened_at?: string
                    opened_by: string
                    opening_balance: number
                    status?: string
                    store_id: string
                }
                Update: {
                    actual_balance?: number | null
                    closed_at?: string | null
                    closed_by?: string | null
                    difference?: number | null
                    expected_balance?: number | null
                    id?: string
                    opened_at?: string
                    opened_by?: string
                    opening_balance?: number
                    status?: string
                    store_id?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "cash_sessions_closed_by_fkey"
                        columns: ["closed_by"]
                        isOneToOne: false
                        referencedRelation: "employees"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "cash_sessions_opened_by_fkey"
                        columns: ["opened_by"]
                        isOneToOne: false
                        referencedRelation: "employees"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "cash_sessions_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            client_transactions: {
                Row: {
                    amount: number
                    client_id: string
                    created_at: string
                    description: string | null
                    id: string
                    sale_id: string | null
                    transaction_type: string
                }
                Insert: {
                    amount: number
                    client_id: string
                    created_at?: string
                    description?: string | null
                    id?: string
                    sale_id?: string | null
                    transaction_type: string
                }
                Update: {
                    amount?: number
                    client_id?: string
                    created_at?: string
                    description?: string | null
                    id?: string
                    sale_id?: string | null
                    transaction_type?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "client_transactions_client_id_fkey"
                        columns: ["client_id"]
                        isOneToOne: false
                        referencedRelation: "clients"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "client_transactions_sale_id_fkey"
                        columns: ["sale_id"]
                        isOneToOne: false
                        referencedRelation: "sales"
                        referencedColumns: ["id"]
                    },
                ]
            }
            clients: {
                Row: {
                    balance: number | null
                    created_at: string
                    credit_limit: number
                    deleted_at: string | null
                    id: string
                    id_number: string
                    is_deleted: boolean | null
                    name: string
                    phone: string | null
                    store_id: string
                    updated_at: string
                }
                Insert: {
                    balance?: number | null
                    created_at?: string
                    credit_limit?: number
                    deleted_at?: string | null
                    id?: string
                    id_number: string
                    is_deleted?: boolean | null
                    name: string
                    phone?: string | null
                    store_id: string
                    updated_at?: string
                }
                Update: {
                    balance?: number | null
                    created_at?: string
                    credit_limit?: number
                    deleted_at?: string | null
                    id?: string
                    id_number?: string
                    is_deleted?: boolean | null
                    name?: string
                    phone?: string | null
                    store_id?: string
                    updated_at?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "clients_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            daily_passes: {
                Row: {
                    device_fingerprint: string | null
                    employee_id: string
                    id: string
                    pass_date: string
                    requested_at: string
                    resolved_at: string | null
                    resolved_by: string | null
                    retry_count: number | null
                    status: string
                }
                Insert: {
                    device_fingerprint?: string | null
                    employee_id: string
                    id?: string
                    pass_date?: string
                    requested_at?: string
                    resolved_at?: string | null
                    resolved_by?: string | null
                    retry_count?: number | null
                    status?: string
                }
                Update: {
                    device_fingerprint?: string | null
                    employee_id?: string
                    id?: string
                    pass_date?: string
                    requested_at?: string
                    resolved_at?: string | null
                    resolved_by?: string | null
                    retry_count?: number | null
                    status?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "daily_passes_employee_id_fkey"
                        columns: ["employee_id"]
                        isOneToOne: false
                        referencedRelation: "employees"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "daily_passes_resolved_by_fkey"
                        columns: ["resolved_by"]
                        isOneToOne: false
                        referencedRelation: "employees"
                        referencedColumns: ["id"]
                    },
                ]
            }
            daily_reports: {
                Row: {
                    average_ticket: number | null
                    cash_sales: number | null
                    closing_balance: number | null
                    created_at: string
                    credit_sales: number | null
                    difference: number | null
                    digital_sales: number | null
                    id: string
                    low_stock_alerts: number | null
                    opening_balance: number | null
                    products_sold: number | null
                    report_date: string
                    store_id: string
                    total_sales: number | null
                    total_transactions: number | null
                }
                Insert: {
                    average_ticket?: number | null
                    cash_sales?: number | null
                    closing_balance?: number | null
                    created_at?: string
                    credit_sales?: number | null
                    difference?: number | null
                    digital_sales?: number | null
                    id?: string
                    low_stock_alerts?: number | null
                    opening_balance?: number | null
                    products_sold?: number | null
                    report_date: string
                    store_id: string
                    total_sales?: number | null
                    total_transactions?: number | null
                }
                Update: {
                    average_ticket?: number | null
                    cash_sales?: number | null
                    closing_balance?: number | null
                    created_at?: string
                    credit_sales?: number | null
                    difference?: number | null
                    digital_sales?: number | null
                    id?: string
                    low_stock_alerts?: number | null
                    opening_balance?: number | null
                    products_sold?: number | null
                    report_date?: string
                    store_id?: string
                    total_sales?: number | null
                    total_transactions?: number | null
                }
                Relationships: [
                    {
                        foreignKeyName: "daily_reports_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            employees: {
                Row: {
                    created_at: string
                    display_name: string
                    id: string
                    is_active: boolean | null
                    name: string
                    permissions: Json
                    pin_hash: string
                    role: string
                    store_id: string
                    updated_at: string
                    username: string
                }
                Insert: {
                    created_at?: string
                    display_name?: string
                    id?: string
                    is_active?: boolean | null
                    name: string
                    permissions?: Json
                    pin_hash: string
                    role?: string
                    store_id: string
                    updated_at?: string
                    username: string
                }
                Update: {
                    created_at?: string
                    display_name?: string
                    id?: string
                    is_active?: boolean | null
                    name?: string
                    permissions?: Json
                    pin_hash?: string
                    role?: string
                    store_id?: string
                    updated_at?: string
                    username?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "employees_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            error_logs: {
                Row: {
                    context: Json | null
                    created_at: string
                    error_message: string
                    error_type: string
                    id: string
                    stack_trace: string | null
                    store_id: string | null
                    user_id: string | null
                    user_role: string | null
                }
                Insert: {
                    context?: Json | null
                    created_at?: string
                    error_message: string
                    error_type: string
                    id?: string
                    stack_trace?: string | null
                    store_id?: string | null
                    user_id?: string | null
                    user_role?: string | null
                }
                Update: {
                    context?: Json | null
                    created_at?: string
                    error_message?: string
                    error_type?: string
                    id?: string
                    stack_trace?: string | null
                    store_id?: string | null
                    user_id?: string | null
                    user_role?: string | null
                }
                Relationships: [
                    {
                        foreignKeyName: "error_logs_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            inventory_movements: {
                Row: {
                    created_at: string
                    created_by: string | null
                    id: string
                    movement_type: string
                    product_id: string
                    quantity: number
                    reason: string | null
                }
                Insert: {
                    created_at?: string
                    created_by?: string | null
                    id?: string
                    movement_type: string
                    product_id: string
                    quantity: number
                    reason?: string | null
                }
                Update: {
                    created_at?: string
                    created_by?: string | null
                    id?: string
                    movement_type?: string
                    product_id?: string
                    quantity?: number
                    reason?: string | null
                }
                Relationships: [
                    {
                        foreignKeyName: "inventory_movements_created_by_fkey"
                        columns: ["created_by"]
                        isOneToOne: false
                        referencedRelation: "employees"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "inventory_movements_product_id_fkey"
                        columns: ["product_id"]
                        isOneToOne: false
                        referencedRelation: "products"
                        referencedColumns: ["id"]
                    },
                ]
            }
            price_change_logs: {
                Row: {
                    changed_by: string | null
                    created_at: string
                    id: string
                    new_price: number
                    previous_price: number
                    product_id: string
                    reason: string | null
                }
                Insert: {
                    changed_by?: string | null
                    created_at?: string
                    id?: string
                    new_price: number
                    previous_price: number
                    product_id: string
                    reason?: string | null
                }
                Update: {
                    changed_by?: string | null
                    created_at?: string
                    id?: string
                    new_price?: number
                    previous_price?: number
                    product_id?: string
                    reason?: string | null
                }
                Relationships: [
                    {
                        foreignKeyName: "price_change_logs_changed_by_fkey"
                        columns: ["changed_by"]
                        isOneToOne: false
                        referencedRelation: "employees"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "price_change_logs_product_id_fkey"
                        columns: ["product_id"]
                        isOneToOne: false
                        referencedRelation: "products"
                        referencedColumns: ["id"]
                    },
                ]
            }
            products: {
                Row: {
                    plu: string | null
                    brand: string | null
                    category: string | null
                    cost_price: number | null
                    created_at: string
                    current_stock: number
                    id: string
                    is_weighable: boolean | null
                    low_stock_alerted: boolean | null
                    measurement_unit: string
                    min_stock: number
                    name: string
                    price: number
                    store_id: string
                    updated_at: string
                }
                Insert: {
                    plu?: string | null
                    brand?: string | null
                    category?: string | null
                    cost_price?: number | null
                    created_at?: string
                    current_stock?: number
                    id?: string
                    is_weighable?: boolean | null
                    low_stock_alerted?: boolean | null
                    measurement_unit?: string
                    min_stock?: number
                    name: string
                    price: number
                    store_id: string
                    updated_at?: string
                }
                Update: {
                    plu?: string | null
                    brand?: string | null
                    category?: string | null
                    cost_price?: number | null
                    created_at?: string
                    current_stock?: number
                    id?: string
                    is_weighable?: boolean | null
                    low_stock_alerted?: boolean | null
                    measurement_unit?: string
                    min_stock?: number
                    name?: string
                    price?: number
                    store_id?: string
                    updated_at?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "products_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            sale_items: {
                Row: {
                    created_at: string
                    id: string
                    product_id: string
                    quantity: number
                    sale_id: string
                    subtotal: number
                    unit_price: number
                }
                Insert: {
                    created_at?: string
                    id?: string
                    product_id: string
                    quantity: number
                    sale_id: string
                    subtotal: number
                    unit_price: number
                }
                Update: {
                    created_at?: string
                    id?: string
                    product_id?: string
                    quantity?: number
                    sale_id?: string
                    subtotal?: number
                    unit_price?: number
                }
                Relationships: [
                    {
                        foreignKeyName: "sale_items_product_id_fkey"
                        columns: ["product_id"]
                        isOneToOne: false
                        referencedRelation: "products"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "sale_items_sale_id_fkey"
                        columns: ["sale_id"]
                        isOneToOne: false
                        referencedRelation: "sales"
                        referencedColumns: ["id"]
                    },
                ]
            }
            sales: {
                Row: {
                    amount_received: number | null
                    change_given: number | null
                    client_id: string | null
                    created_at: string
                    employee_id: string
                    id: string
                    is_voided: boolean | null
                    local_id: string | null
                    payment_method: string
                    rounding_difference: number | null
                    store_id: string
                    sync_status: string | null
                    ticket_number: number
                    total: number
                    void_reason: string | null
                    voided_by: string | null
                }
                Insert: {
                    amount_received?: number | null
                    change_given?: number | null
                    client_id?: string | null
                    created_at?: string
                    employee_id: string
                    id?: string
                    is_voided?: boolean | null
                    local_id?: string | null
                    payment_method: string
                    rounding_difference?: number | null
                    store_id: string
                    sync_status?: string | null
                    ticket_number: number
                    total: number
                    void_reason?: string | null
                    voided_by?: string | null
                }
                Update: {
                    amount_received?: number | null
                    change_given?: number | null
                    client_id?: string | null
                    created_at?: string
                    employee_id?: string
                    id?: string
                    is_voided?: boolean | null
                    local_id?: string | null
                    payment_method?: string
                    rounding_difference?: number | null
                    store_id?: string
                    sync_status?: string | null
                    ticket_number?: number
                    total?: number
                    void_reason?: string | null
                    voided_by?: string | null
                }
                Relationships: [
                    {
                        foreignKeyName: "sales_client_id_fkey"
                        columns: ["client_id"]
                        isOneToOne: false
                        referencedRelation: "clients"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "sales_employee_id_fkey"
                        columns: ["employee_id"]
                        isOneToOne: false
                        referencedRelation: "employees"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "sales_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "sales_voided_by_fkey"
                        columns: ["voided_by"]
                        isOneToOne: false
                        referencedRelation: "employees"
                        referencedColumns: ["id"]
                    },
                ]
            }
            stores: {
                Row: {
                    address: string | null
                    business_category: string | null
                    created_at: string
                    currency: string
                    email: string | null
                    id: string
                    is_active: boolean | null
                    is_temporarily_closed: boolean
                    logo_url: string | null
                    name: string
                    phone: string | null
                    settings: Json
                    slug: string
                    subscription_plan: string
                    timezone: string
                    updated_at: string
                }
                Insert: {
                    address?: string | null
                    business_category?: string | null
                    created_at?: string
                    currency?: string
                    email?: string | null
                    id: string
                    is_active?: boolean | null
                    is_temporarily_closed?: boolean
                    logo_url?: string | null
                    name: string
                    phone?: string | null
                    settings?: Json
                    slug: string
                    subscription_plan?: string
                    timezone?: string
                    updated_at?: string
                }
                Update: {
                    address?: string | null
                    business_category?: string | null
                    created_at?: string
                    currency?: string
                    email?: string | null
                    id?: string
                    is_active?: boolean | null
                    is_temporarily_closed?: boolean
                    logo_url?: string | null
                    name?: string
                    phone?: string | null
                    settings?: Json
                    slug?: string
                    subscription_plan?: string
                    timezone?: string
                    updated_at?: string
                }
                Relationships: []
            }
            sync_queue: {
                Row: {
                    created_at: string
                    entity_id: string
                    entity_type: string
                    id: string
                    last_error: string | null
                    payload: Json
                    retry_count: number | null
                    status: string
                    store_id: string
                    synced_at: string | null
                }
                Insert: {
                    created_at?: string
                    entity_id: string
                    entity_type: string
                    id?: string
                    last_error?: string | null
                    payload: Json
                    retry_count?: number | null
                    status?: string
                    store_id: string
                    synced_at?: string | null
                }
                Update: {
                    created_at?: string
                    entity_id?: string
                    entity_type?: string
                    id?: string
                    last_error?: string | null
                    payload?: Json
                    retry_count?: number | null
                    status?: string
                    store_id?: string
                    synced_at?: string | null
                }
                Relationships: [
                    {
                        foreignKeyName: "sync_queue_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
        }
        Views: {
            [_ in never]: never
        }
        Functions: {
            abrir_caja: {
                Args: {
                    p_store_id: string
                    p_employee_id: string
                    p_opening_balance: number
                }
                Returns: Json
            }
            aprobar_pase_diario: {
                Args: {
                    p_pass_id: string
                    p_admin_id: string
                }
                Returns: Json
            }
            cerrar_caja: {
                Args: {
                    p_session_id: string
                    p_employee_id: string
                    p_actual_balance: number
                }
                Returns: Json
            }
            crear_empleado: {
                Args: {
                    p_store_id: string
                    p_name: string
                    p_username: string
                    p_pin: string
                    p_permissions?: Json
                }
                Returns: Json
            }
            expire_daily_passes: {
                Args: Record<PropertyKey, never>
                Returns: unknown
            }
            get_current_employee_id: {
                Args: Record<PropertyKey, never>
                Returns: string
            }
            get_current_store_id: {
                Args: Record<PropertyKey, never>
                Returns: string
            }
            is_admin: {
                Args: Record<PropertyKey, never>
                Returns: boolean
            }
            log_price_change: {
                Args: Record<PropertyKey, never>
                Returns: unknown
            }
            log_security_event: {
                Args: {
                    p_store_id: string
                    p_event_type: string
                    p_severity?: string
                    p_actor_id?: string
                    p_actor_role?: string
                    p_metadata?: Json
                }
                Returns: string
            }
            procesar_venta: {
                Args: {
                    p_store_id: string
                    p_employee_id: string
                    p_items: Json
                    p_total: number
                    p_payment_method: string
                    p_amount_received?: number
                    p_client_id?: string
                    p_local_id?: string
                }
                Returns: Json
            }
            registrar_abono: {
                Args: {
                    p_client_id: string
                    p_amount: number
                }
                Returns: Json
            }
            solicitar_pase_diario: {
                Args: {
                    p_employee_id: string
                    p_device_fingerprint?: string
                }
                Returns: Json
            }
            update_product_stock: {
                Args: Record<PropertyKey, never>
                Returns: unknown
            }
            update_timestamp: {
                Args: Record<PropertyKey, never>
                Returns: unknown
            }
            validar_pin_empleado: {
                Args: {
                    p_username: string
                    p_pin: string
                }
                Returns: Json
            }
        }
        Enums: {
            [_ in never]: never
        }
        CompositeTypes: {
            [_ in never]: never
        }
    }
}
