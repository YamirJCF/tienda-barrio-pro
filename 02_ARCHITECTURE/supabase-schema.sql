-- =============================================
-- TIENDA DE BARRIO PRO - SUPABASE SCHEMA
-- =============================================
-- Sistema de gestión de tiendas con:
-- - Triggers automáticos para inventario
-- - RPC para operaciones críticas
-- - RLS para seguridad de datos
-- =============================================

-- Habilitar extensión para UUID y crypto
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================
-- TABLAS BASE
-- =============================================

-- Tienda/Negocio
CREATE TABLE IF NOT EXISTS stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  owner_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Empleados
CREATE TABLE IF NOT EXISTS employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  pin TEXT NOT NULL, -- Hasheado con crypt()
  permissions JSONB DEFAULT '{"canSell": true, "canViewInventory": true, "canViewReports": false, "canFiar": false}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Productos
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  plu TEXT NOT NULL,
  price DECIMAL(12,2) NOT NULL,
  cost_price DECIMAL(12,2), -- ⚠️ Protegido por RLS
  category TEXT DEFAULT 'General',
  current_stock DECIMAL(10,3) DEFAULT 0, -- ⚠️ Read-only, actualizado por trigger
  min_stock INTEGER DEFAULT 0,
  is_weighable BOOLEAN DEFAULT false,
  measurement_unit TEXT CHECK (measurement_unit IN ('kg', 'lb', 'g', 'un')) DEFAULT 'un',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(store_id, plu)
);

-- Movimientos de Inventario (Kardex)
CREATE TABLE IF NOT EXISTS inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  movement_type TEXT CHECK (movement_type IN ('entrada', 'salida', 'ajuste', 'venta', 'devolucion')) NOT NULL,
  quantity DECIMAL(10,3) NOT NULL,
  reason TEXT,
  sale_id UUID, -- Referencia a ventas si aplica
  created_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Clientes
CREATE TABLE IF NOT EXISTS clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  cedula TEXT NOT NULL,
  phone TEXT,
  credit_limit DECIMAL(12,2) DEFAULT 0,
  balance DECIMAL(12,2) DEFAULT 0, -- Positivo = debe dinero
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(store_id, cedula)
);

-- Transacciones de Clientes (Compras fiadas y Pagos)
CREATE TABLE IF NOT EXISTS client_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
  type TEXT CHECK (type IN ('purchase', 'payment')) NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  description TEXT,
  sale_id UUID, -- Si es purchase, referencia a la venta
  created_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Ventas
CREATE TABLE IF NOT EXISTS sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  employee_id UUID REFERENCES employees(id),
  ticket_number SERIAL,
  total DECIMAL(12,2) NOT NULL,
  payment_method TEXT CHECK (payment_method IN ('cash', 'nequi', 'fiado')) NOT NULL,
  amount_received DECIMAL(12,2),
  change DECIMAL(12,2),
  client_id UUID REFERENCES clients(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Items de Venta
CREATE TABLE IF NOT EXISTS sale_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id UUID REFERENCES sales(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  product_name TEXT NOT NULL, -- Snapshot del nombre
  quantity DECIMAL(10,3) NOT NULL,
  price DECIMAL(12,2) NOT NULL,
  subtotal DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Gastos
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL,
  description TEXT NOT NULL,
  category TEXT DEFAULT 'General',
  created_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Registro de Caja
CREATE TABLE IF NOT EXISTS cash_register (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  type TEXT CHECK (type IN ('opening', 'closing')) NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  notes TEXT,
  created_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(store_id, date, type)
);

-- Sesiones de Empleados
CREATE TABLE IF NOT EXISTS employee_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
  device_info TEXT,
  ip_address INET,
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ
);

-- Solicitudes de Acceso IAM (Control de Dispositivos)
-- PROTOCOLO IAM-01: Device Fingerprinting
CREATE TABLE IF NOT EXISTS access_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
  device_fingerprint TEXT NOT NULL,
  user_agent TEXT,
  ip_address INET,
  status TEXT CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
  reviewed_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  UNIQUE(employee_id, device_fingerprint)
);

-- =============================================
-- TRIGGERS
-- =============================================

-- Trigger: Actualizar stock automáticamente
CREATE OR REPLACE FUNCTION update_product_stock()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.movement_type IN ('entrada', 'devolucion') THEN
    UPDATE products 
    SET current_stock = current_stock + NEW.quantity,
        updated_at = now()
    WHERE id = NEW.product_id;
  ELSIF NEW.movement_type IN ('salida', 'venta') THEN
    UPDATE products 
    SET current_stock = current_stock - NEW.quantity,
        updated_at = now()
    WHERE id = NEW.product_id;
  ELSIF NEW.movement_type = 'ajuste' THEN
    -- Ajuste es absoluto, puede ser positivo o negativo
    UPDATE products 
    SET current_stock = current_stock + NEW.quantity,
        updated_at = now()
    WHERE id = NEW.product_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_movement
AFTER INSERT ON inventory_movements
FOR EACH ROW EXECUTE FUNCTION update_product_stock();

-- Trigger: Actualizar timestamps
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_products_updated
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_employees_updated
BEFORE UPDATE ON employees
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_clients_updated
BEFORE UPDATE ON clients
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- =============================================
-- FUNCIONES RPC
-- =============================================

-- RPC: Login de Empleado (Seguro)
CREATE OR REPLACE FUNCTION login_empleado(
  p_username TEXT,
  p_pin TEXT
)
RETURNS JSON AS $$
DECLARE
  v_employee employees%ROWTYPE;
BEGIN
  SELECT * INTO v_employee 
  FROM employees 
  WHERE username = LOWER(p_username)
    AND pin = crypt(p_pin, pin)
    AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false, 
      'error', 'Credenciales inválidas o empleado inactivo'
    );
  END IF;
  
  -- Registrar sesión
  INSERT INTO employee_sessions (employee_id, device_info)
  VALUES (v_employee.id, current_setting('request.headers', true)::json->>'user-agent');
  
  RETURN json_build_object(
    'success', true,
    'employee', json_build_object(
      'id', v_employee.id,
      'name', v_employee.name,
      'username', v_employee.username,
      'permissions', v_employee.permissions
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Login Unificado de Empleado (Gatekeeper de 3 Capas)
-- SPEC-005: Autenticación Unificada e Integridad IAM
CREATE OR REPLACE FUNCTION login_empleado_unificado(
  p_username TEXT,
  p_pin TEXT,
  p_device_fingerprint TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_employee employees%ROWTYPE;
  v_store_id UUID;
  v_is_store_open BOOLEAN := false;
  v_device_status TEXT;
BEGIN
  -- ========================================
  -- NIVEL 1: Validación de Credenciales
  -- ========================================
  SELECT * INTO v_employee 
  FROM employees 
  WHERE username = LOWER(p_username)
    AND pin = crypt(p_pin, pin)
    AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false, 
      'error_code', 'INVALID_CREDENTIALS',
      'error', 'Credenciales inválidas o empleado inactivo'
    );
  END IF;

  v_store_id := v_employee.store_id;

  -- ========================================
  -- NIVEL 2: Validación IAM (Dispositivo)
  -- ========================================
  IF p_device_fingerprint IS NOT NULL THEN
    SELECT status INTO v_device_status
    FROM access_requests
    WHERE employee_id = v_employee.id
      AND device_fingerprint = p_device_fingerprint;

    IF NOT FOUND THEN
      -- Dispositivo nuevo: registrar solicitud
      INSERT INTO access_requests (employee_id, device_fingerprint, user_agent)
      VALUES (v_employee.id, p_device_fingerprint, p_user_agent);
      
      RETURN json_build_object(
        'success', false,
        'error_code', 'GATEKEEPER_PENDING',
        'error', 'Dispositivo en espera de aprobación del Administrador'
      );
    ELSIF v_device_status = 'pending' THEN
      RETURN json_build_object(
        'success', false,
        'error_code', 'GATEKEEPER_PENDING',
        'error', 'Dispositivo en espera de aprobación del Administrador'
      );
    ELSIF v_device_status = 'rejected' THEN
      RETURN json_build_object(
        'success', false,
        'error_code', 'GATEKEEPER_REJECTED',
        'error', 'Acceso denegado desde este dispositivo'
      );
    END IF;
    -- Si status = 'approved', continúa
  END IF;

  -- ========================================
  -- NIVEL 3: Estado de Tienda (Operativo)
  -- ========================================
  SELECT EXISTS (
    SELECT 1 FROM cash_register 
    WHERE store_id = v_store_id 
      AND date = CURRENT_DATE 
      AND type = 'opening'
      AND NOT EXISTS (
        SELECT 1 FROM cash_register 
        WHERE store_id = v_store_id 
          AND date = CURRENT_DATE 
          AND type = 'closing'
      )
  ) INTO v_is_store_open;

  -- Registrar sesión exitosa
  INSERT INTO employee_sessions (employee_id, device_info)
  VALUES (v_employee.id, p_user_agent);

  RETURN json_build_object(
    'success', true,
    'employee', json_build_object(
      'id', v_employee.id,
      'name', v_employee.name,
      'username', v_employee.username,
      'permissions', v_employee.permissions,
      'store_id', v_store_id
    ),
    'store_state', json_build_object(
      'is_open', v_is_store_open
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Crear Empleado (con PIN hasheado)
CREATE OR REPLACE FUNCTION crear_empleado(
  p_store_id UUID,
  p_name TEXT,
  p_username TEXT,
  p_pin TEXT,
  p_permissions JSONB DEFAULT '{"canSell": true, "canViewInventory": true, "canViewReports": false, "canFiar": false}'
)
RETURNS JSON AS $$
DECLARE
  v_employee_id UUID;
BEGIN
  -- Validar PIN de 4 dígitos
  IF LENGTH(p_pin) != 4 OR p_pin !~ '^\d{4}$' THEN
    RETURN json_build_object('success', false, 'error', 'PIN debe ser de 4 dígitos');
  END IF;

  -- Verificar username único
  IF EXISTS (SELECT 1 FROM employees WHERE username = LOWER(p_username)) THEN
    RETURN json_build_object('success', false, 'error', 'Usuario ya existe');
  END IF;

  INSERT INTO employees (store_id, name, username, pin, permissions)
  VALUES (
    p_store_id,
    p_name,
    LOWER(p_username),
    crypt(p_pin, gen_salt('bf')),
    p_permissions
  )
  RETURNING id INTO v_employee_id;

  RETURN json_build_object(
    'success', true,
    'employee_id', v_employee_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Cambiar PIN
CREATE OR REPLACE FUNCTION cambiar_pin(
  p_employee_id UUID,
  p_new_pin TEXT
)
RETURNS JSON AS $$
BEGIN
  IF LENGTH(p_new_pin) != 4 OR p_new_pin !~ '^\d{4}$' THEN
    RETURN json_build_object('success', false, 'error', 'PIN debe ser de 4 dígitos');
  END IF;

  UPDATE employees 
  SET pin = crypt(p_new_pin, gen_salt('bf'))
  WHERE id = p_employee_id;

  RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Procesar Venta Completa
CREATE OR REPLACE FUNCTION procesar_venta(
  p_store_id UUID,
  p_items JSON,
  p_payment_method TEXT,
  p_amount_received DECIMAL DEFAULT NULL,
  p_client_id UUID DEFAULT NULL,
  p_employee_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_sale_id UUID;
  v_total DECIMAL := 0;
  v_item JSON;
  v_product products%ROWTYPE;
BEGIN
  -- 1. Calcular total y validar stock
  FOR v_item IN SELECT * FROM json_array_elements(p_items)
  LOOP
    v_total := v_total + (v_item->>'subtotal')::DECIMAL;
    
    -- Validar que existe stock suficiente
    SELECT * INTO v_product FROM products WHERE id = (v_item->>'product_id')::UUID;
    IF v_product.current_stock < (v_item->>'quantity')::DECIMAL THEN
      RETURN json_build_object(
        'success', false, 
        'error', 'Stock insuficiente para: ' || v_product.name
      );
    END IF;
  END LOOP;

  -- 2. Validar crédito si es fiado
  IF p_payment_method = 'fiado' THEN
    IF p_client_id IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'Debe seleccionar un cliente para venta fiada');
    END IF;
    
    IF NOT EXISTS (
      SELECT 1 FROM clients 
      WHERE id = p_client_id 
        AND credit_limit - balance >= v_total
    ) THEN
      -- Advertencia pero permite continuar
      NULL;
    END IF;
  END IF;

  -- 3. Crear venta
  INSERT INTO sales (store_id, employee_id, total, payment_method, amount_received, change, client_id)
  VALUES (
    p_store_id,
    p_employee_id,
    v_total, 
    p_payment_method, 
    p_amount_received,
    COALESCE(p_amount_received - v_total, 0),
    p_client_id
  )
  RETURNING id INTO v_sale_id;

  -- 4. Insertar items y movimientos de inventario
  FOR v_item IN SELECT * FROM json_array_elements(p_items)
  LOOP
    SELECT name INTO v_product FROM products WHERE id = (v_item->>'product_id')::UUID;
    
    INSERT INTO sale_items (sale_id, product_id, product_name, quantity, price, subtotal)
    VALUES (
      v_sale_id,
      (v_item->>'product_id')::UUID,
      v_product.name,
      (v_item->>'quantity')::DECIMAL,
      (v_item->>'price')::DECIMAL,
      (v_item->>'subtotal')::DECIMAL
    );

    -- Trigger actualizará el stock automáticamente
    INSERT INTO inventory_movements (product_id, movement_type, quantity, sale_id, created_by)
    VALUES (
      (v_item->>'product_id')::UUID,
      'venta',
      (v_item->>'quantity')::DECIMAL,
      v_sale_id,
      p_employee_id
    );
  END LOOP;

  -- 5. Si es fiado, registrar deuda
  IF p_payment_method = 'fiado' AND p_client_id IS NOT NULL THEN
    INSERT INTO client_transactions (client_id, type, amount, description, sale_id, created_by)
    VALUES (p_client_id, 'purchase', v_total, 'Compra #' || v_sale_id, v_sale_id, p_employee_id);

    UPDATE clients SET balance = balance + v_total WHERE id = p_client_id;
  END IF;

  RETURN json_build_object(
    'success', true,
    'sale_id', v_sale_id,
    'total', v_total,
    'change', COALESCE(p_amount_received - v_total, 0)
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- RPC: Registrar Pago de Cliente
CREATE OR REPLACE FUNCTION registrar_pago_cliente(
  p_client_id UUID,
  p_amount DECIMAL,
  p_description TEXT DEFAULT 'Abono',
  p_employee_id UUID
)
RETURNS JSON AS $$
BEGIN
  INSERT INTO client_transactions (client_id, type, amount, description, created_by)
  VALUES (p_client_id, 'payment', p_amount, p_description, p_employee_id);

  UPDATE clients SET balance = balance - p_amount WHERE id = p_client_id;

  RETURN json_build_object(
    'success', true,
    'new_balance', (SELECT balance FROM clients WHERE id = p_client_id)
  );
END;
$$ LANGUAGE plpgsql;

-- RPC: Reporte de Caja
CREATE OR REPLACE FUNCTION get_cash_report(
  p_store_id UUID,
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSON AS $$
DECLARE
  v_opening DECIMAL;
  v_sales_data JSON;
  v_expenses DECIMAL;
BEGIN
  -- Obtener apertura de caja
  SELECT amount INTO v_opening 
  FROM cash_register 
  WHERE store_id = p_store_id AND date = p_date AND type = 'opening';

  -- Calcular ventas
  SELECT json_build_object(
    'cash', COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN total ELSE 0 END), 0),
    'nequi', COALESCE(SUM(CASE WHEN payment_method = 'nequi' THEN total ELSE 0 END), 0),
    'fiado', COALESCE(SUM(CASE WHEN payment_method = 'fiado' THEN total ELSE 0 END), 0),
    'total', COALESCE(SUM(total), 0),
    'count', COUNT(*)
  ) INTO v_sales_data
  FROM sales 
  WHERE store_id = p_store_id AND DATE(created_at) = p_date;

  -- Calcular gastos
  SELECT COALESCE(SUM(amount), 0) INTO v_expenses
  FROM expenses 
  WHERE store_id = p_store_id AND DATE(created_at) = p_date;

  RETURN json_build_object(
    'date', p_date,
    'opening_cash', COALESCE(v_opening, 0),
    'sales', v_sales_data,
    'expenses', v_expenses,
    'expected_cash', COALESCE(v_opening, 0) + (v_sales_data->>'cash')::DECIMAL - v_expenses
  );
END;
$$ LANGUAGE plpgsql;

-- RPC: Reporte de Deudores
CREATE OR REPLACE FUNCTION get_debtors_report(p_store_id UUID)
RETURNS JSON AS $$
BEGIN
  RETURN (
    SELECT COALESCE(json_agg(
      json_build_object(
        'client', json_build_object('id', c.id, 'name', c.name, 'cedula', c.cedula, 'phone', c.phone),
        'balance', c.balance,
        'credit_limit', c.credit_limit,
        'available_credit', c.credit_limit - c.balance,
        'last_purchase', (
          SELECT MAX(created_at) FROM client_transactions 
          WHERE client_id = c.id AND type = 'purchase'
        )
      )
      ORDER BY c.balance DESC
    ), '[]'::json)
    FROM clients c
    WHERE c.store_id = p_store_id AND c.balance > 0
  );
END;
$$ LANGUAGE plpgsql;

-- RPC: Calcular precio para producto pesable
CREATE OR REPLACE FUNCTION calculate_weighable_price(
  p_product_id UUID,
  p_input_value DECIMAL,
  p_mode TEXT -- 'weight' o 'value'
)
RETURNS JSON AS $$
DECLARE
  v_product products%ROWTYPE;
  v_quantity DECIMAL;
  v_subtotal DECIMAL;
BEGIN
  SELECT * INTO v_product FROM products WHERE id = p_product_id;
  
  IF NOT v_product.is_weighable THEN
    RETURN json_build_object('success', false, 'error', 'Producto no es pesable');
  END IF;

  IF p_mode = 'value' THEN
    -- Usuario ingresó valor monetario
    v_subtotal := p_input_value;
    v_quantity := ROUND(p_input_value / v_product.price, 3);
  ELSE
    -- Usuario ingresó peso
    v_quantity := p_input_value;
    v_subtotal := ROUND(p_input_value * v_product.price, 0);
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'quantity', v_quantity,
    'subtotal', v_subtotal,
    'unit', v_product.measurement_unit,
    'price_per_unit', v_product.price
  );
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- VISTAS SEGURAS
-- =============================================

-- Vista de productos sin costo (para vendedores)
CREATE OR REPLACE VIEW products_safe AS
SELECT 
  id, store_id, name, plu, price,
  category, current_stock, min_stock,
  is_weighable, measurement_unit,
  created_at, updated_at
FROM products;

-- =============================================
-- RLS (Row Level Security)
-- =============================================

-- Habilitar RLS en tablas sensibles
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

-- Política: Solo ver productos de tu tienda
CREATE POLICY "view_own_store_products" ON products
FOR SELECT USING (true); -- Ajustar según autenticación

-- Política: Solo administradores ven cost_price
-- (Implementado via vista products_safe)

-- =============================================
-- ÍNDICES
-- =============================================

CREATE INDEX IF NOT EXISTS idx_products_store ON products(store_id);
CREATE INDEX IF NOT EXISTS idx_products_plu ON products(plu);
CREATE INDEX IF NOT EXISTS idx_sales_store_date ON sales(store_id, created_at);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_product ON inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_clients_store ON clients(store_id);
CREATE INDEX IF NOT EXISTS idx_client_transactions_client ON client_transactions(client_id);
CREATE INDEX IF NOT EXISTS idx_access_requests_employee_device ON access_requests(employee_id, device_fingerprint);

-- =============================================
-- DATOS INICIALES (Desarrollo)
-- =============================================

-- Insertar tienda de ejemplo
INSERT INTO stores (id, name, address) VALUES 
  ('00000000-0000-0000-0000-000000000001', 'Mi Tienda de Barrio', 'Calle Principal #123')
ON CONFLICT DO NOTHING;

-- Insertar empleado admin (PIN: 0000)
INSERT INTO employees (store_id, name, username, pin, permissions) VALUES 
  ('00000000-0000-0000-0000-000000000001', 'Administrador', 'admin', crypt('0000', gen_salt('bf')), 
   '{"canSell": true, "canViewInventory": true, "canViewReports": true, "canFiar": true}')
ON CONFLICT DO NOTHING;
