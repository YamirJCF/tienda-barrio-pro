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
                    event_type: string
                    id?: string
                    ip_address?: string | null
                    metadata?: Json
                    severity?: string
                    store_id: string
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
                    created_by: string
                    description: string | null
                    id: string
                    movement_type: string
                    payment_method: string | null
                    related_entity_id: string | null
                    related_entity_type: string | null
                    session_id: string
                    store_id: string
                }
                Insert: {
                    amount: number
                    created_at?: string
                    created_by: string
                    description?: string | null
                    id?: string
                    movement_type: string
                    payment_method?: string | null
                    related_entity_id?: string | null
                    related_entity_type?: string | null
                    session_id: string
                    store_id: string
                }
                Update: {
                    amount?: number
                    created_at?: string
                    created_by?: string
                    description?: string | null
                    id?: string
                    movement_type?: string
                    payment_method?: string | null
                    related_entity_id?: string | null
                    related_entity_type?: string | null
                    session_id?: string
                    store_id?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "cash_movements_created_by_fkey"
                        columns: ["created_by"]
                        isOneToOne: false
                        referencedRelation: "employees"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "cash_movements_session_id_fkey"
                        columns: ["session_id"]
                        isOneToOne: false
                        referencedRelation: "cash_sessions"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "cash_movements_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            cash_sessions: {
                Row: {
                    actual_balance: number | null
                    closed_at: string | null
                    closed_by: string | null
                    created_at: string
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
                    created_at?: string
                    difference?: number | null
                    expected_balance?: number | null
                    id?: string
                    opened_at?: string
                    opened_by: string
                    opening_balance?: number
                    status?: string
                    store_id: string
                }
                Update: {
                    actual_balance?: number | null
                    closed_at?: string | null
                    closed_by?: string | null
                    created_at?: string
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
            clients: {
                Row: {
                    address: string | null
                    balance: number | null
                    created_at: string
                    email: string | null
                    id: string
                    name: string
                    notes: string | null
                    phone: string | null
                    store_id: string
                    updated_at: string
                }
                Insert: {
                    address?: string | null
                    balance?: number | null
                    created_at?: string
                    email?: string | null
                    id?: string
                    name: string
                    notes?: string | null
                    phone?: string | null
                    store_id: string
                    updated_at?: string
                }
                Update: {
                    address?: string | null
                    balance?: number | null
                    created_at?: string
                    email?: string | null
                    id?: string
                    name?: string
                    notes?: string | null
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
                        referencedRelation: "admin_profiles"
                        referencedColumns: ["id"]
                    },
                ]
            }
            employees: {
                Row: {
                    created_at: string
                    id: string
                    is_active: boolean
                    name: string
                    permissions: Json
                    pin_hash: string
                    store_id: string
                    updated_at: string
                    username: string
                }
                Insert: {
                    created_at?: string
                    id?: string
                    is_active?: boolean
                    name: string
                    permissions?: Json
                    pin_hash: string
                    store_id: string
                    updated_at?: string
                    username: string
                }
                Update: {
                    created_at?: string
                    id?: string
                    is_active?: boolean
                    name?: string
                    permissions?: Json
                    pin_hash?: string
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
            expenses: {
                Row: {
                    amount: number
                    category: string
                    created_at: string
                    created_by: string
                    date: string
                    description: string
                    id: string
                    store_id: string
                    updated_at: string
                }
                Insert: {
                    amount: number
                    category: string
                    created_at: string
                    created_by: string
                    date?: string
                    description: string
                    id?: string
                    store_id: string
                    updated_at?: string
                }
                Update: {
                    amount?: number
                    category?: string
                    created_at?: string
                    created_by?: string
                    date?: string
                    description?: string
                    id?: string
                    store_id?: string
                    updated_at?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "expenses_created_by_fkey"
                        columns: ["created_by"]
                        isOneToOne: false
                        referencedRelation: "employees"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "expenses_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            notification_queue: {
                Row: {
                    created_at: string | null
                    error_log: string | null
                    id: string
                    payload: Json
                    processed_at: string | null
                    recipient_email: string | null
                    status: string | null
                    type: string
                }
                Insert: {
                    created_at?: string | null
                    error_log?: string | null
                    id?: string
                    payload: Json
                    processed_at?: string | null
                    recipient_email?: string | null
                    status?: string | null
                    type: string
                }
                Update: {
                    created_at?: string | null
                    error_log?: string | null
                    id?: string
                    payload?: Json
                    processed_at?: string | null
                    recipient_email?: string | null
                    status?: string | null
                    type?: string
                }
                Relationships: []
            }
            product_prices: {
                Row: {
                    cost_price: number | null
                    created_at: string
                    effective_date: string
                    history: Json | null
                    id: string
                    product_id: string
                    sale_price: number
                    store_id: string
                }
                Insert: {
                    cost_price?: number | null
                    created_at?: string
                    effective_date?: string
                    history?: Json | null
                    id?: string
                    product_id: string
                    sale_price: number
                    store_id: string
                }
                Update: {
                    cost_price?: number | null
                    created_at?: string
                    effective_date?: string
                    history?: Json | null
                    id?: string
                    product_id?: string
                    sale_price?: number
                    store_id?: string
                }
                Relationships: [
                    {
                        foreignKeyName: "product_prices_product_id_fkey"
                        columns: ["product_id"]
                        isOneToOne: false
                        referencedRelation: "products"
                        referencedColumns: ["id"]
                    },
                    {
                        foreignKeyName: "product_prices_store_id_fkey"
                        columns: ["store_id"]
                        isOneToOne: false
                        referencedRelation: "stores"
                        referencedColumns: ["id"]
                    },
                ]
            }
            products: {
                Row: {
                    barcode: string | null
                    category_id: string | null
                    created_at: string
                    description: string | null
                    id: string
                    is_active: boolean
                    low_stock_threshold: number
                    name: string
                    sku: string | null
                    stock: number
                    store_id: string
                    unit_type: string
                    updated_at: string
                }
                Insert: {
                    barcode?: string | null
                    category_id?: string | null
                    created_at?: string
                    description?: string | null
                    id?: string
                    is_active?: boolean
                    low_stock_threshold?: number
                    name: string
                    sku?: string | null
                    stock?: number
                    store_id: string
                    unit_type?: string
                    updated_at?: string
                }
                Update: {
                    barcode?: string | null
                    category_id?: string | null
                    created_at?: string
                    description?: string | null
                    id?: string
                    is_active?: boolean
                    low_stock_threshold?: number
                    name?: string
                    sku?: string | null
                    stock?: number
                    store_id?: string
                    unit_type?: string
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
                    price_at_sale: number
                    product_id: string
                    quantity: number
                    sale_id: string
                    subtotal: number
                }
                Insert: {
                    created_at?: string
                    id?: string
                    price_at_sale: number
                    product_id: string
                    quantity: number
                    sale_id: string
                    subtotal: number
                }
                Update: {
                    created_at?: string
                    id?: string
                    price_at_sale?: number
                    product_id?: string
                    quantity?: number
                    sale_id?: string
                    subtotal?: number
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
                    client_id: string | null
                    created_at: string
                    created_by: string
                    id: string
                    notes: string | null
                    payment_method: string
                    status: string
                    store_id: string
                    total_amount: number
                }
                Insert: {
                    client_id?: string | null
                    created_at?: string
                    created_by: string
                    id?: string
                    notes?: string | null
                    payment_method: string
                    status?: string
                    store_id: string
                    total_amount: number
                }
                Update: {
                    client_id?: string | null
                    created_at?: string
                    created_by?: string
                    id?: string
                    notes?: string | null
                    payment_method?: string
                    status?: string
                    store_id?: string
                    total_amount?: number
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
                        foreignKeyName: "sales_created_by_fkey"
                        columns: ["created_by"]
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
                ]
            }
            stores: {
                Row: {
                    created_at: string
                    currency: string
                    email: string
                    id: string
                    is_active: boolean
                    logo_url: string | null
                    name: string
                    owner: string
                    phone: string | null
                    settings: Json | null
                    slug: string
                    subscription_plan: string
                    tax_rate: number
                    theme_config: Json | null
                    timezone: string
                    updated_at: string
                }
                Insert: {
                    created_at?: string
                    currency?: string
                    email: string
                    id?: string
                    is_active?: boolean
                    logo_url?: string | null
                    name: string
                    owner: string
                    phone?: string | null
                    settings?: Json | null
                    slug: string
                    subscription_plan?: string
                    tax_rate?: number
                    theme_config?: Json | null
                    timezone?: string
                    updated_at?: string
                }
                Update: {
                    created_at?: string
                    currency?: string
                    email?: string
                    id?: string
                    is_active?: boolean
                    logo_url?: string | null
                    name?: string
                    owner?: string
                    phone?: string | null
                    settings?: Json | null
                    slug?: string
                    subscription_plan?: string
                    tax_rate?: number
                    theme_config?: Json | null
                    timezone?: string
                    updated_at?: string
                }
                Relationships: []
            }
        }
        Views: {
            [_ in never]: never
        }
        Functions: {
            abrir_caja: {
                Args: {
                    p_employee_id: string
                    p_opening_balance: number
                }
                Returns: Json
            }
            actualizar_pin_empleado: {
                Args: {
                    p_employee_id: string
                    p_new_pin: string
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
                    p_actual_balance: number
                    p_employee_id: string
                }
                Returns: Json
            }
            check_daily_pass_status: {
                Args: {
                    p_employee_id: string
                    p_device_fingerprint: string
                }
                Returns: Json
            }
            crear_empleado: {
                Args: {
                    p_name: string
                    p_username: string
                    p_pin: string
                    p_permissions: Json
                }
                Returns: Json
            }
            expire_daily_passes: {
                Args: {
                    p_store_id: string
                    p_employee_id: string
                }
                Returns: void
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
                Args: {
                    p_product_id: string
                    p_old_price: number
                    p_new_price: number
                    p_store_id: string
                }
                Returns: undefined
            }
            log_security_event: {
                Args: {
                    p_event_type: string
                    p_severity: string
                    p_metadata: Json
                }
                Returns: boolean
            }
            solicitar_pase_diario: {
                Args: {
                    p_employee_id: string
                    p_device_fingerprint: string
                }
                Returns: Json
            }
            toggle_empleado_activo: {
                Args: {
                    p_employee_id: string
                }
                Returns: Json
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

export type Tables<
    PublicTableNameOrOptions extends
    | keyof (Database["public"]["Tables"] & Database["public"]["Views"])
    | { schema: keyof Database },
    TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof (Database[PublicTableNameOrOptions["schema"]]["Tables"] &
        Database[PublicTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
    ? (Database[PublicTableNameOrOptions["schema"]]["Tables"] &
        Database[PublicTableNameOrOptions["schema"]]["Views"])[TableName] extends {
            Row: infer R
        }
    ? R
    : never
    : PublicTableNameOrOptions extends keyof (Database["public"]["Tables"] &
        Database["public"]["Views"])
    ? (Database["public"]["Tables"] &
        Database["public"]["Views"])[PublicTableNameOrOptions] extends {
            Row: infer R
        }
    ? R
    : never
    : never

export type TablesInsert<
    PublicTableNameOrOptions extends
    | keyof Database["public"]["Tables"]
    | { schema: keyof Database },
    TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
    ? Database[PublicTableNameOrOptions["schema"]]["Tables"][TableName] extends {
        Insert: infer I
    }
    ? I
    : never
    : PublicTableNameOrOptions extends keyof Database["public"]["Tables"]
    ? Database["public"]["Tables"][PublicTableNameOrOptions] extends {
        Insert: infer I
    }
    ? I
    : never
    : never

export type TablesUpdate<
    PublicTableNameOrOptions extends
    | keyof Database["public"]["Tables"]
    | { schema: keyof Database },
    TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
    ? Database[PublicTableNameOrOptions["schema"]]["Tables"][TableName] extends {
        Update: infer U
    }
    ? U
    : never
    : PublicTableNameOrOptions extends keyof Database["public"]["Tables"]
    ? Database["public"]["Tables"][PublicTableNameOrOptions] extends {
        Update: infer U
    }
    ? U
    : never
    : never

export type Enums<
    DefaultSchemaEnumNameOrOptions extends
    | keyof Database["public"]["Enums"]
    | { schema: keyof Database },
    EnumName extends DefaultSchemaEnumNameOrOptions extends {
        schema: keyof Database
    }
    ? keyof Database[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof Database }
    ? Database[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
    : DefaultSchemaEnumNameOrOptions extends keyof Database["public"]["Enums"]
    ? Database["public"]["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
    PublicCompositeTypeNameOrOptions extends
    | keyof Database["public"]["CompositeTypes"]
    | { schema: keyof Database },
    CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
        schema: keyof Database
    }
    ? keyof Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends { schema: keyof Database }
    ? Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
    : PublicCompositeTypeNameOrOptions extends keyof Database["public"]["CompositeTypes"]
    ? Database["public"]["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
    public: {
        Enums: {},
    },
} as const
