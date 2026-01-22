-- =============================================
-- 00_seed_data.sql
-- Objetivo: Poblar la DB con datos de prueba (WO-6)
-- Dependencias: supabase-schema.sql ya ejecutado
-- =============================================

-- Deshabilitar triggers para carga masiva rápida (opcional, pero seguro en test)
SET session_replication_role = 'replica';

-- 1. Limpiar datos previos (Orden por dependencias FK)
TRUNCATE TABLE sale_items CASCADE;
TRUNCATE TABLE sales CASCADE;
TRUNCATE TABLE inventory_movements CASCADE;
TRUNCATE TABLE client_transactions CASCADE;
TRUNCATE TABLE clients CASCADE;
TRUNCATE TABLE products CASCADE;
TRUNCATE TABLE employees CASCADE;
TRUNCATE TABLE stores CASCADE;

-- Reactivar triggers para asegurar lógica de negocio al insertar
SET session_replication_role = 'origin';

-- 2. Crear Tienda Demo
INSERT INTO stores (id, name, address, owner_name, owner_pin_hash, created_at)
VALUES 
(
    '11111111-1111-1111-1111-111111111111', 
    'Tienda Demo Pro', 
    'Calle Falsa 123, Bogotá', 
    'Juan Dueño',
    crypt('000000', gen_salt('bf')), -- PIN Admin: 000000
    NOW()
);

-- 3. Crear Empleados
-- Admin (Dueño operando caja)
INSERT INTO employees (id, store_id, name, username, pin, permissions, is_active)
VALUES
(
    '22222222-2222-2222-2222-222222222201',
    '11111111-1111-1111-1111-111111111111',
    'Administrador',
    'admin',
    crypt('0000', gen_salt('bf')), -- PIN: 0000
    '{"canSell": true, "canViewInventory": true, "canViewReports": true, "canFiar": true, "canOpenCloseCash": true}',
    true
);

-- Empleado 1: Vendedor
INSERT INTO employees (id, store_id, name, username, pin, permissions, is_active)
VALUES
(
    '22222222-2222-2222-2222-222222222202',
    '11111111-1111-1111-1111-111111111111',
    'Ana Vendedora',
    'ana',
    crypt('1234', gen_salt('bf')), -- PIN: 1234
    '{"canSell": true, "canViewInventory": true, "canViewReports": false, "canFiar": false, "canOpenCloseCash": false}',
    true
);

-- Empleado 2: Bodeguero
INSERT INTO employees (id, store_id, name, username, pin, permissions, is_active)
VALUES
(
    '22222222-2222-2222-2222-222222222203',
    '11111111-1111-1111-1111-111111111111',
    'Pedro Bodega',
    'pedro',
    crypt('5678', gen_salt('bf')), -- PIN: 5678
    '{"canSell": false, "canViewInventory": true, "canViewReports": false, "canFiar": false, "canOpenCloseCash": false}',
    true
);

-- 4. Crear Productos (50 items variados)
-- Función auxiliar para generar productos
DO $$
DECLARE
    v_store_id UUID := '11111111-1111-1111-1111-111111111111';
    v_i INTEGER;
    v_category TEXT;
    v_is_weighable BOOLEAN;
    v_unit TEXT;
    v_price DECIMAL;
BEGIN
    FOR v_i IN 1..50 LOOP
        -- Lógica aleatoria simple para variedad
        IF v_i <= 10 THEN
            v_category := 'Bebidas';
            v_is_weighable := false;
            v_unit := 'un';
            v_price := (floor(random() * 5 + 1) * 1000); -- 1000, 2000, ...
        ELSIF v_i <= 20 THEN
            v_category := 'Frutas y Verduras';
            v_is_weighable := true;
            v_unit := 'kg';
            v_price := (floor(random() * 10 + 1) * 500); -- Precios por kg
        ELSIF v_i <= 30 THEN
            v_category := 'Abarrotes';
            v_is_weighable := false;
            v_unit := 'un';
            v_price := (floor(random() * 20 + 1) * 200);
        ELSIF v_i <= 40 THEN
            v_category := 'Lácteos';
            v_is_weighable := false;
            v_unit := 'un';
            v_price := (floor(random() * 8 + 2) * 500);
        ELSE
            v_category := 'Aseo';
            v_is_weighable := false;
            v_unit := 'un';
            v_price := (floor(random() * 15 + 5) * 500);
        END IF;

        INSERT INTO products (store_id, name, plu, price, cost_price, category, current_stock, min_stock, is_weighable, measurement_unit)
        VALUES (
            v_store_id,
            'Producto ' || v_category || ' ' || v_i,
            'P' || lpad(v_i::text, 4, '0'), -- P0001, P0002...
            v_price,
            v_price * 0.7, -- 30% margen
            v_category,
            100, -- Stock inicial (se sobreescribirá si hay movimientos, pero útil para base)
            10,
            v_is_weighable,
            v_unit
        );
    END LOOP;
END $$;

-- 5. Crear Clientes
INSERT INTO clients (store_id, name, cedula, phone, credit_limit, balance)
VALUES
('11111111-1111-1111-1111-111111111111', 'Cliente Frecuente 1', 'C001', '3001234567', 1000000, 0),
('11111111-1111-1111-1111-111111111111', 'Cliente Fiador', 'C002', '3109876543', 500000, 150000), -- Debe 150k
('11111111-1111-1111-1111-111111111111', 'Vecino Juan', 'C003', '3201112233', 200000, 0);

-- Generar 7 clientes más
DO $$
DECLARE
    v_store_id UUID := '11111111-1111-1111-1111-111111111111';
    v_i INTEGER;
BEGIN
    FOR v_i IN 4..10 LOOP
        INSERT INTO clients (store_id, name, cedula, phone, credit_limit, balance)
        VALUES (
            v_store_id,
            'Cliente Genérico ' || v_i,
            'C00' || v_i,
            '300000000' || v_i,
            100000,
            0
        );
    END LOOP;
END $$;

-- Fin del seeding
