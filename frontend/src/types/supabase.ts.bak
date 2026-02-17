export type Json =
    | string
    | number
    | boolean
    | null
    | { [key: string]: Json | undefined }
    | Json[]

export interface Database {
    public: {
        Tables: {
            products: {
                Row: {
                    id: string
                    name: string
                    plu: string | null
                    price: number
                    cost_price: number | null // Hidden for non-admins via RLS
                    current_stock: number
                    min_stock: number
                    measurement_unit: 'un' | 'kg' | 'lb' | 'g'
                    is_weighable: boolean
                    category: string | null
                    brand: string | null
                    store_id: string | null
                    created_at: string
                    updated_at: string
                }
                Insert: {
                    id?: string
                    name: string
                    plu?: string | null
                    price: number
                    cost_price?: number | null
                    current_stock?: number
                    min_stock?: number
                    measurement_unit?: 'un' | 'kg' | 'lb' | 'g'
                    is_weighable?: boolean
                    category?: string | null
                    brand?: string | null
                    store_id?: string | null
                    created_at?: string
                    updated_at?: string
                }
                Update: {
                    id?: string
                    name?: string
                    plu?: string | null
                    price?: number
                    cost_price?: number | null
                    current_stock?: number
                    min_stock?: number
                    measurement_unit?: 'un' | 'kg' | 'lb' | 'g'
                    is_weighable?: boolean
                    category?: string | null
                    brand?: string | null
                    store_id?: string | null
                    created_at?: string
                    updated_at?: string
                }
            }
            inventory_movements: {
                Row: {
                    id: string
                    product_id: string
                    movement_type: 'entrada' | 'salida' | 'ajuste' | 'venta'
                    quantity: number
                    reason: string | null
                    sale_id: string | null
                    created_by: string | null
                    created_at: string
                }
                Insert: {
                    id?: string
                    product_id: string
                    movement_type: 'entrada' | 'salida' | 'ajuste' | 'venta'
                    quantity: number
                    reason?: string | null
                    sale_id?: string | null
                    created_by?: string | null
                    created_at?: string
                }
                Update: {
                    id?: string
                    product_id?: string
                    movement_type?: 'entrada' | 'salida' | 'ajuste' | 'venta'
                    quantity?: number
                    reason?: string | null
                    sale_id?: string | null
                    created_by?: string | null
                    created_at?: string
                }
            }
            sales: {
                Row: {
                    id: string
                    total: number
                    payment_method: 'cash' | 'nequi' | 'fiado'
                    amount_received: number | null
                    change: number
                    client_id: string | null
                    employee_id: string | null
                    created_at: string
                }
                Insert: {
                    id?: string
                    total: number
                    payment_method: 'cash' | 'nequi' | 'fiado'
                    amount_received?: number | null
                    change?: number
                    client_id?: string | null
                    employee_id?: string | null
                    created_at?: string
                }
                Update: {
                    id?: string
                    total?: number
                    payment_method?: 'cash' | 'nequi' | 'fiado'
                    amount_received?: number | null
                    change?: number
                    client_id?: string | null
                    employee_id?: string | null
                    created_at?: string
                }
            }
            clients: {
                Row: {
                    id: string
                    name: string
                    cedula: string
                    phone: string | null
                    email: string | null
                    balance: number
                    credit_limit: number
                    notes: string | null
                    created_at: string
                    updated_at: string
                }
                Insert: {
                    id?: string
                    name: string
                    cedula: string
                    phone?: string | null
                    email?: string | null
                    balance?: number
                    credit_limit?: number
                    notes?: string | null
                    created_at?: string
                    updated_at?: string
                }
                Update: {
                    id?: string
                    name?: string
                    cedula?: string
                    phone?: string | null
                    email?: string | null
                    balance?: number
                    credit_limit?: number
                    notes?: string | null
                    created_at?: string
                    updated_at?: string
                }
            }
            employees: {
                Row: {
                    id: string
                    name: string
                    username: string
                    store_id: string
                    permissions: Json // EmployeePermissions
                    is_active: boolean
                    created_at: string
                    updated_at: string
                }
                Insert: {
                    id?: string
                    name: string
                    username: string
                    store_id: string
                    permissions: Json
                    is_active?: boolean
                    created_at?: string
                    updated_at?: string
                }
                Update: {
                    id?: string
                    name?: string
                    username?: string
                    store_id?: string
                    permissions?: Json
                    is_active?: boolean
                    created_at?: string
                    updated_at?: string
                }
            }
        }
        Functions: {
            login_empleado: {
                Args: {
                    p_username: string
                    p_pin: string
                }
                Returns: {
                    success: boolean
                    employee?: {
                        id: string
                        name: string
                        permissions: Json
                    }
                    error?: string
                }
            }
            procesar_venta: {
                Args: {
                    p_items: Json[]
                    p_payment_method: string
                    p_amount_received?: number
                    p_client_id?: string
                    p_employee_id: string
                }
                Returns: {
                    success: boolean
                    sale_id: string
                    total: number
                    change: number
                    error?: string
                }
            }
            get_cash_report: {
                Args: {
                    p_date?: string
                }
                Returns: Json
            }
        }
    }
}
