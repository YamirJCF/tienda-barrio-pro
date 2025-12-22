/**
 * Sample Data - Centralized sample/seed data for development
 * Products, categories, and other seed data
 */

import { Decimal } from 'decimal.js';
import type { MeasurementUnit } from '../stores/inventory';

export interface SampleProduct {
    name: string;
    brand: string;
    category: string;
    plu: string;
    price: Decimal;
    cost: Decimal;
    isWeighable: boolean;
    measurementUnit: MeasurementUnit;
    stock: Decimal;
    minStock: number;
}

export const SAMPLE_PRODUCTS: SampleProduct[] = [
    {
        name: 'Coca Cola 1.5L',
        brand: 'Coca Cola',
        category: 'Bebidas',
        plu: '101',
        price: new Decimal(4500),
        cost: new Decimal(3200),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(24),
        minStock: 6,
    },
    {
        name: 'Pan Bimbo Blanco',
        brand: 'Bimbo',
        category: 'Panadería',
        plu: '102',
        price: new Decimal(3800),
        cost: new Decimal(2800),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(15),
        minStock: 5,
    },
    {
        name: 'Huevos AA x12',
        brand: 'Santa Reyes',
        category: 'Lácteos y Huevos',
        plu: '103',
        price: new Decimal(600),
        cost: new Decimal(450),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(30),
        minStock: 12,
    },
    {
        name: 'Leche Entera 1L',
        brand: 'Alpina',
        category: 'Lácteos y Huevos',
        plu: '104',
        price: new Decimal(3200),
        cost: new Decimal(2400),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(18),
        minStock: 6,
    },
    {
        name: 'Arroz Diana 500g',
        brand: 'Diana',
        category: 'Despensa',
        plu: '105',
        price: new Decimal(2100),
        cost: new Decimal(1600),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(20),
        minStock: 8,
    },
    {
        name: 'Aceite Girasol 1L',
        brand: 'Gourmet',
        category: 'Despensa',
        plu: '106',
        price: new Decimal(8500),
        cost: new Decimal(6800),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(12),
        minStock: 4,
    },
    {
        name: 'Azúcar 1kg',
        brand: 'Manuelita',
        category: 'Despensa',
        plu: '107',
        price: new Decimal(3500),
        cost: new Decimal(2700),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(25),
        minStock: 10,
    },
    {
        name: 'Sal 500g',
        brand: 'Refisal',
        category: 'Despensa',
        plu: '108',
        price: new Decimal(1200),
        cost: new Decimal(900),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(40),
        minStock: 15,
    },
    // Productos por peso (nuevos)
    {
        name: 'Carne de Res',
        brand: 'Carnicería Local',
        category: 'Carnes',
        plu: '201',
        price: new Decimal(5000),  // Precio por libra
        cost: new Decimal(3500),
        isWeighable: true,
        measurementUnit: 'lb',
        stock: new Decimal(50),  // 50 libras en stock
        minStock: 10,
    },
    {
        name: 'Queso Costeño',
        brand: 'Lácteos del Campo',
        category: 'Lácteos y Huevos',
        plu: '202',
        price: new Decimal(8000),  // Precio por libra
        cost: new Decimal(6000),
        isWeighable: true,
        measurementUnit: 'lb',
        stock: new Decimal(25),  // 25 libras en stock
        minStock: 5,
    },
];

// Categories list
export const CATEGORIES = [
    'Bebidas',
    'Panadería',
    'Lácteos y Huevos',
    'Despensa',
    'Snacks',
    'Aseo del Hogar',
    'Licores',
    'Frutas y Verduras',
    'Carnes',
];

// Payment methods
export const PAYMENT_METHODS = [
    { id: 'cash', name: 'Efectivo', icon: 'payments' },
    { id: 'nequi', name: 'Nequi', icon: 'smartphone' },
    { id: 'fiado', name: 'Fiado', icon: 'person' },
];

// Measurement units display labels
export const UNIT_LABELS: Record<MeasurementUnit, string> = {
    'kg': 'Kilogramo',
    'lb': 'Libra',
    'g': 'Gramo',
    'un': 'Unidad',
};
