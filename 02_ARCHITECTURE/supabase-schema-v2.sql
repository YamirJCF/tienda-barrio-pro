-- =============================================
-- TIENDA DE BARRIO PRO - SUPABASE SCHEMA v2
-- =============================================
-- Generado desde: FRDs en 01_REQUIREMENTS/FRD/
-- Fecha: 2026-01-28
-- Arquitecto: @[/data]
-- =============================================

-- =============================================
-- EXTENSIONES REQUERIDAS
-- =============================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================
-- FUNCIÓN HELPER: get_current_store_id()
-- =============================================
-- Extrae store_id del JWT del usuario autenticado
-- Requisito: QA_ADDENDUM §6.1
CREATE OR REPLACE FUNCTION public.get_current_store_id()
RETURNS UUID AS $$
BEGIN
  RETURN (auth.jwt() ->> 'store_id')::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- =============================================
-- MÓDULO: CORE (FRD_002)
-- =============================================

-- Tabla: stores
-- FRD: FRD_002_REGISTRO_ADMIN.md
-- Entidad: Tienda
CREATE TABLE IF NOT EXISTS public.stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  subscription_plan TEXT DEFAULT 'free' CHECK (subscription_plan IN ('free', 'pro', 'enterprise')),
  store_pin_hash TEXT, -- Hash del PIN de caja (bcrypt via crypt())
  
  -- Campos de auditoría (QA_ADDENDUM §4.1)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para stores
CREATE INDEX IF NOT EXISTS idx_stores_slug ON public.stores(slug);

-- RLS para stores
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "stores_select_own" ON public.stores
  FOR SELECT USING (id = get_current_store_id());

CREATE POLICY "stores_update_own" ON public.stores
  FOR UPDATE USING (id = get_current_store_id());

CREATE POLICY "stores_insert_auth" ON public.stores
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Tabla: admin_profiles
-- FRD: FRD_002_REGISTRO_ADMIN.md
-- Entidad: Perfil de Admin
CREATE TABLE IF NOT EXISTS public.admin_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'owner' CHECK (role IN ('owner', 'manager')),
  is_verified BOOLEAN DEFAULT false,
  
  -- Campos de auditoría (QA_ADDENDUM §4.1)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para admin_profiles
CREATE INDEX IF NOT EXISTS idx_admin_profiles_store ON public.admin_profiles(store_id);

-- RLS para admin_profiles
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_profiles_select_own" ON public.admin_profiles
  FOR SELECT USING (store_id = get_current_store_id());

CREATE POLICY "admin_profiles_update_self" ON public.admin_profiles
  FOR UPDATE USING (id = auth.uid());

-- =============================================
-- TRIGGER: Actualizar updated_at automáticamente
-- =============================================
CREATE OR REPLACE FUNCTION public.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stores_updated
  BEFORE UPDATE ON public.stores
  FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

-- =============================================
-- MÓDULO: EMPLEADOS (FRD_003)
-- =============================================

-- Tabla: employees
-- FRD: FRD_003_GESTION_EMPLEADOS.md
-- Entidad: Empleado
CREATE TABLE IF NOT EXISTS public.employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE, -- Alias numérico único GLOBAL
  pin_hash TEXT NOT NULL, -- Hash del PIN 4 dígitos (bcrypt via crypt())
  is_active BOOLEAN DEFAULT true,
  permissions JSONB DEFAULT '{
    "canViewInventory": false,
    "canFiar": false,
    "canOpenCloseCash": false,
    "canViewReports": false
  }'::jsonb,
  
  -- Campos de auditoría (QA_ADDENDUM §4.1)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para employees
CREATE INDEX IF NOT EXISTS idx_employees_store ON public.employees(store_id);
CREATE INDEX IF NOT EXISTS idx_employees_username ON public.employees(username);
CREATE INDEX IF NOT EXISTS idx_employees_active ON public.employees(store_id, is_active);

-- RLS para employees
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;

CREATE POLICY "employees_select_store" ON public.employees
  FOR SELECT USING (store_id = get_current_store_id());

CREATE POLICY "employees_insert_store" ON public.employees
  FOR INSERT WITH CHECK (store_id = get_current_store_id());

CREATE POLICY "employees_update_store" ON public.employees
  FOR UPDATE USING (store_id = get_current_store_id());

-- Trigger para updated_at en employees
CREATE TRIGGER trg_employees_updated
  BEFORE UPDATE ON public.employees
  FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

-- =============================================
-- RPC: Validar PIN de Empleado (Seguro)
-- FRD: FRD_003 + QA_ADDENDUM §3.2 CRED-004
-- =============================================
CREATE OR REPLACE FUNCTION public.validar_pin_empleado(
  p_username TEXT,
  p_pin TEXT
)
RETURNS JSON AS $$
DECLARE
  v_employee public.employees%ROWTYPE;
  v_store_id UUID;
BEGIN
  -- Buscar empleado por username (global)
  SELECT * INTO v_employee
  FROM public.employees
  WHERE username = p_username
    AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Usuario no encontrado o inactivo',
      'code', 'USER_NOT_FOUND'
    );
  END IF;
  
  -- Validar PIN con crypt()
  IF v_employee.pin_hash != crypt(p_pin, v_employee.pin_hash) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'PIN incorrecto',
      'code', 'INVALID_PIN'
    );
  END IF;
  
  v_store_id := v_employee.store_id;
  
  -- Retornar datos del empleado (sin hash)
  RETURN json_build_object(
    'success', true,
    'employee', json_build_object(
      'id', v_employee.id,
      'name', v_employee.name,
      'username', v_employee.username,
      'permissions', v_employee.permissions,
      'store_id', v_store_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- RPC: Crear Empleado (con validación de límite)
-- FRD: FRD_003 §7 - Límite 5 empleados activos
-- =============================================
CREATE OR REPLACE FUNCTION public.crear_empleado(
  p_store_id UUID,
  p_name TEXT,
  p_username TEXT,
  p_pin TEXT,
  p_permissions JSONB DEFAULT '{}'::jsonb
)
RETURNS JSON AS $$
DECLARE
  v_count INTEGER;
  v_employee_id UUID;
BEGIN
  -- Validar límite de 5 empleados activos
  SELECT COUNT(*) INTO v_count
  FROM public.employees
  WHERE store_id = p_store_id AND is_active = true;
  
  IF v_count >= 5 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Límite de 5 empleados activos alcanzado',
      'code', 'EMPLOYEE_LIMIT_REACHED'
    );
  END IF;
  
  -- Crear empleado con PIN hasheado
  INSERT INTO public.employees (store_id, name, username, pin_hash, permissions)
  VALUES (
    p_store_id,
    p_name,
    p_username,
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

-- =============================================
-- FIN MÓDULO: EMPLEADOS (FRD_003)
-- =============================================

-- =============================================
-- MÓDULO: INVENTARIO (FRD_006)
-- =============================================

-- Tabla: products
-- FRD: FRD_006_INVENTARIO.md
-- Entidad: Producto
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(name) >= 2),
  plu TEXT, -- Código rápido 4 dígitos, único por tienda
  price DECIMAL(12,0) NOT NULL CHECK (price > 0), -- Redondeado al $50
  cost_price DECIMAL(12,0), -- Visible solo Admin
  current_stock DECIMAL(10,2) DEFAULT 0 CHECK (current_stock >= 0),
  min_stock DECIMAL(10,2) DEFAULT 5,
  category TEXT,
  measurement_unit TEXT DEFAULT 'unidad' CHECK (measurement_unit IN ('unidad', 'kg', 'lb', 'g')),
  is_weighable BOOLEAN DEFAULT false,
  low_stock_alerted BOOLEAN DEFAULT false,
  
  -- Campos de auditoría (QA_ADDENDUM §4.1)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  
  -- Constraint único para PLU por tienda
  UNIQUE (store_id, plu)
);

-- Índices para products
CREATE INDEX IF NOT EXISTS idx_products_store ON public.products(store_id);
CREATE INDEX IF NOT EXISTS idx_products_plu ON public.products(store_id, plu);
CREATE INDEX IF NOT EXISTS idx_products_low_stock ON public.products(store_id, current_stock, min_stock);

-- RLS para products
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "products_select_store" ON public.products
  FOR SELECT USING (store_id = get_current_store_id());

CREATE POLICY "products_insert_store" ON public.products
  FOR INSERT WITH CHECK (store_id = get_current_store_id());

CREATE POLICY "products_update_store" ON public.products
  FOR UPDATE USING (store_id = get_current_store_id());

-- DELETE solo via RPC para validar permisos Admin
CREATE POLICY "products_delete_store" ON public.products
  FOR DELETE USING (store_id = get_current_store_id());

-- Trigger para updated_at en products
CREATE TRIGGER trg_products_updated
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

-- Tabla: inventory_movements (IMMUTABLE - INSERT-only)
-- FRD: FRD_006_INVENTARIO.md
-- Entidad: Movimientos de Inventario (Kardex)
CREATE TABLE IF NOT EXISTS public.inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  movement_type TEXT NOT NULL CHECK (movement_type IN ('entrada', 'salida', 'ajuste', 'venta', 'devolucion')),
  quantity DECIMAL(10,2) NOT NULL,
  reason TEXT,
  created_by UUID REFERENCES public.employees(id),
  
  -- Campos de auditoría (QA_ADDENDUM §4.2 - IMMUTABLE)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para inventory_movements
CREATE INDEX IF NOT EXISTS idx_movements_product ON public.inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_movements_created ON public.inventory_movements(created_at);

-- RLS para inventory_movements (IMMUTABLE)
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

-- SELECT via JOIN con products
CREATE POLICY "movements_select_store" ON public.inventory_movements
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = product_id AND p.store_id = get_current_store_id()
    )
  );

-- INSERT solo via RPC transaccional
CREATE POLICY "movements_insert_store" ON public.inventory_movements
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = product_id AND p.store_id = get_current_store_id()
    )
  );

-- =============================================
-- FUNCIÓN: Actualizar stock automáticamente
-- FRD_006 §Kardex - Trigger automático
-- =============================================
CREATE OR REPLACE FUNCTION public.update_product_stock()
RETURNS TRIGGER AS $$
DECLARE
  v_new_stock DECIMAL(10,2);
  v_product public.products%ROWTYPE;
BEGIN
  -- Calcular nuevo stock según tipo de movimiento
  SELECT * INTO v_product FROM public.products WHERE id = NEW.product_id;
  
  CASE NEW.movement_type
    WHEN 'entrada', 'devolucion' THEN
      v_new_stock := v_product.current_stock + NEW.quantity;
    WHEN 'salida', 'venta' THEN
      v_new_stock := v_product.current_stock - NEW.quantity;
      -- Validar stock no negativo
      IF v_new_stock < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente. Disponible: % %', 
          v_product.current_stock, v_product.measurement_unit;
      END IF;
    WHEN 'ajuste' THEN
      -- Ajuste puede ser positivo o negativo
      v_new_stock := v_product.current_stock + NEW.quantity;
      IF v_new_stock < 0 THEN
        RAISE EXCEPTION 'El ajuste resultaría en stock negativo';
      END IF;
  END CASE;
  
  -- Actualizar stock del producto
  UPDATE public.products
  SET current_stock = v_new_stock,
      -- Resetear alerta si stock vuelve a nivel normal
      low_stock_alerted = CASE 
        WHEN v_new_stock >= min_stock THEN false 
        ELSE low_stock_alerted 
      END
  WHERE id = NEW.product_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_stock
  AFTER INSERT ON public.inventory_movements
  FOR EACH ROW EXECUTE FUNCTION public.update_product_stock();

-- =============================================
-- FIN MÓDULO: INVENTARIO (FRD_006)
-- =============================================

-- =============================================
-- MÓDULO: VENTAS (FRD_007)
-- =============================================

-- Secuencia para ticket numbers por tienda
-- Se usa dentro de procesar_venta para generar número secuencial
CREATE SEQUENCE IF NOT EXISTS public.ticket_sequence START 1;

-- Tabla: sales (IMMUTABLE)
-- FRD: FRD_007_VENTAS.md
-- Entidad: Venta
CREATE TABLE IF NOT EXISTS public.sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  ticket_number INTEGER NOT NULL,
  employee_id UUID NOT NULL REFERENCES public.employees(id),
  client_id UUID, -- FK a clients (WO-DM-006)
  total DECIMAL(12,0) NOT NULL,
  rounding_difference DECIMAL(10,2) DEFAULT 0,
  payment_method TEXT NOT NULL CHECK (payment_method IN ('efectivo', 'nequi', 'daviplata', 'fiado')),
  amount_received DECIMAL(12,0),
  change_given DECIMAL(12,0),
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('synced', 'pending', 'failed')),
  local_id TEXT, -- ID local para offline sync
  is_voided BOOLEAN DEFAULT false,
  voided_by UUID REFERENCES public.employees(id),
  void_reason TEXT,
  
  -- Campos de auditoría (QA_ADDENDUM §4.2 - IMMUTABLE)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  
  -- Constraint: ticket_number único por tienda
  UNIQUE (store_id, ticket_number)
);

-- Índices para sales
CREATE INDEX IF NOT EXISTS idx_sales_store ON public.sales(store_id);
CREATE INDEX IF NOT EXISTS idx_sales_employee ON public.sales(employee_id);
CREATE INDEX IF NOT EXISTS idx_sales_created ON public.sales(store_id, created_at);
CREATE INDEX IF NOT EXISTS idx_sales_sync ON public.sales(sync_status) WHERE sync_status != 'synced';

-- RLS para sales (IMMUTABLE)
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sales_select_store" ON public.sales
  FOR SELECT USING (store_id = get_current_store_id());

-- INSERT solo via RPC procesar_venta
CREATE POLICY "sales_insert_store" ON public.sales
  FOR INSERT WITH CHECK (store_id = get_current_store_id());

-- Tabla: sale_items (IMMUTABLE)
-- FRD: FRD_007_VENTAS.md
-- Entidad: Items de Venta
CREATE TABLE IF NOT EXISTS public.sale_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  quantity DECIMAL(10,2) NOT NULL,
  unit_price DECIMAL(12,0) NOT NULL,
  subtotal DECIMAL(12,0) NOT NULL,
  
  -- Campos de auditoría (QA_ADDENDUM §4.2 - IMMUTABLE)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para sale_items
CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON public.sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product ON public.sale_items(product_id);

-- RLS para sale_items (IMMUTABLE)
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;

-- SELECT via JOIN con sales
CREATE POLICY "sale_items_select_store" ON public.sale_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.sales s
      WHERE s.id = sale_id AND s.store_id = get_current_store_id()
    )
  );

-- INSERT solo via RPC
CREATE POLICY "sale_items_insert_store" ON public.sale_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.sales s
      WHERE s.id = sale_id AND s.store_id = get_current_store_id()
    )
  );

-- =============================================
-- RPC: Procesar Venta (Transacción Atómica)
-- FRD_007 - Orquesta toda la venta
-- =============================================
CREATE OR REPLACE FUNCTION public.procesar_venta(
  p_store_id UUID,
  p_employee_id UUID,
  p_items JSONB, -- [{product_id, quantity, unit_price, subtotal}]
  p_total DECIMAL,
  p_payment_method TEXT,
  p_amount_received DECIMAL DEFAULT NULL,
  p_client_id UUID DEFAULT NULL,
  p_local_id TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_sale_id UUID;
  v_ticket_number INTEGER;
  v_item JSONB;
  v_change DECIMAL;
  v_rounding_diff DECIMAL := 0;
BEGIN
  -- Validar límite de 50 items
  IF jsonb_array_length(p_items) > 50 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Máximo 50 productos por venta',
      'code', 'MAX_ITEMS_EXCEEDED'
    );
  END IF;
  
  -- Generar ticket_number secuencial para esta tienda
  SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number
  FROM public.sales
  WHERE store_id = p_store_id;
  
  -- Calcular vueltas si es efectivo
  IF p_payment_method = 'efectivo' AND p_amount_received IS NOT NULL THEN
    v_change := p_amount_received - p_total;
  END IF;
  
  -- Crear la venta
  INSERT INTO public.sales (
    store_id, ticket_number, employee_id, client_id,
    total, rounding_difference, payment_method,
    amount_received, change_given, local_id, sync_status
  )
  VALUES (
    p_store_id, v_ticket_number, p_employee_id, p_client_id,
    p_total, v_rounding_diff, p_payment_method,
    p_amount_received, v_change, p_local_id, 'synced'
  )
  RETURNING id INTO v_sale_id;
  
  -- Insertar items y crear movimientos de inventario
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Insertar item
    INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
    VALUES (
      v_sale_id,
      (v_item->>'product_id')::UUID,
      (v_item->>'quantity')::DECIMAL,
      (v_item->>'unit_price')::DECIMAL,
      (v_item->>'subtotal')::DECIMAL
    );
    
    -- Crear movimiento de inventario (trigger actualizará stock)
    INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
    VALUES (
      (v_item->>'product_id')::UUID,
      'venta',
      (v_item->>'quantity')::DECIMAL,
      'Venta #' || v_ticket_number,
      p_employee_id
    );
  END LOOP;
  
  RETURN json_build_object(
    'success', true,
    'sale_id', v_sale_id,
    'ticket_number', v_ticket_number
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'code', 'SALE_PROCESSING_ERROR'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FIN MÓDULO: VENTAS (FRD_007)
-- =============================================

-- =============================================
-- MÓDULO: CLIENTES (FRD_009)
-- =============================================

-- Tabla: clients (Soft Delete)
-- FRD: FRD_009_CLIENTES.md
-- Entidad: Cliente
CREATE TABLE IF NOT EXISTS public.clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(name) >= 3),
  id_number TEXT NOT NULL, -- Cédula, única por tienda
  phone TEXT,
  credit_limit DECIMAL(12,0) NOT NULL DEFAULT 100000,
  balance DECIMAL(12,0) DEFAULT 0 CHECK (balance >= 0),
  is_deleted BOOLEAN DEFAULT false,
  deleted_at TIMESTAMPTZ,
  
  -- Campos de auditoría (QA_ADDENDUM §4.1)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  
  -- Constraint único para cédula por tienda
  UNIQUE (store_id, id_number)
);

-- Índices para clients
CREATE INDEX IF NOT EXISTS idx_clients_store ON public.clients(store_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_clients_id_number ON public.clients(store_id, id_number);
CREATE INDEX IF NOT EXISTS idx_clients_balance ON public.clients(store_id, balance) WHERE balance > 0;

-- RLS para clients
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clients_select_store" ON public.clients
  FOR SELECT USING (store_id = get_current_store_id() AND NOT is_deleted);

CREATE POLICY "clients_insert_store" ON public.clients
  FOR INSERT WITH CHECK (store_id = get_current_store_id());

CREATE POLICY "clients_update_store" ON public.clients
  FOR UPDATE USING (store_id = get_current_store_id());

-- Trigger para updated_at en clients
CREATE TRIGGER trg_clients_updated
  BEFORE UPDATE ON public.clients
  FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

-- Tabla: client_transactions (IMMUTABLE)
-- FRD: FRD_009_CLIENTES.md
-- Entidad: Transacción de Cliente
CREATE TABLE IF NOT EXISTS public.client_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('compra', 'pago')),
  amount DECIMAL(12,0) NOT NULL CHECK (amount > 0),
  description TEXT,
  sale_id UUID REFERENCES public.sales(id), -- Solo para compras
  
  -- Campos de auditoría (QA_ADDENDUM §4.2 - IMMUTABLE)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para client_transactions
CREATE INDEX IF NOT EXISTS idx_client_tx_client ON public.client_transactions(client_id);
CREATE INDEX IF NOT EXISTS idx_client_tx_created ON public.client_transactions(created_at);

-- RLS para client_transactions (IMMUTABLE)
ALTER TABLE public.client_transactions ENABLE ROW LEVEL SECURITY;

-- SELECT via JOIN con clients
CREATE POLICY "client_tx_select_store" ON public.client_transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.clients c
      WHERE c.id = client_id AND c.store_id = get_current_store_id()
    )
  );

CREATE POLICY "client_tx_insert_store" ON public.client_transactions
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.clients c
      WHERE c.id = client_id AND c.store_id = get_current_store_id()
    )
  );

-- =============================================
-- RPC: Registrar Abono
-- FRD_009 - Valida balance >= monto
-- =============================================
CREATE OR REPLACE FUNCTION public.registrar_abono(
  p_client_id UUID,
  p_amount DECIMAL
)
RETURNS JSON AS $$
DECLARE
  v_client public.clients%ROWTYPE;
  v_new_balance DECIMAL;
BEGIN
  -- Obtener cliente
  SELECT * INTO v_client FROM public.clients WHERE id = p_client_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Cliente no encontrado', 'code', 'CLIENT_NOT_FOUND');
  END IF;
  
  -- Validar monto no excede balance
  IF p_amount > v_client.balance THEN
    RETURN json_build_object(
      'success', false,
      'error', format('El abono ($%s) supera la deuda actual ($%s)', p_amount, v_client.balance),
      'code', 'AMOUNT_EXCEEDS_BALANCE'
    );
  END IF;
  
  v_new_balance := v_client.balance - p_amount;
  
  -- Actualizar balance del cliente
  UPDATE public.clients SET balance = v_new_balance WHERE id = p_client_id;
  
  -- Registrar transacción
  INSERT INTO public.client_transactions (client_id, transaction_type, amount, description)
  VALUES (p_client_id, 'pago', p_amount, 'Abono efectivo');
  
  RETURN json_build_object(
    'success', true,
    'new_balance', v_new_balance
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FIN MÓDULO: CLIENTES (FRD_009)
-- =============================================

-- =============================================
-- MÓDULO: CONTROL DE CAJA (FRD_004)
-- =============================================

-- Tabla: cash_sessions
-- FRD: FRD_004_CONTROL_DE_CAJA.md
-- Entidad: Sesión de Caja
CREATE TABLE IF NOT EXISTS public.cash_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  opened_by UUID NOT NULL REFERENCES public.employees(id),
  closed_by UUID REFERENCES public.employees(id),
  opening_balance DECIMAL(12,0) NOT NULL,
  expected_balance DECIMAL(12,0), -- Calculado al cerrar
  actual_balance DECIMAL(12,0),   -- Declarado por usuario
  difference DECIMAL(12,0),       -- expected - actual
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  opened_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  closed_at TIMESTAMPTZ
);

-- Partial unique index: Solo 1 sesión abierta por tienda
CREATE UNIQUE INDEX IF NOT EXISTS idx_cash_sessions_one_open 
  ON public.cash_sessions(store_id) 
  WHERE status = 'open';

-- Índices para cash_sessions
CREATE INDEX IF NOT EXISTS idx_cash_sessions_store ON public.cash_sessions(store_id);
CREATE INDEX IF NOT EXISTS idx_cash_sessions_status ON public.cash_sessions(store_id, status);

-- RLS para cash_sessions
ALTER TABLE public.cash_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cash_sessions_select_store" ON public.cash_sessions
  FOR SELECT USING (store_id = get_current_store_id());

CREATE POLICY "cash_sessions_insert_store" ON public.cash_sessions
  FOR INSERT WITH CHECK (store_id = get_current_store_id());

CREATE POLICY "cash_sessions_update_store" ON public.cash_sessions
  FOR UPDATE USING (store_id = get_current_store_id());

-- Tabla: cash_movements (IMMUTABLE)
-- FRD: FRD_004_CONTROL_DE_CAJA.md
-- Entidad: Movimiento de Caja
CREATE TABLE IF NOT EXISTS public.cash_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.cash_sessions(id) ON DELETE CASCADE,
  movement_type TEXT NOT NULL CHECK (movement_type IN ('ingreso', 'gasto')),
  amount DECIMAL(12,0) NOT NULL CHECK (amount > 0),
  description TEXT NOT NULL,
  sale_id UUID REFERENCES public.sales(id), -- Solo para ingresos de venta
  
  -- Campos de auditoría (QA_ADDENDUM §4.2 - IMMUTABLE)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para cash_movements
CREATE INDEX IF NOT EXISTS idx_cash_movements_session ON public.cash_movements(session_id);
CREATE INDEX IF NOT EXISTS idx_cash_movements_type ON public.cash_movements(session_id, movement_type);

-- RLS para cash_movements (IMMUTABLE)
ALTER TABLE public.cash_movements ENABLE ROW LEVEL SECURITY;

-- SELECT via JOIN con cash_sessions
CREATE POLICY "cash_movements_select_store" ON public.cash_movements
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.cash_sessions cs
      WHERE cs.id = session_id AND cs.store_id = get_current_store_id()
    )
  );

CREATE POLICY "cash_movements_insert_store" ON public.cash_movements
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.cash_sessions cs
      WHERE cs.id = session_id AND cs.store_id = get_current_store_id()
    )
  );

-- =============================================
-- RPC: Abrir Caja
-- FRD_004 - Valida no haya otra abierta
-- =============================================
CREATE OR REPLACE FUNCTION public.abrir_caja(
  p_store_id UUID,
  p_employee_id UUID,
  p_opening_balance DECIMAL
)
RETURNS JSON AS $$
DECLARE
  v_existing_session UUID;
  v_session_id UUID;
BEGIN
  -- Verificar que no hay sesión abierta
  SELECT id INTO v_existing_session
  FROM public.cash_sessions
  WHERE store_id = p_store_id AND status = 'open';
  
  IF FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Ya existe una caja abierta',
      'code', 'CASH_ALREADY_OPEN'
    );
  END IF;
  
  -- Crear nueva sesión
  INSERT INTO public.cash_sessions (store_id, opened_by, opening_balance)
  VALUES (p_store_id, p_employee_id, p_opening_balance)
  RETURNING id INTO v_session_id;
  
  RETURN json_build_object(
    'success', true,
    'session_id', v_session_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- RPC: Cerrar Caja
-- FRD_004 - Calcula balance esperado y diferencia
-- =============================================
CREATE OR REPLACE FUNCTION public.cerrar_caja(
  p_session_id UUID,
  p_employee_id UUID,
  p_actual_balance DECIMAL
)
RETURNS JSON AS $$
DECLARE
  v_session public.cash_sessions%ROWTYPE;
  v_expected DECIMAL;
  v_ingresos DECIMAL;
  v_gastos DECIMAL;
  v_difference DECIMAL;
BEGIN
  -- Obtener sesión
  SELECT * INTO v_session FROM public.cash_sessions WHERE id = p_session_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Sesión no encontrada', 'code', 'SESSION_NOT_FOUND');
  END IF;
  
  IF v_session.status = 'closed' THEN
    RETURN json_build_object('success', false, 'error', 'La caja ya está cerrada', 'code', 'ALREADY_CLOSED');
  END IF;
  
  -- Calcular ingresos
  SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
  FROM public.cash_movements
  WHERE session_id = p_session_id AND movement_type = 'ingreso';
  
  -- Calcular gastos
  SELECT COALESCE(SUM(amount), 0) INTO v_gastos
  FROM public.cash_movements
  WHERE session_id = p_session_id AND movement_type = 'gasto';
  
  -- Fórmula de conciliación
  v_expected := v_session.opening_balance + v_ingresos - v_gastos;
  v_difference := v_expected - p_actual_balance;
  
  -- Cerrar sesión
  UPDATE public.cash_sessions
  SET 
    closed_by = p_employee_id,
    expected_balance = v_expected,
    actual_balance = p_actual_balance,
    difference = v_difference,
    status = 'closed',
    closed_at = now()
  WHERE id = p_session_id;
  
  RETURN json_build_object(
    'success', true,
    'expected_balance', v_expected,
    'actual_balance', p_actual_balance,
    'difference', v_difference
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FIN MÓDULO: CONTROL DE CAJA (FRD_004)
-- =============================================

-- =============================================
-- MÓDULO: SEGURIDAD DIARIA (FRD_001)
-- =============================================

-- Tabla: daily_passes
-- FRD: FRD_001_SEGURIDAD_DIARIA.md
-- Entidad: Pase Diario
CREATE TABLE IF NOT EXISTS public.daily_passes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  pass_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
  device_fingerprint TEXT, -- Identificador informativo del dispositivo
  retry_count INTEGER DEFAULT 0 CHECK (retry_count >= 0 AND retry_count <= 3),
  requested_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES public.employees(id), -- Admin que resolvió
  
  -- Un empleado solo puede tener un pase pendiente/aprobado por día
  UNIQUE (employee_id, pass_date)
);

-- Índices para daily_passes
CREATE INDEX IF NOT EXISTS idx_daily_passes_employee ON public.daily_passes(employee_id);
CREATE INDEX IF NOT EXISTS idx_daily_passes_status ON public.daily_passes(status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_daily_passes_date ON public.daily_passes(pass_date);

-- RLS para daily_passes
ALTER TABLE public.daily_passes ENABLE ROW LEVEL SECURITY;

-- SELECT: Empleados ven solo sus pases, Admin ve todos de la tienda
CREATE POLICY "daily_passes_select_store" ON public.daily_passes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.employees e
      WHERE e.id = employee_id AND e.store_id = get_current_store_id()
    )
  );

CREATE POLICY "daily_passes_insert_own" ON public.daily_passes
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.employees e
      WHERE e.id = employee_id AND e.store_id = get_current_store_id()
    )
  );

CREATE POLICY "daily_passes_update_store" ON public.daily_passes
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.employees e
      WHERE e.id = employee_id AND e.store_id = get_current_store_id()
    )
  );

-- =============================================
-- RPC: Solicitar Pase Diario
-- FRD_001 - Crea solicitud pendiente
-- =============================================
CREATE OR REPLACE FUNCTION public.solicitar_pase_diario(
  p_employee_id UUID,
  p_device_fingerprint TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_existing_pass public.daily_passes%ROWTYPE;
  v_pass_id UUID;
BEGIN
  -- Verificar si ya existe pase para hoy
  SELECT * INTO v_existing_pass
  FROM public.daily_passes
  WHERE employee_id = p_employee_id AND pass_date = CURRENT_DATE;
  
  IF FOUND THEN
    -- Si ya está aprobado, retornar éxito
    IF v_existing_pass.status = 'approved' THEN
      RETURN json_build_object('success', true, 'status', 'approved', 'pass_id', v_existing_pass.id);
    END IF;
    
    -- Si está pendiente, incrementar retry si aplica
    IF v_existing_pass.status = 'pending' THEN
      IF v_existing_pass.retry_count >= 3 THEN
        RETURN json_build_object(
          'success', false,
          'error', 'Límite de intentos alcanzado. Llame al administrador',
          'code', 'MAX_RETRIES'
        );
      END IF;
      
      -- Incrementar retry
      UPDATE public.daily_passes
      SET retry_count = retry_count + 1, device_fingerprint = p_device_fingerprint
      WHERE id = v_existing_pass.id;
      
      RETURN json_build_object('success', true, 'status', 'pending', 'pass_id', v_existing_pass.id, 'retry_count', v_existing_pass.retry_count + 1);
    END IF;
    
    -- Si está rechazado o expirado, no se puede solicitar de nuevo hoy
    RETURN json_build_object('success', false, 'error', 'Pase ya procesado para hoy', 'code', 'ALREADY_PROCESSED');
  END IF;
  
  -- Crear nuevo pase
  INSERT INTO public.daily_passes (employee_id, device_fingerprint)
  VALUES (p_employee_id, p_device_fingerprint)
  RETURNING id INTO v_pass_id;
  
  RETURN json_build_object('success', true, 'status', 'pending', 'pass_id', v_pass_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- RPC: Aprobar Pase Diario (Solo Admin)
-- FRD_001 - Cambia status a approved
-- =============================================
CREATE OR REPLACE FUNCTION public.aprobar_pase_diario(
  p_pass_id UUID,
  p_admin_id UUID
)
RETURNS JSON AS $$
BEGIN
  UPDATE public.daily_passes
  SET status = 'approved', resolved_at = now(), resolved_by = p_admin_id
  WHERE id = p_pass_id AND status = 'pending';
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Pase no encontrado o ya procesado', 'code', 'NOT_FOUND');
  END IF;
  
  RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Trigger: Expirar pases al cerrar caja
-- FRD_001 - Al cerrar caja, todos los pases expiran
-- =============================================
CREATE OR REPLACE FUNCTION public.expire_daily_passes()
RETURNS TRIGGER AS $$
BEGIN
  -- Cuando una sesión de caja se cierra, expirar todos los pases aprobados de esa tienda
  IF NEW.status = 'closed' AND OLD.status = 'open' THEN
    UPDATE public.daily_passes dp
    SET status = 'expired'
    FROM public.employees e
    WHERE dp.employee_id = e.id
      AND e.store_id = NEW.store_id
      AND dp.status = 'approved'
      AND dp.pass_date = CURRENT_DATE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_expire_passes_on_cash_close
  AFTER UPDATE ON public.cash_sessions
  FOR EACH ROW EXECUTE FUNCTION public.expire_daily_passes();

-- =============================================
-- FIN MÓDULO: SEGURIDAD DIARIA (FRD_001)
-- =============================================

-- =============================================
-- MÓDULO: AUDITORÍA (QA_ADDENDUM §4.3)
-- =============================================

-- Tabla: audit_logs (IMMUTABLE)
-- Doc: QA_ADDENDUM_DATA_MODEL.md §4.3
-- Entidad: Log de Seguridad
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- login_success, login_failed, pin_change, etc.
  severity TEXT NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  actor_id UUID, -- Puede ser NULL para eventos de sistema
  actor_role TEXT CHECK (actor_role IN ('admin', 'employee', 'system')),
  metadata JSONB DEFAULT '{}' NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  
  -- Campos de auditoría (QA_ADDENDUM §4.2 - IMMUTABLE)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para audit_logs
CREATE INDEX IF NOT EXISTS idx_audit_logs_store ON public.audit_logs(store_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_type ON public.audit_logs(store_id, event_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_severity ON public.audit_logs(store_id, severity) WHERE severity IN ('warning', 'critical');
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON public.audit_logs(actor_id) WHERE actor_id IS NOT NULL;

-- RLS para audit_logs (IMMUTABLE, solo Admin puede leer)
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Solo Admin puede leer logs de su tienda
CREATE POLICY "audit_logs_select_admin" ON public.audit_logs
  FOR SELECT USING (
    store_id = get_current_store_id() 
    AND is_admin()
  );

-- Solo via RPC puede insertar (SECURITY DEFINER)
CREATE POLICY "audit_logs_insert_system" ON public.audit_logs
  FOR INSERT WITH CHECK (store_id = get_current_store_id());

-- =============================================
-- RPC: Log de Evento de Seguridad
-- QA_ADDENDUM §4.3 - Registro automático
-- =============================================
CREATE OR REPLACE FUNCTION public.log_security_event(
  p_store_id UUID,
  p_event_type TEXT,
  p_severity TEXT DEFAULT 'info',
  p_actor_id UUID DEFAULT NULL,
  p_actor_role TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO public.audit_logs (
    store_id, event_type, severity, actor_id, actor_role, metadata
  )
  VALUES (
    p_store_id, p_event_type, p_severity, p_actor_id, p_actor_role, p_metadata
  )
  RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- Integración: Logging automático en login
-- =============================================
-- Modificar validar_pin_empleado para registrar logs
CREATE OR REPLACE FUNCTION public.validar_pin_empleado(
  p_username TEXT,
  p_pin TEXT
)
RETURNS JSON AS $$
DECLARE
  v_employee public.employees%ROWTYPE;
  v_store public.stores%ROWTYPE;
BEGIN
  -- Buscar empleado por username
  SELECT * INTO v_employee
  FROM public.employees
  WHERE username = p_username AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Usuario no encontrado', 'code', 'USER_NOT_FOUND');
  END IF;
  
  -- Validar PIN
  IF v_employee.pin_hash != crypt(p_pin, v_employee.pin_hash) THEN
    -- Registrar intento fallido
    PERFORM public.log_security_event(
      v_employee.store_id,
      'login_failed',
      'warning',
      v_employee.id,
      'employee',
      json_build_object('username', p_username)::jsonb
    );
    
    RETURN json_build_object('success', false, 'error', 'PIN incorrecto', 'code', 'INVALID_PIN');
  END IF;
  
  -- Obtener estado de la tienda
  SELECT * INTO v_store FROM public.stores WHERE id = v_employee.store_id;
  
  -- Registrar login exitoso
  PERFORM public.log_security_event(
    v_employee.store_id,
    'login_success',
    'info',
    v_employee.id,
    'employee',
    json_build_object('username', p_username)::jsonb
  );
  
  -- Retornar datos del empleado (sin pin_hash)
  RETURN json_build_object(
    'success', true,
    'employee', json_build_object(
      'id', v_employee.id,
      'username', v_employee.username,
      'display_name', v_employee.display_name,
      'role', v_employee.role,
      'permissions', v_employee.permissions
    ),
    'store_state', json_build_object(
      'is_open', NOT v_store.is_temporarily_closed
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- FIN MÓDULO: AUDITORÍA (QA_ADDENDUM §4.3)
-- =============================================

-- =============================================
-- MÓDULO: HISTORIAL DE PRECIOS (FRD_010)
-- =============================================

-- Tabla: price_change_logs (IMMUTABLE)
-- FRD: FRD_010_HISTORIAL_PRECIOS.md
-- Entidad: Log de Cambios de Precio
CREATE TABLE IF NOT EXISTS public.price_change_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  previous_price DECIMAL(12,0) NOT NULL,
  new_price DECIMAL(12,0) NOT NULL,
  changed_by UUID REFERENCES public.employees(id), -- Puede ser NULL si trigger
  reason TEXT, -- Opcional, max 200 chars
  
  -- Campos de auditoría (IMMUTABLE)
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para price_change_logs (FRD_010: productId + changedAt DESC)
CREATE INDEX IF NOT EXISTS idx_price_logs_product ON public.price_change_logs(product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_price_logs_created ON public.price_change_logs(created_at);

-- RLS para price_change_logs (solo usuarios con canViewInventory)
ALTER TABLE public.price_change_logs ENABLE ROW LEVEL SECURITY;

-- SELECT para empleados con permiso inventario
CREATE POLICY "price_logs_select_inventory" ON public.price_change_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = product_id AND p.store_id = get_current_store_id()
    )
    AND (
      is_admin() OR 
      EXISTS (
        SELECT 1 FROM public.employees e 
        WHERE e.id = get_current_employee_id() 
        AND (e.permissions->>'canViewInventory')::boolean = true
      )
    )
  );

-- INSERT solo via trigger
CREATE POLICY "price_logs_insert_system" ON public.price_change_logs
  FOR INSERT WITH CHECK (true); -- Controlado por trigger SECURITY DEFINER

-- =============================================
-- Trigger: Registro automático de cambios de precio
-- FRD_010 - RN-010-01: Registro Automático
-- =============================================
CREATE OR REPLACE FUNCTION public.log_price_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Solo registrar si el precio realmente cambió
  IF OLD.price IS DISTINCT FROM NEW.price THEN
    INSERT INTO public.price_change_logs (product_id, previous_price, new_price)
    VALUES (NEW.id, COALESCE(OLD.price, 0), NEW.price);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_log_price_change
  AFTER UPDATE OF price ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.log_price_change();

-- =============================================
-- FIN MÓDULO: HISTORIAL DE PRECIOS (FRD_010)
-- =============================================

-- =============================================
-- MÓDULO: SINCRONIZACIÓN OFFLINE (FRD_012)
-- =============================================

-- Tabla: sync_queue
-- Para ventas creadas offline pendientes de sincronización
CREATE TABLE IF NOT EXISTS public.sync_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL, -- 'sale', 'inventory_movement', etc.
  entity_id UUID NOT NULL,   -- ID local del registro
  payload JSONB NOT NULL,    -- Datos a sincronizar
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'syncing', 'synced', 'failed')),
  retry_count INTEGER DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  synced_at TIMESTAMPTZ
);

-- Índices para sync_queue
CREATE INDEX IF NOT EXISTS idx_sync_queue_store ON public.sync_queue(store_id);
CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON public.sync_queue(status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_sync_queue_created ON public.sync_queue(created_at);

-- RLS para sync_queue
ALTER TABLE public.sync_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sync_queue_select_store" ON public.sync_queue
  FOR SELECT USING (store_id = get_current_store_id());

CREATE POLICY "sync_queue_insert_store" ON public.sync_queue
  FOR INSERT WITH CHECK (store_id = get_current_store_id());

CREATE POLICY "sync_queue_update_store" ON public.sync_queue
  FOR UPDATE USING (store_id = get_current_store_id());

-- =============================================
-- FIN MÓDULO: SINCRONIZACIÓN (FRD_012)
-- =============================================

-- =============================================
-- MÓDULO: REPORTES DIARIOS (FRD_008)
-- =============================================

-- Tabla: daily_reports (Cierres de día consolidados)
CREATE TABLE IF NOT EXISTS public.daily_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  report_date DATE NOT NULL,
  
  -- Métricas de ventas
  total_sales DECIMAL(12,0) DEFAULT 0,
  total_transactions INTEGER DEFAULT 0,
  average_ticket DECIMAL(12,0) DEFAULT 0,
  
  -- Desglose por método de pago
  cash_sales DECIMAL(12,0) DEFAULT 0,
  digital_sales DECIMAL(12,0) DEFAULT 0,
  credit_sales DECIMAL(12,0) DEFAULT 0,
  
  -- Métricas de caja
  opening_balance DECIMAL(12,0),
  closing_balance DECIMAL(12,0),
  difference DECIMAL(12,0),
  
  -- Inventario
  products_sold INTEGER DEFAULT 0,
  low_stock_alerts INTEGER DEFAULT 0,
  
  -- Auditoría
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  
  UNIQUE (store_id, report_date)
);

-- Índices para daily_reports
CREATE INDEX IF NOT EXISTS idx_daily_reports_store ON public.daily_reports(store_id);
CREATE INDEX IF NOT EXISTS idx_daily_reports_date ON public.daily_reports(store_id, report_date DESC);

-- RLS para daily_reports
ALTER TABLE public.daily_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "daily_reports_select_admin" ON public.daily_reports
  FOR SELECT USING (store_id = get_current_store_id() AND is_admin());

CREATE POLICY "daily_reports_insert_system" ON public.daily_reports
  FOR INSERT WITH CHECK (store_id = get_current_store_id());

-- =============================================
-- FIN MÓDULO: REPORTES DIARIOS (FRD_008)
-- =============================================

-- =============================================
-- MÓDULO: ERROR LOGS (Manejo de Errores)
-- =============================================

-- Tabla: error_logs (Frontend error tracking)
CREATE TABLE IF NOT EXISTS public.error_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE,
  error_type TEXT NOT NULL,
  error_message TEXT NOT NULL,
  stack_trace TEXT,
  context JSONB DEFAULT '{}',
  user_id UUID,
  user_role TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para error_logs
CREATE INDEX IF NOT EXISTS idx_error_logs_store ON public.error_logs(store_id) WHERE store_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_error_logs_type ON public.error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_error_logs_created ON public.error_logs(created_at);

-- RLS para error_logs (INSERT público, SELECT solo Admin)
ALTER TABLE public.error_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "error_logs_insert_public" ON public.error_logs
  FOR INSERT WITH CHECK (true); -- Permitir logs de errores incluso sin auth

CREATE POLICY "error_logs_select_admin" ON public.error_logs
  FOR SELECT USING (
    (store_id IS NULL) OR 
    (store_id = get_current_store_id() AND is_admin())
  );

-- =============================================
-- FIN MÓDULO: ERROR LOGS
-- =============================================

-- =============================================
-- FUNCIONES HELPER FINALES
-- =============================================

-- Función helper: Obtener empleado actual
CREATE OR REPLACE FUNCTION public.get_current_employee_id()
RETURNS UUID AS $$
BEGIN
  RETURN (current_setting('app.employee_id', true))::UUID;
EXCEPTION
  WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- Función helper: Verificar si es admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  -- El admin usa auth.users, verificar si hay jwt de tipo admin
  RETURN (current_setting('app.user_role', true) = 'admin');
EXCEPTION
  WHEN OTHERS THEN RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================
-- FIN: MODELO DE DATOS COMPLETO
-- Tablas: 17
-- RPCs: 10+
-- Triggers: 6
-- =============================================
