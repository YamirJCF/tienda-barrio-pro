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
    PostgrestVersion: "13.0.5"
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
      audit_caja: {
        Row: {
          actor_id: string | null
          created_at: string
          event_type: string
          id: string
          metadata: Json | null
          session_id: string | null
          store_id: string
        }
        Insert: {
          actor_id?: string | null
          created_at?: string
          event_type: string
          id?: string
          metadata?: Json | null
          session_id?: string | null
          store_id: string
        }
        Update: {
          actor_id?: string | null
          created_at?: string
          event_type?: string
          id?: string
          metadata?: Json | null
          session_id?: string | null
          store_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_caja_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_caja_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "cash_sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_caja_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          actor_id: string
          created_at: string | null
          event_type: string
          id: string
          ip_address: string | null
          metadata: Json | null
          resource_id: string | null
          review_notes: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          severity: string | null
          store_id: string | null
        }
        Insert: {
          actor_id: string
          created_at?: string | null
          event_type: string
          id?: string
          ip_address?: string | null
          metadata?: Json | null
          resource_id?: string | null
          review_notes?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          severity?: string | null
          store_id?: string | null
        }
        Update: {
          actor_id?: string
          created_at?: string | null
          event_type?: string
          id?: string
          ip_address?: string | null
          metadata?: Json | null
          resource_id?: string | null
          review_notes?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          severity?: string | null
          store_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_logs_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_precios: {
        Row: {
          changed_by: string | null
          created_at: string
          id: string
          new_cost: number | null
          new_price: number | null
          old_cost: number | null
          old_price: number | null
          product_id: string | null
          store_id: string
        }
        Insert: {
          changed_by?: string | null
          created_at?: string
          id?: string
          new_cost?: number | null
          new_price?: number | null
          old_cost?: number | null
          old_price?: number | null
          product_id?: string | null
          store_id: string
        }
        Update: {
          changed_by?: string | null
          created_at?: string
          id?: string
          new_cost?: number | null
          new_price?: number | null
          old_cost?: number | null
          old_price?: number | null
          product_id?: string | null
          store_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_precios_changed_by_fkey"
            columns: ["changed_by"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_precios_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_precios_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_seguridad: {
        Row: {
          actor_id: string | null
          created_at: string
          event_type: string
          id: string
          ip_address: string | null
          metadata: Json | null
          store_id: string | null
          user_agent: string | null
        }
        Insert: {
          actor_id?: string | null
          created_at?: string
          event_type: string
          id?: string
          ip_address?: string | null
          metadata?: Json | null
          store_id?: string | null
          user_agent?: string | null
        }
        Update: {
          actor_id?: string | null
          created_at?: string
          event_type?: string
          id?: string
          ip_address?: string | null
          metadata?: Json | null
          store_id?: string | null
          user_agent?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_seguridad_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_seguridad_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_ventas: {
        Row: {
          actor_id: string | null
          created_at: string
          event_type: string
          id: string
          metadata: Json | null
          sale_id: string | null
          store_id: string
        }
        Insert: {
          actor_id?: string | null
          created_at?: string
          event_type: string
          id?: string
          metadata?: Json | null
          sale_id?: string | null
          store_id: string
        }
        Update: {
          actor_id?: string | null
          created_at?: string
          event_type?: string
          id?: string
          metadata?: Json | null
          sale_id?: string | null
          store_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_ventas_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_ventas_sale_id_fkey"
            columns: ["sale_id"]
            isOneToOne: false
            referencedRelation: "sales"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_ventas_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      cash_movements: {
        Row: {
          actor_id: string | null
          amount: number
          category: string | null
          created_at: string
          description: string
          id: string
          movement_type: string
          payment_method: string
          sale_id: string | null
          session_id: string
          voucher_ref: string | null
        }
        Insert: {
          actor_id?: string | null
          amount: number
          category?: string | null
          created_at?: string
          description: string
          id?: string
          movement_type: string
          payment_method?: string
          sale_id?: string | null
          session_id: string
          voucher_ref?: string | null
        }
        Update: {
          actor_id?: string | null
          amount?: number
          category?: string | null
          created_at?: string
          description?: string
          id?: string
          movement_type?: string
          payment_method?: string
          sale_id?: string | null
          session_id?: string
          voucher_ref?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cash_movements_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
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
          forced_close: boolean
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
          forced_close?: boolean
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
          forced_close?: boolean
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
      client_ledger: {
        Row: {
          amount: number
          client_id: string
          created_at: string | null
          created_by: string | null
          id: string
          new_balance: number
          previous_balance: number
          reference_id: string | null
          store_id: string
          transaction_type: string
        }
        Insert: {
          amount: number
          client_id: string
          created_at?: string | null
          created_by?: string | null
          id?: string
          new_balance?: number
          previous_balance?: number
          reference_id?: string | null
          store_id: string
          transaction_type: string
        }
        Update: {
          amount?: number
          client_id?: string
          created_at?: string | null
          created_by?: string | null
          id?: string
          new_balance?: number
          previous_balance?: number
          reference_id?: string | null
          store_id?: string
          transaction_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "client_ledger_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "client_ledger_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "client_ledger_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
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
          approved_at: string | null
          approved_by: string | null
          auth_user_id: string | null
          device_fingerprint: string | null
          employee_id: string
          id: string
          pass_date: string
          requested_at: string
          resolved_at: string | null
          resolved_by: string | null
          retry_count: number | null
          status: string
          store_id: string | null
          updated_at: string | null
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          auth_user_id?: string | null
          device_fingerprint?: string | null
          employee_id: string
          id?: string
          pass_date?: string
          requested_at?: string
          resolved_at?: string | null
          resolved_by?: string | null
          retry_count?: number | null
          status?: string
          store_id?: string | null
          updated_at?: string | null
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          auth_user_id?: string | null
          device_fingerprint?: string | null
          employee_id?: string
          id?: string
          pass_date?: string
          requested_at?: string
          resolved_at?: string | null
          resolved_by?: string | null
          retry_count?: number | null
          status?: string
          store_id?: string | null
          updated_at?: string | null
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
            foreignKeyName: "daily_passes_store_id_fkey"
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
          id: string
          is_active: boolean | null
          name: string
          permissions: Json | null
          pin_hash: string
          store_id: string
          updated_at: string
          username: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean | null
          name: string
          permissions?: Json | null
          pin_hash: string
          store_id: string
          updated_at?: string
          username: string
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean | null
          name?: string
          permissions?: Json | null
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
      inventory_batches: {
        Row: {
          cost_unit: number
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean | null
          product_id: string
          quantity_initial: number
          quantity_remaining: number
          sale_price: number
          source_movement_id: string | null
        }
        Insert: {
          cost_unit: number
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean | null
          product_id: string
          quantity_initial: number
          quantity_remaining: number
          sale_price: number
          source_movement_id?: string | null
        }
        Update: {
          cost_unit?: number
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean | null
          product_id?: string
          quantity_initial?: number
          quantity_remaining?: number
          sale_price?: number
          source_movement_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inventory_batches_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_batches_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_batches_source_movement_id_fkey"
            columns: ["source_movement_id"]
            isOneToOne: false
            referencedRelation: "inventory_movements"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_movement_batches: {
        Row: {
          batch_id: string
          id: string
          movement_id: string
          quantity_consumed: number
          unit_cost: number
        }
        Insert: {
          batch_id: string
          id?: string
          movement_id: string
          quantity_consumed: number
          unit_cost: number
        }
        Update: {
          batch_id?: string
          id?: string
          movement_id?: string
          quantity_consumed?: number
          unit_cost?: number
        }
        Relationships: [
          {
            foreignKeyName: "inventory_movement_batches_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "inventory_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movement_batches_movement_id_fkey"
            columns: ["movement_id"]
            isOneToOne: false
            referencedRelation: "inventory_movements"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_movements: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          invoice_reference: string | null
          movement_type: string
          payment_type: string | null
          product_id: string
          quantity: number
          reason: string | null
          reference_invoice_id: string | null
          supplier_id: string | null
          unit_cost: number | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          invoice_reference?: string | null
          movement_type: string
          payment_type?: string | null
          product_id: string
          quantity: number
          reason?: string | null
          reference_invoice_id?: string | null
          supplier_id?: string | null
          unit_cost?: number | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          invoice_reference?: string | null
          movement_type?: string
          payment_type?: string | null
          product_id?: string
          quantity?: number
          reason?: string | null
          reference_invoice_id?: string | null
          supplier_id?: string | null
          unit_cost?: number | null
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
          {
            foreignKeyName: "inventory_movements_reference_invoice_id_fkey"
            columns: ["reference_invoice_id"]
            isOneToOne: false
            referencedRelation: "supplier_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          audience: string
          created_at: string
          id: string
          is_read: boolean | null
          message: string
          metadata: Json | null
          store_id: string
          title: string
          type: string
        }
        Insert: {
          audience: string
          created_at?: string
          id?: string
          is_read?: boolean | null
          message: string
          metadata?: Json | null
          store_id: string
          title: string
          type: string
        }
        Update: {
          audience?: string
          created_at?: string
          id?: string
          is_read?: boolean | null
          message?: string
          metadata?: Json | null
          store_id?: string
          title?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_methods: {
        Row: {
          allows_change: boolean | null
          code: string
          created_at: string | null
          id: string
          is_active: boolean | null
          name: string
          requires_reference: boolean | null
          sort_order: number | null
        }
        Insert: {
          allows_change?: boolean | null
          code: string
          created_at?: string | null
          id?: string
          is_active?: boolean | null
          name: string
          requires_reference?: boolean | null
          sort_order?: number | null
        }
        Update: {
          allows_change?: boolean | null
          code?: string
          created_at?: string | null
          id?: string
          is_active?: boolean | null
          name?: string
          requires_reference?: boolean | null
          sort_order?: number | null
        }
        Relationships: []
      }
      product_price_history: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          product_id: string
          purchase_price: number
          sale_price: number
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          product_id: string
          purchase_price: number
          sale_price: number
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          product_id?: string
          purchase_price?: number
          sale_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "product_price_history_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          brand: string | null
          category: string | null
          cost_price: number | null
          created_at: string
          current_stock: number | null
          id: string
          is_active: boolean
          is_weighable: boolean | null
          low_stock_alerted: boolean | null
          measurement_unit: string | null
          min_stock: number | null
          name: string
          plu: string | null
          price: number
          store_id: string
          supplier_id: string | null
          updated_at: string
        }
        Insert: {
          brand?: string | null
          category?: string | null
          cost_price?: number | null
          created_at?: string
          current_stock?: number | null
          id?: string
          is_active?: boolean
          is_weighable?: boolean | null
          low_stock_alerted?: boolean | null
          measurement_unit?: string | null
          min_stock?: number | null
          name: string
          plu?: string | null
          price: number
          store_id: string
          supplier_id?: string | null
          updated_at?: string
        }
        Update: {
          brand?: string | null
          category?: string | null
          cost_price?: number | null
          created_at?: string
          current_stock?: number | null
          id?: string
          is_active?: boolean
          is_weighable?: boolean | null
          low_stock_alerted?: boolean | null
          measurement_unit?: string | null
          min_stock?: number | null
          name?: string
          plu?: string | null
          price?: number
          store_id?: string
          supplier_id?: string | null
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
          {
            foreignKeyName: "products_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      sale_item_batches: {
        Row: {
          batch_id: string
          created_at: string
          id: string
          quantity_consumed: number
          sale_item_id: string
          unit_cost: number
          unit_price: number
        }
        Insert: {
          batch_id: string
          created_at?: string
          id?: string
          quantity_consumed: number
          sale_item_id: string
          unit_cost: number
          unit_price: number
        }
        Update: {
          batch_id?: string
          created_at?: string
          id?: string
          quantity_consumed?: number
          sale_item_id?: string
          unit_cost?: number
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "sale_item_batches_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "inventory_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sale_item_batches_sale_item_id_fkey"
            columns: ["sale_item_id"]
            isOneToOne: false
            referencedRelation: "sale_items"
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
          unit_cost: number | null
          unit_price: number
        }
        Insert: {
          created_at?: string
          id?: string
          product_id: string
          quantity: number
          sale_id: string
          subtotal: number
          unit_cost?: number | null
          unit_price: number
        }
        Update: {
          created_at?: string
          id?: string
          product_id?: string
          quantity?: number
          sale_id?: string
          subtotal?: number
          unit_cost?: number | null
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
          idempotency_key: string | null
          is_voided: boolean | null
          local_id: string | null
          payment_method: string
          rounding_difference: number | null
          store_id: string
          sync_status: string | null
          ticket_number: number
          total: number
          void_reason: string | null
          void_session_id: string | null
          voided_at: string | null
          voided_by: string | null
        }
        Insert: {
          amount_received?: number | null
          change_given?: number | null
          client_id?: string | null
          created_at?: string
          employee_id: string
          id?: string
          idempotency_key?: string | null
          is_voided?: boolean | null
          local_id?: string | null
          payment_method: string
          rounding_difference?: number | null
          store_id: string
          sync_status?: string | null
          ticket_number: number
          total: number
          void_reason?: string | null
          void_session_id?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Update: {
          amount_received?: number | null
          change_given?: number | null
          client_id?: string | null
          created_at?: string
          employee_id?: string
          id?: string
          idempotency_key?: string | null
          is_voided?: boolean | null
          local_id?: string | null
          payment_method?: string
          rounding_difference?: number | null
          store_id?: string
          sync_status?: string | null
          ticket_number?: number
          total?: number
          void_reason?: string | null
          void_session_id?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Relationships: [
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
            foreignKeyName: "sales_void_session_id_fkey"
            columns: ["void_session_id"]
            isOneToOne: false
            referencedRelation: "cash_sessions"
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
          created_at: string
          crypto_salt: string | null
          id: string
          name: string
          pin_hash: string | null
          slug: string
          store_pin_hash: string | null
          subscription_plan: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          crypto_salt?: string | null
          id?: string
          name: string
          pin_hash?: string | null
          slug: string
          store_pin_hash?: string | null
          subscription_plan?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          crypto_salt?: string | null
          id?: string
          name?: string
          pin_hash?: string | null
          slug?: string
          store_pin_hash?: string | null
          subscription_plan?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      supplier_invoices: {
        Row: {
          amount_paid: number
          created_at: string
          due_date: string
          id: string
          invoice_number: string | null
          store_id: string
          supplier_id: string
          total_amount: number
        }
        Insert: {
          amount_paid?: number
          created_at?: string
          due_date: string
          id?: string
          invoice_number?: string | null
          store_id: string
          supplier_id: string
          total_amount: number
        }
        Update: {
          amount_paid?: number
          created_at?: string
          due_date?: string
          id?: string
          invoice_number?: string | null
          store_id?: string
          supplier_id?: string
          total_amount?: number
        }
        Relationships: [
          {
            foreignKeyName: "supplier_invoices_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      suppliers: {
        Row: {
          created_at: string | null
          delivery_day: number | null
          frequency_days: number
          id: string
          is_default: boolean
          lead_time_days: number
          name: string
          store_id: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          delivery_day?: number | null
          frequency_days?: number
          id?: string
          is_default?: boolean
          lead_time_days?: number
          name: string
          store_id: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          delivery_day?: number | null
          frequency_days?: number
          id?: string
          is_default?: boolean
          lead_time_days?: number
          name?: string
          store_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "suppliers_store_id_fkey"
            columns: ["store_id"]
            isOneToOne: false
            referencedRelation: "stores"
            referencedColumns: ["id"]
          },
        ]
      }
      transaction_types: {
        Row: {
          code: string
          description: string
          id: string
          impact_cash: number | null
          impact_stock: number | null
          is_system: boolean | null
        }
        Insert: {
          code: string
          description: string
          id?: string
          impact_cash?: number | null
          impact_stock?: number | null
          is_system?: boolean | null
        }
        Update: {
          code?: string
          description?: string
          id?: string
          impact_cash?: number | null
          impact_stock?: number | null
          is_system?: boolean | null
        }
        Relationships: []
      }
    }
    Views: {
      client_transactions: {
        Row: {
          amount: number | null
          client_id: string | null
          created_at: string | null
          description: string | null
          id: string | null
          sale_id: string | null
          transaction_type: string | null
        }
        Relationships: [
          {
            foreignKeyName: "client_ledger_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      abrir_caja: {
        Args: {
          p_employee_id: string
          p_opening_balance: number
          p_store_id: string
        }
        Returns: Json
      }
      actualizar_pin_empleado: {
        Args: { p_employee_id: string; p_new_pin: string }
        Returns: Json
      }
      aprobar_pase_diario: {
        Args: { p_admin_id?: string; p_pass_id: string }
        Returns: Json
      }
      assert_store_access: { Args: { p_store_id: string }; Returns: undefined }
      buscar_producto_pos: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_store_id: string
          p_term: string
        }
        Returns: Json
      }
      cerrar_caja: {
        Args: {
          p_actual_balance: number
          p_employee_id: string
          p_session_id: string
        }
        Returns: Json
      }
      check_daily_pass_status: {
        Args: { p_device_fingerprint?: string; p_employee_id: string }
        Returns: Json
      }
      check_my_pass_status: { Args: { p_pass_id: string }; Returns: Json }
      consume_stock_fifo: {
        Args: { p_product_id: string; p_quantity_needed: number }
        Returns: {
          batch_id: string
          cost_unit: number
          quantity_taken: number
          sale_price: number
        }[]
      }
      crear_empleado: {
        Args: {
          p_name: string
          p_permissions?: Json
          p_pin: string
          p_store_id: string
          p_username: string
        }
        Returns: Json
      }
      get_active_cash_session: { Args: { p_store_id: string }; Returns: Json }
      get_client_ledger_summary: { Args: { p_store_id: string }; Returns: Json }
      get_current_store_id: { Args: never; Returns: string }
      get_daily_summary: {
        Args: { p_date?: string; p_store_id: string }
        Returns: Json
      }
      get_employee_id_from_session: { Args: never; Returns: string }
      get_employee_public_info: { Args: { p_username: string }; Returns: Json }
      get_financial_summary: {
        Args: {
          p_employee_id?: string
          p_end_date?: string
          p_start_date?: string
          p_store_id: string
        }
        Returns: Json
      }
      get_history_caja: {
        Args: { p_end_date: string; p_start_date: string; p_store_id: string }
        Returns: Json
      }
      get_history_compras: {
        Args: { p_end_date: string; p_start_date: string; p_store_id: string }
        Returns: Json
      }
      get_history_creditos: {
        Args: { p_end_date?: string; p_start_date?: string; p_store_id: string }
        Returns: {
          amount: number
          client_name: string
          created_at: string
          description: string
          employee_name: string
          id: string
          new_balance: number
          previous_balance: number
          transaction_type: string
        }[]
      }
      get_history_ventas: {
        Args: {
          p_employee_id?: string
          p_end_date: string
          p_start_date: string
          p_store_id: string
        }
        Returns: Json
      }
      get_inventory_health: { Args: { p_store_id: string }; Returns: Json }
      get_sale_detail: { Args: { p_sale_id: string }; Returns: Json }
      get_smart_supply_report: {
        Args: { p_store_id: string }
        Returns: {
          current_stock: number
          doi: number
          product_id: string
          product_name: string
          revenue_at_risk: number
          status: string
          suggestion: string
          velocity: number
        }[]
      }
      get_stagnant_products: {
        Args: { p_days_threshold?: number; p_store_id: string }
        Returns: {
          days_stagnant: number
          last_sale_date: string
          product_id: string
          product_name: string
          stock_value: number
        }[]
      }
      get_top_products_by_units: {
        Args: {
          p_end_date?: string
          p_limit?: number
          p_start_date?: string
          p_store_id: string
        }
        Returns: {
          dias_rotacion: number
          product_id: string
          product_name: string
          stock_actual: number
          units_sold: number
        }[]
      }
      get_top_selling_products: {
        Args: {
          p_end_date?: string
          p_limit?: number
          p_start_date?: string
          p_store_id: string
        }
        Returns: {
          product_id: string
          product_name: string
          profit: number
          revenue: number
          stock_remaining: number
          stock_status: string
          units_sold: number
        }[]
      }
      is_authorized_employee: { Args: never; Returns: boolean }
      procesar_venta: {
        Args: {
          p_amount_received?: number
          p_client_id?: string
          p_employee_id: string
          p_items: Json
          p_local_id?: string
          p_payment_method: string
          p_store_id: string
          p_total: number
        }
        Returns: Json
      }
      registrar_abono: {
        Args: { p_amount: number; p_client_id: string }
        Returns: Json
      }
      request_employee_access: {
        Args: {
          p_device_fingerprint: string
          p_pin: string
          p_username: string
        }
        Returns: Json
      }
      rpc_actualizar_precio_lote:
        | {
            Args: {
              p_batch_id: string
              p_cost_unit: number
              p_sale_price: number
            }
            Returns: Json
          }
        | {
            Args: { p_batch_id: string; p_new_sale_price: number }
            Returns: Json
          }
      rpc_actualizar_producto_catalogo: {
        Args: {
          p_category?: string
          p_cost?: number
          p_expected_name: string
          p_expected_old_cost?: number
          p_expected_old_price: number
          p_min_stock?: number
          p_name: string
          p_plu?: string
          p_price: number
          p_product_id: string
        }
        Returns: Json
      }
      rpc_admin_get_clients: {
        Args: {
          p_filter_debt?: string
          p_include_deleted?: boolean
          p_limit?: number
          p_offset?: number
          p_order_by?: string
          p_search_query?: string
          p_store_id: string
        }
        Returns: Json
      }
      rpc_anular_venta: {
        Args: { p_reason: string; p_sale_id: string }
        Returns: Json
      }
      rpc_asignar_proveedor_masivo: {
        Args: {
          p_product_ids: string[]
          p_store_id: string
          p_supplier_id: string
        }
        Returns: Json
      }
      rpc_bulk_assign_supplier: {
        Args: {
          p_product_ids: string[]
          p_store_id: string
          p_supplier_id: string
        }
        Returns: Json
      }
      rpc_check_and_force_close_shifts: { Args: never; Returns: Json }
      rpc_force_sale: {
        Args: {
          p_amount_received?: number
          p_client_id: string
          p_items: Json
          p_justification: string
          p_payment_method: string
          p_store_id: string
        }
        Returns: Json
      }
      rpc_gestionar_dispositivo: {
        Args: { p_action: string; p_pass_id: string }
        Returns: Json
      }
      rpc_get_comprehensive_financial_report: {
        Args: {
          p_employee_id?: string
          p_end_date?: string
          p_start_date?: string
          p_store_id: string
        }
        Returns: Json
      }
      rpc_get_system_config: { Args: never; Returns: Json }
      rpc_log_security_event: {
        Args: { p_event_type: string; p_metadata?: Json; p_store_id?: string }
        Returns: undefined
      }
      rpc_marcar_auditoria_revisada: {
        Args: { p_audit_id: string; p_notes?: string }
        Returns: Json
      }
      rpc_obtener_empleados: {
        Args: {
          p_search?: string
          p_status_filter?: string
          p_store_id: string
        }
        Returns: {
          created_at: string
          id: string
          is_active: boolean
          name: string
          permissions: Json
          pin: string
          store_id: string
          updated_at: string
          username: string
        }[]
      }
      rpc_pay_supplier_invoice: {
        Args: {
          p_amount: number
          p_invoice_id: string
          p_payment_method: string
        }
        Returns: undefined
      }
      rpc_procesar_venta_v2: {
        Args: {
          p_amount_received: number
          p_client_id: string
          p_items: Json
          p_payment_method: string
          p_store_id: string
        }
        Returns: Json
      }
      rpc_procesar_venta_v3: {
        Args: {
          p_amount_received: number
          p_client_id: string
          p_idempotency_key?: string
          p_is_offline_sync?: boolean
          p_items: Json
          p_local_id?: string
          p_origin_session_id?: string
          p_payment_method: string
          p_sold_by?: string
          p_store_id: string
        }
        Returns: Json
      }
      rpc_reconciliar_cierre_forzado: {
        Args: {
          p_actual_balance: number
          p_employee_id: string
          p_session_id: string
        }
        Returns: Json
      }
      rpc_registrar_abono: {
        Args: {
          p_amount: number
          p_client_id: string
          p_notes?: string
          p_payment_method: string
        }
        Returns: Json
      }
      rpc_registrar_entrada:
        | {
            Args: {
              p_product_id: string
              p_purchase_price: number
              p_quantity: number
              p_reason?: string
              p_sale_price: number
            }
            Returns: Json
          }
        | {
            Args: {
              p_invoice_reference?: string
              p_payment_type?: string
              p_product_id: string
              p_purchase_price: number
              p_quantity: number
              p_reason?: string
              p_reference_invoice_id?: string
              p_sale_price: number
              p_supplier_id?: string
            }
            Returns: Json
          }
      rpc_registrar_entrada_masiva: {
        Args: { p_entries: Json; p_store_id: string }
        Returns: Json
      }
      rpc_registrar_gasto_v2: {
        Args: {
          p_amount: number
          p_category: string
          p_description: string
          p_payment_method: string
          p_session_id: string
          p_voucher_ref?: string
        }
        Returns: Json
      }
      rpc_registrar_movimiento_inventario: {
        Args: {
          p_invoice_reference?: string
          p_movement_type: string
          p_payment_type?: string
          p_product_id: string
          p_quantity: number
          p_reason?: string
          p_supplier_id?: string
        }
        Returns: Json
      }
      rpc_soft_delete_product: { Args: { p_product_id: string }; Returns: Json }
      rpc_verificar_estado_sesion: { Args: never; Returns: Json }
      rpc_verify_store_pin: {
        Args: { p_pin: string; p_store_id: string }
        Returns: boolean
      }
      slugify: { Args: { "": string }; Returns: string }
      solicitar_pase_diario: {
        Args: { p_device_fingerprint?: string; p_employee_id: string }
        Returns: Json
      }
      toggle_empleado_activo: {
        Args: { p_employee_id: string; p_new_status: boolean }
        Returns: Json
      }
      toggle_employee_status: {
        Args: { p_employee_id: string; p_new_status: boolean }
        Returns: Json
      }
      validar_pin_empleado: {
        Args: { p_pin: string; p_username: string }
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

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
