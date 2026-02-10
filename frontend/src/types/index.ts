import { Decimal } from 'decimal.js';
import type { Database } from './supabase';

export type MeasurementUnit = 'un' | 'kg' | 'lb' | 'g' | 'unidad';

// WO-001: UUID Refactoring - All IDs changed from number to string
// Maps to: Database['public']['Tables']['products']['Row']
export interface Product {
    id: string; // UUID
    name: string;
    price: Decimal;
    stock: Decimal;
    measurementUnit: MeasurementUnit;
    category?: string;
    brand?: string;
    minStock: number;
    cost?: Decimal;
    plu?: string;
    isWeighable?: boolean;
    createdAt?: string;
    updatedAt?: string;
    notifiedLowStock?: boolean;
    storeId: string; // REQUIRED - RLS compliance (was optional, caused 401 errors)
    supplierId?: string; // Smart Supply (FRD-008 Fase 2)
}

export interface CartItem {
    id: string; // UUID - references Product.id
    name: string;
    price: Decimal;
    quantity: number | Decimal;
    measurementUnit: MeasurementUnit;
    isWeighable?: boolean;
    subtotal?: Decimal;
    // Optional metadata from product if needed
    plu?: string;
    brand?: string;
    category?: string;
}

export interface SaleItem {
    productId: string; // UUID - references Product.id
    productName: string;
    quantity: number;
    price: Decimal;
    subtotal: Decimal;
}

// Maps to: Database['public']['Tables']['sales']['Row']
export interface Sale {
    id: string; // UUID
    ticketNumber: number; // Sequential number for UI display (SPEC-012)
    date: string; // YYYY-MM-DD
    timestamp: string; // ISO Full
    items: SaleItem[];
    total: Decimal;
    paymentMethod: 'cash' | 'nequi' | 'fiado' | 'mixed';
    payments?: PaymentTransaction[]; // WO-PHASE3-001: For mixed payments
    roundingDifference?: Decimal;
    effectiveTotal: Decimal;
    amountReceived?: Decimal;
    change?: Decimal;
    clientId?: string; // UUID - references Client.id
    employeeId?: string; // UUID - references Employee.id
    syncStatus?: 'synced' | 'pending' | 'failed'; // SPEC-012: Sync Protocol
}

// WO-PHASE3-001: Mixed Payments Transaction
export interface PaymentTransaction {
    method: 'cash' | 'nequi' | 'fiado';
    amount: Decimal;
    reference?: string; // For Nequi/Transfer
}

// Maps to: Database['public']['Tables']['clients']['Row']
export interface Client {
    id: string; // UUID
    name: string;
    cc: string;
    phone?: string;
    email?: string;
    totalDebt: Decimal;
    notes?: string;
    creditLimit?: Decimal;
    createdAt?: string;
    updatedAt?: string;
    storeId: string; // REQUIRED - RLS compliance (Fase 1 Blindaje)
}

// Maps to: Database['public']['Tables']['client_transactions']['Row']
export interface ClientTransaction {
    id: string; // UUID
    clientId: string; // UUID - references Client.id
    type: 'purchase' | 'payment';
    amount: Decimal | number;
    description: string;
    date: string;
    saleId?: string; // UUID - references Sale.id
}

// WO-001: New interface for employees (consolidating from auth.ts)
// Maps to: Database['public']['Tables']['employees']['Row']
export interface Employee {
    id: string; // UUID
    name: string;
    username: string;
    pin: string; // Added for persistence/creation
    storeId: string; // UUID - references Store.id
    permissions: EmployeePermissions;
    isActive: boolean;
    createdAt: string;
    updatedAt: string;
}

export interface EmployeePermissions {
    canSell: boolean;
    canViewInventory: boolean;
    canViewReports: boolean;
    canFiar: boolean;
    canOpenCloseCash: boolean;
    canManageInventory?: boolean;
    canManageClients?: boolean;
}

// WO-001: Helper type for generating UUIDs
export type UUID = string;

// WO-004: Cash Register Types
export interface CashTransaction {
    id: string;
    type: 'income' | 'expense';
    amount: Decimal;
    description: string;
    timestamp: string;
    category?: string;
    relatedSaleId?: string; // Optional link to a sale
}

// Maps to: Database['public']['Tables']['cash_register']['Row'] (partially)
export interface CashSession {
    id: string;
    storeId: string; // Required for RLS - Tienda asociada
    employeeId: string; // ID of employee who opened the register
    status: 'open' | 'closed';
    openingTime: string;
    closingTime?: string;
    openingBalance: Decimal;
    closingBalance?: Decimal; // Physical count at closing
    calculatedBalance?: Decimal; // System calculated balance at closing
    discrepancy?: Decimal; // Difference
    transactions: CashTransaction[];
    notes?: string;
}

