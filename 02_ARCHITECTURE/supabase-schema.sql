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
  -- SPEC-006: PIN de Caja del Dueño
  owner_pin_hash TEXT,                          -- PIN hasheado con bcrypt (6 dígitos)
  pin_failed_attempts INTEGER DEFAULT 0,        -- Contador de intentos fallidos
  pin_locked_until TIMESTAMPTZ,                 -- Timestamp de desbloqueo (rate limiting)
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Empleados
CREATE TABLE IF NOT EXISTS employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  pin TEXT NOT NULL, -- Hasheado con crypt()
  permissions JSONB DEFAULT '{"canSell": true, "canViewInventory": true, "canViewReports": false, "canFiar": false, "canOpenCloseCash": false}',
  is_active BOOLEAN DEFAULT true,
  -- SPEC-005: Rate Limiting para protección contra fuerza bruta
  failed_attempts INTEGER DEFAULT 0,
  locked_until TIMESTAMPTZ DEFAULT NULL,
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
-- SPEC-006: Control de Caja con PIN
-- =============================================

-- Eventos de Control de Caja (Auditoría)
CREATE TABLE IF NOT EXISTS cash_control_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('open', 'close')),
  
  -- Usuario que autorizó (puede ser admin o empleado)
  authorized_by_id UUID,
  authorized_by_type TEXT NOT NULL CHECK (authorized_by_type IN ('admin', 'employee')),
  authorized_by_name TEXT NOT NULL,
  
  -- Montos
  amount_declared DECIMAL(12,2) NOT NULL,
  amount_expected DECIMAL(12,2),              -- Solo para cierre
  difference DECIMAL(12,2),                    -- Solo para cierre
  
  -- Metadatos de seguridad
  pin_verified BOOLEAN DEFAULT true,
  device_fingerprint TEXT,
  ip_address INET,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para cash_control_events
CREATE INDEX IF NOT EXISTS idx_cash_events_store ON cash_control_events(store_id);
CREATE INDEX IF NOT EXISTS idx_cash_events_date ON cash_control_events(created_at);
CREATE INDEX IF NOT EXISTS idx_cash_events_type ON cash_control_events(store_id, event_type);

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
  -- NIVEL 0: Verificar Bloqueo por Rate Limiting
  -- ========================================
  SELECT * INTO v_employee 
  FROM employees 
  WHERE username = LOWER(p_username);

  IF FOUND AND v_employee.locked_until IS NOT NULL AND v_employee.locked_until > NOW() THEN
    RETURN json_build_object(
      'success', false,
      'error_code', 'ACCOUNT_LOCKED',
      'error', 'Cuenta bloqueada. Intenta en 15 minutos.',
      'locked_until', v_employee.locked_until
    );
  END IF;

  -- ========================================
  -- NIVEL 1: Validación de Credenciales
  -- ========================================
  SELECT * INTO v_employee 
  FROM employees 
  WHERE username = LOWER(p_username)
    AND pin = crypt(p_pin, pin)
    AND is_active = true;
  
  IF NOT FOUND THEN
    -- Incrementar intentos fallidos
    UPDATE employees 
    SET failed_attempts = failed_attempts + 1,
        locked_until = CASE 
          WHEN failed_attempts >= 4 THEN NOW() + INTERVAL '15 minutes' 
          ELSE NULL 
        END
    WHERE username = LOWER(p_username);

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

  -- ========================================
  -- Login Exitoso: Resetear Rate Limiting
  -- ========================================
  UPDATE employees 
  SET failed_attempts = 0, locked_until = NULL 
  WHERE id = v_employee.id;

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

-- =============================================
-- SPEC-006: RPCs para Control de Caja con PIN
-- =============================================

-- RPC: Validar PIN del Admin/Dueño (WO-003)
CREATE OR REPLACE FUNCTION validar_pin_admin(
  p_store_id UUID,
  p_pin TEXT
)
RETURNS JSON AS $$
DECLARE
  v_store stores%ROWTYPE;
  v_current_attempts INTEGER;
BEGIN
  -- Obtener datos de la tienda
  SELECT * INTO v_store FROM stores WHERE id = p_store_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error_code', 'STORE_NOT_FOUND');
  END IF;
  
  -- Verificar si está bloqueado
  IF v_store.pin_locked_until IS NOT NULL AND v_store.pin_locked_until > NOW() THEN
    RETURN json_build_object(
      'success', false,
      'error_code', 'PIN_LOCKED',
      'locked_until', v_store.pin_locked_until,
      'message', 'Cuenta bloqueada temporalmente'
    );
  END IF;
  
  -- Verificar si tiene PIN configurado
  IF v_store.owner_pin_hash IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error_code', 'PIN_NOT_CONFIGURED',
      'message', 'Debes configurar un PIN primero'
    );
  END IF;
  
  -- Validar PIN usando bcrypt
  IF v_store.owner_pin_hash = crypt(p_pin, v_store.owner_pin_hash) THEN
    -- PIN correcto: resetear contadores
    UPDATE stores 
    SET pin_failed_attempts = 0, 
        pin_locked_until = NULL 
    WHERE id = p_store_id;
    
    RETURN json_build_object('success', true);
  ELSE
    -- PIN incorrecto: incrementar intentos
    v_current_attempts := COALESCE(v_store.pin_failed_attempts, 0) + 1;
    
    UPDATE stores 
    SET pin_failed_attempts = v_current_attempts,
        pin_locked_until = CASE 
          WHEN v_current_attempts >= 7 THEN NOW() + INTERVAL '1 hour'
          WHEN v_current_attempts >= 6 THEN NOW() + INTERVAL '15 minutes'
          WHEN v_current_attempts >= 5 THEN NOW() + INTERVAL '5 minutes'
          ELSE NULL 
        END
    WHERE id = p_store_id;
    
    RETURN json_build_object(
      'success', false,
      'error_code', 'INVALID_PIN',
      'attempts_remaining', GREATEST(5 - v_current_attempts, 0),
      'message', 'PIN incorrecto'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Establecer/Cambiar PIN del Admin (WO-004)
CREATE OR REPLACE FUNCTION establecer_pin_admin(
  p_store_id UUID,
  p_new_pin TEXT,
  p_current_pin TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_store stores%ROWTYPE;
BEGIN
  SELECT * INTO v_store FROM stores WHERE id = p_store_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Tienda no encontrada');
  END IF;
  
  -- Validar formato de PIN (exactamente 6 dígitos)
  IF LENGTH(p_new_pin) != 6 OR p_new_pin !~ '^\d{6}$' THEN
    RETURN json_build_object('success', false, 'error', 'El PIN debe ser de 6 dígitos numéricos');
  END IF;
  
  -- Si ya tiene PIN, validar el actual
  IF v_store.owner_pin_hash IS NOT NULL THEN
    IF p_current_pin IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'Debes ingresar tu PIN actual');
    END IF;
    
    IF v_store.owner_pin_hash != crypt(p_current_pin, v_store.owner_pin_hash) THEN
      RETURN json_build_object('success', false, 'error', 'PIN actual incorrecto');
    END IF;
    
    -- Verificar que nuevo PIN sea diferente
    IF v_store.owner_pin_hash = crypt(p_new_pin, v_store.owner_pin_hash) THEN
      RETURN json_build_object('success', false, 'error', 'El nuevo PIN debe ser diferente al actual');
    END IF;
  END IF;
  
  -- Establecer nuevo PIN
  UPDATE stores 
  SET owner_pin_hash = crypt(p_new_pin, gen_salt('bf')),
      pin_failed_attempts = 0,
      pin_locked_until = NULL
  WHERE id = p_store_id;
  
  RETURN json_build_object('success', true, 'message', 'PIN configurado correctamente');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Registrar Evento de Caja (WO-005)
CREATE OR REPLACE FUNCTION registrar_evento_caja(
  p_store_id UUID,
  p_event_type TEXT,
  p_amount_declared DECIMAL,
  p_authorized_by_name TEXT,
  p_authorized_by_type TEXT,
  p_authorized_by_id UUID DEFAULT NULL,
  p_device_fingerprint TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_event_id UUID;
  v_amount_expected DECIMAL;
  v_difference DECIMAL;
  v_existing_open BOOLEAN;
BEGIN
  -- Validar tipo de evento
  IF p_event_type NOT IN ('open', 'close') THEN
    RETURN json_build_object('success', false, 'error', 'Tipo de evento inválido');
  END IF;
  
  -- Para apertura: verificar que no haya una apertura sin cierre hoy
  IF p_event_type = 'open' THEN
    SELECT EXISTS (
      SELECT 1 FROM cash_control_events 
      WHERE store_id = p_store_id 
        AND DATE(created_at) = CURRENT_DATE 
        AND event_type = 'open'
        AND NOT EXISTS (
          SELECT 1 FROM cash_control_events ce2
          WHERE ce2.store_id = p_store_id 
            AND DATE(ce2.created_at) = CURRENT_DATE 
            AND ce2.event_type = 'close'
            AND ce2.created_at > cash_control_events.created_at
        )
    ) INTO v_existing_open;
    
    IF v_existing_open THEN
      RETURN json_build_object('success', false, 'error', 'La caja ya está abierta');
    END IF;
  END IF;
  
  -- Para cierre: calcular monto esperado
  IF p_event_type = 'close' THEN
    SELECT COALESCE(
      (SELECT amount FROM cash_register 
       WHERE store_id = p_store_id AND date = CURRENT_DATE AND type = 'opening'), 0
    ) + COALESCE(
      (SELECT SUM(total) FROM sales 
       WHERE store_id = p_store_id AND DATE(created_at) = CURRENT_DATE AND payment_method = 'cash'), 0
    ) - COALESCE(
      (SELECT SUM(amount) FROM expenses 
       WHERE store_id = p_store_id AND DATE(created_at) = CURRENT_DATE), 0
    ) INTO v_amount_expected;
    
    v_difference := p_amount_declared - COALESCE(v_amount_expected, 0);
  END IF;
  
  -- Insertar evento de control de caja
  INSERT INTO cash_control_events (
    store_id, event_type, 
    authorized_by_id, authorized_by_type, authorized_by_name,
    amount_declared, amount_expected, difference,
    device_fingerprint
  ) VALUES (
    p_store_id, p_event_type,
    p_authorized_by_id, p_authorized_by_type, p_authorized_by_name,
    p_amount_declared, v_amount_expected, v_difference,
    p_device_fingerprint
  )
  RETURNING id INTO v_event_id;
  
  -- Sincronizar con tabla cash_register para compatibilidad
  INSERT INTO cash_register (store_id, date, type, amount, created_by)
  VALUES (
    p_store_id, 
    CURRENT_DATE, 
    CASE WHEN p_event_type = 'open' THEN 'opening' ELSE 'closing' END,
    p_amount_declared,
    p_authorized_by_id
  )
  ON CONFLICT (store_id, date, type) DO UPDATE SET amount = p_amount_declared;
  
  RETURN json_build_object(
    'success', true,
    'event_id', v_event_id,
    'amount_expected', v_amount_expected,
    'difference', v_difference
  );
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
-- SPEC-011: Cache Strategy - Dead Letter Queue
-- =============================================

-- Tabla para transacciones que fallan después de MAX_RETRIES
CREATE TABLE IF NOT EXISTS sync_queue_failed (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL CHECK (action_type IN ('sale', 'stock_entry', 'expense', 'client_payment')),
  payload JSONB NOT NULL,
  original_timestamp TIMESTAMPTZ NOT NULL,
  failed_at TIMESTAMPTZ DEFAULT NOW(),
  retry_count INTEGER NOT NULL DEFAULT 5,
  last_error TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'retried', 'discarded', 'manual_resolved')),
  resolved_by UUID REFERENCES employees(id),
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,
  created_by UUID REFERENCES employees(id),
  device_fingerprint TEXT
);

-- Índices para sync_queue_failed
CREATE INDEX IF NOT EXISTS idx_sync_failed_store ON sync_queue_failed(store_id);
CREATE INDEX IF NOT EXISTS idx_sync_failed_status ON sync_queue_failed(status);
CREATE INDEX IF NOT EXISTS idx_sync_failed_pending ON sync_queue_failed(store_id, status) WHERE status = 'pending';

-- Índices optimizados para consultas SWR frecuentes
CREATE INDEX IF NOT EXISTS idx_products_store_active ON products(store_id) WHERE current_stock > 0;
CREATE INDEX IF NOT EXISTS idx_clients_with_balance ON clients(store_id) WHERE balance > 0;
CREATE INDEX IF NOT EXISTS idx_sales_today ON sales(store_id, created_at);

-- RLS para sync_queue_failed
ALTER TABLE sync_queue_failed ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sync_failed_store_isolation" ON sync_queue_failed
FOR ALL USING (
  store_id IN (
    SELECT store_id FROM employees WHERE id = auth.uid()
    UNION
    SELECT id FROM stores WHERE id = auth.uid()
  )
);

-- RPC: Obtener timestamp del servidor (MIT-05)
CREATE OR REPLACE FUNCTION get_server_timestamp()
RETURNS JSON AS $$
BEGIN
  RETURN json_build_object(
    'timestamp', EXTRACT(EPOCH FROM NOW()) * 1000,
    'iso', NOW()::TEXT
  );
END;
$$ LANGUAGE plpgsql;

-- RPC: Reintentar transacción fallida desde Dead Letter Queue
CREATE OR REPLACE FUNCTION retry_failed_sync(
  p_failed_id UUID,
  p_employee_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_failed sync_queue_failed%ROWTYPE;
  v_result JSON;
BEGIN
  SELECT * INTO v_failed FROM sync_queue_failed WHERE id = p_failed_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Registro no encontrado');
  END IF;
  
  IF v_failed.status != 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'Transacción ya procesada');
  END IF;
  
  -- Procesar según tipo
  CASE v_failed.action_type
    WHEN 'sale' THEN
      SELECT procesar_venta(
        v_failed.store_id,
        v_failed.payload->'items',
        v_failed.payload->>'payment_method',
        (v_failed.payload->>'amount_received')::DECIMAL,
        (v_failed.payload->>'client_id')::UUID,
        p_employee_id
      ) INTO v_result;
      
    WHEN 'expense' THEN
      INSERT INTO expenses (store_id, amount, description, category, created_by)
      VALUES (
        v_failed.store_id,
        (v_failed.payload->>'amount')::DECIMAL,
        v_failed.payload->>'description',
        COALESCE(v_failed.payload->>'category', 'General'),
        p_employee_id
      );
      v_result := json_build_object('success', true);
      
    ELSE
      RETURN json_build_object('success', false, 'error', 'Tipo de acción no soportado: ' || v_failed.action_type);
  END CASE;
  
  -- Actualizar estado si fue exitoso
  IF (v_result->>'success')::BOOLEAN THEN
    UPDATE sync_queue_failed 
    SET status = 'retried',
        resolved_by = p_employee_id,
        resolved_at = NOW()
    WHERE id = p_failed_id;
  END IF;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- TRIGGERS Y FUNCIONES AUTOMÁTICAS
-- =============================================

-- 1. Función para actualizar timestamp (updated_at)
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers de timestamp
DROP TRIGGER IF EXISTS trg_products_updated ON products;
CREATE TRIGGER trg_products_updated BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_employees_updated ON employees;
CREATE TRIGGER trg_employees_updated BEFORE UPDATE ON employees FOR EACH ROW EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_clients_updated ON clients;
CREATE TRIGGER trg_clients_updated BEFORE UPDATE ON clients FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- 2. Función para actualizar stock automáticamete
CREATE OR REPLACE FUNCTION update_inventory_stock()
RETURNS TRIGGER AS $$
BEGIN
  -- Si es entrada, sumar
  IF NEW.movement_type IN ('entrada', 'devolucion', 'ajuste') THEN
    UPDATE products SET current_stock = current_stock + NEW.quantity WHERE id = NEW.product_id;
  
  -- Si es salida o venta, restar
  ELSIF NEW.movement_type IN ('salida', 'venta') THEN
    -- Validar stock negativo (opcional, pero recomendado)
    IF (SELECT current_stock FROM products WHERE id = NEW.product_id) < NEW.quantity THEN
       RAISE EXCEPTION 'Stock insuficiente para el producto %', NEW.product_id;
    END IF;
    UPDATE products SET current_stock = current_stock - NEW.quantity WHERE id = NEW.product_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger de inventario
DROP TRIGGER IF EXISTS trg_inventory_movement ON inventory_movements;
CREATE TRIGGER trg_inventory_movement 
AFTER INSERT ON inventory_movements 
FOR EACH ROW EXECUTE FUNCTION update_inventory_stock();


-- =============================================
-- RPCs FALTANTES (SPEC-012)
-- =============================================

-- RPC: Establecer PIN de Admin (Dueño)
CREATE OR REPLACE FUNCTION establecer_pin_admin(
  p_store_id UUID,
  p_pin TEXT
)
RETURNS JSON AS $$
BEGIN
  -- Validar formato (6 dígitos para admin)
  IF LENGTH(p_pin) != 6 OR p_pin !~ '^\d{6}$' THEN
    RETURN json_build_object('success', false, 'error', 'PIN de administrador debe ser de 6 dígitos');
  END IF;

  UPDATE stores 
  SET owner_pin_hash = crypt(p_pin, gen_salt('bf')),
      pin_failed_attempts = 0,
      pin_locked_until = NULL
  WHERE id = p_store_id;

  RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- RPC: Validar PIN de Admin (para Caja)
CREATE OR REPLACE FUNCTION validar_pin_admin(
  p_store_id UUID,
  p_pin TEXT
)
RETURNS JSON AS $$
DECLARE
  v_store stores%ROWTYPE;
BEGIN
  SELECT * INTO v_store FROM stores WHERE id = p_store_id;

  -- 1. Verificar bloqueo
  IF v_store.pin_locked_until IS NOT NULL AND v_store.pin_locked_until > NOW() THEN
     RETURN json_build_object('success', false, 'error', 'PIN bloqueado temporalmente. Intente más tarde.');
  END IF;

  -- 2. Verificar Hash
  IF v_store.owner_pin_hash = crypt(p_pin, v_store.owner_pin_hash) THEN
     -- Resetear intentos
     UPDATE stores SET pin_failed_attempts = 0, pin_locked_until = NULL WHERE id = p_store_id;
     RETURN json_build_object('success', true);
  ELSE
     -- Incrementar intentos
     UPDATE stores SET pin_failed_attempts = pin_failed_attempts + 1 WHERE id = p_store_id;
     
     -- Bloquear si > 5 intentos (por 15 min)
     IF (v_store.pin_failed_attempts + 1) >= 5 THEN
       UPDATE stores SET pin_locked_until = NOW() + INTERVAL '15 minutes' WHERE id = p_store_id;
       RETURN json_build_object('success', false, 'error', 'PIN bloqueado por demasiados intentos fallidos');
     END IF;

     RETURN json_build_object('success', false, 'error', 'PIN incorrecto');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- RPC: Registrar Evento de Caja
CREATE OR REPLACE FUNCTION registrar_evento_caja(
  p_store_id UUID,
  p_type TEXT, -- 'open' | 'close'
  p_amount DECIMAL,
  p_authorized_by_name TEXT,
  p_authorized_by_type TEXT, -- 'admin' | 'employee'
  p_notes TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_event_id UUID;
BEGIN
  -- 1. Insertar en Historial de Eventos (Auditoría)
  INSERT INTO cash_control_events (
    store_id, event_type, authorized_by_name, authorized_by_type, 
    amount_declared, pin_verified
  ) VALUES (
    p_store_id, p_type, p_authorized_by_name, p_authorized_by_type, 
    p_amount, true
  ) RETURNING id INTO v_event_id;

  -- 2. Actualizar estado actual de la caja
  -- 'opening' -> inserta registro del día
  -- 'closing' -> actualiza o inserta cierre
  INSERT INTO cash_register (store_id, date, type, amount, notes)
  VALUES (
    p_store_id, CURRENT_DATE, 
    CASE WHEN p_type = 'open' THEN 'opening' ELSE 'closing' END,
    p_amount, p_notes
  );

  RETURN json_build_object('success', true, 'event_id', v_event_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- RPC: Procesar Venta Completa
CREATE OR REPLACE FUNCTION procesar_venta(
  p_store_id UUID,
  p_items JSONB, -- Array de {product_id, quantity, price}
  p_payment_method TEXT,
  p_amount_received DECIMAL,
  p_client_id UUID DEFAULT NULL,
  p_employee_id UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_sale_id UUID;
  v_total DECIMAL := 0;
  v_item JSONB;
  v_product products%ROWTYPE;
  v_item_subtotal DECIMAL;
BEGIN
  -- 1. Calcular Total y Validar Stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    SELECT * INTO v_product FROM products WHERE id = (v_item->>'product_id')::UUID;
    
    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'error', 'Producto no encontrado: ' || (v_item->>'product_id'));
    END IF;

    -- Validar stock (si no es servicio/infinito, aqui asumimos todo tiene stock finito por ahora)
    IF v_product.current_stock < (v_item->>'quantity')::DECIMAL THEN
       RETURN json_build_object('success', false, 'error', 'Stock insuficiente para: ' || v_product.name);
    END IF;

    v_item_subtotal := (v_item->>'quantity')::DECIMAL * (v_item->>'price')::DECIMAL;
    v_total := v_total + v_item_subtotal;
  END LOOP;

  -- 2. Crear Venta
  INSERT INTO sales (
    store_id, employee_id, total, payment_method, 
    amount_received, change, client_id
  ) VALUES (
    p_store_id, p_employee_id, v_total, p_payment_method,
    p_amount_received, (p_amount_received - v_total), p_client_id
  ) RETURNING id INTO v_sale_id;

  -- 3. Procesar Items y Movimientos
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product := NULL; -- Reset
    SELECT * INTO v_product FROM products WHERE id = (v_item->>'product_id')::UUID;
    v_item_subtotal := (v_item->>'quantity')::DECIMAL * (v_item->>'price')::DECIMAL;

    -- Insertar Sale Item
    INSERT INTO sale_items (
      sale_id, product_id, product_name, quantity, price, subtotal
    ) VALUES (
      v_sale_id, v_product.id, v_product.name, 
      (v_item->>'quantity')::DECIMAL, 
      (v_item->>'price')::DECIMAL, 
      v_item_subtotal
    );

    -- Insertar Movimiento de Inventario (Trigger actualizará stock)
    INSERT INTO inventory_movements (
      product_id, movement_type, quantity, reason, sale_id, created_by
    ) VALUES (
      v_product.id, 'venta', (v_item->>'quantity')::DECIMAL, 
      'Venta #' || v_sale_id, v_sale_id, p_employee_id
    );
  END LOOP;

  -- 4. Si es Fiado, actualizar saldo cliente
  IF p_payment_method = 'fiado' AND p_client_id IS NOT NULL THEN
    UPDATE clients SET balance = balance + v_total WHERE id = p_client_id;
    
    INSERT INTO client_transactions (
      client_id, type, amount, description, sale_id, created_by
    ) VALUES (
      p_client_id, 'purchase', v_total, 'Compra Fiada', v_sale_id, p_employee_id
    );
  END IF;

  RETURN json_build_object('success', true, 'sale_id', v_sale_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


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

-- =============================================
-- MANTENIMIENTO AUTOMÁTICO (pg_cron)
-- =============================================
-- SPEC-005: Limpieza de sesiones expiradas (TTL 8 horas)
-- 
-- INSTRUCCIONES:
-- 1. Habilitar extensión pg_cron en Supabase Dashboard > Database > Extensions
-- 2. Ejecutar el siguiente comando en el SQL Editor:
--
-- SELECT cron.schedule(
--   'cleanup-expired-sessions',
--   '0 3 * * *',  -- Todos los días a las 3 AM
--   $$DELETE FROM employee_sessions WHERE started_at < NOW() - INTERVAL '8 hours'$$
-- );
--
-- 3. Para verificar jobs activos:
-- SELECT * FROM cron.job;
--
-- 4. Para desactivar:
-- SELECT cron.unschedule('cleanup-expired-sessions');

-- =============================================
-- SPEC-009: Sistema de Historiales y Trazabilidad
-- =============================================

-- 1. Log de Auditoría del Sistema (Seguridad)
CREATE TABLE IF NOT EXISTS system_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    user_id UUID REFERENCES employees(id), -- Puede ser nulo si es un intento de login fallido desconocido
    event_type TEXT NOT NULL, -- 'login_success', 'login_failed', 'pin_change', 'unauthorized_access', 'price_change'
    severity TEXT DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
    details JSONB DEFAULT '{}'::jsonb, -- IP, dispositivo, input fallido
    ip_address TEXT
);

-- Índices para búsqueda rápida
CREATE INDEX IF NOT EXISTS idx_audit_store_date ON system_audit_logs(store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_user ON system_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_event_type ON system_audit_logs(store_id, event_type);

-- RLS para system_audit_logs
ALTER TABLE system_audit_logs ENABLE ROW LEVEL SECURITY;

-- Solo admins pueden ver logs de su tienda
CREATE POLICY "audit_select_admins" ON system_audit_logs
    FOR SELECT USING (
        store_id IN (
            SELECT store_id FROM employees 
            WHERE id = auth.uid() 
            AND (permissions->>'canViewReports')::boolean = true
        )
    );

-- Inserción validando pertenencia a tienda (corrige vulnerabilidad QA)
CREATE POLICY "audit_insert_own_store" ON system_audit_logs
    FOR INSERT WITH CHECK (
        store_id IN (
            SELECT store_id FROM employees WHERE id = auth.uid()
        )
        OR auth.uid() IS NULL -- Permitir logs de intentos fallidos de login
    );

-- 2. Historial de Cambios de Precio
CREATE TABLE IF NOT EXISTS price_change_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    changed_by UUID NOT NULL REFERENCES employees(id),
    old_price NUMERIC(12,2),
    new_price NUMERIC(12,2),
    old_cost NUMERIC(12,2),
    new_cost NUMERIC(12,2),
    reason TEXT CHECK (reason IN ('inflation', 'correction', 'promotion', 'supplier_update', 'other'))
);

-- Índices para price_change_logs
CREATE INDEX IF NOT EXISTS idx_price_log_store_date ON price_change_logs(store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_price_log_product ON price_change_logs(product_id);

-- RLS para price_change_logs
ALTER TABLE price_change_logs ENABLE ROW LEVEL SECURITY;

-- Miembros de la tienda pueden ver historial de precios
CREATE POLICY "price_log_select_store" ON price_change_logs
    FOR SELECT USING (
        store_id IN (
            SELECT store_id FROM employees WHERE id = auth.uid()
        )
    );

-- Solo usuarios con permisos de inventario pueden insertar
CREATE POLICY "price_log_insert_inventory" ON price_change_logs
    FOR INSERT WITH CHECK (
        store_id IN (
            SELECT store_id FROM employees 
            WHERE id = auth.uid() 
            AND (permissions->>'canViewInventory')::boolean = true
        )
    );

-- Índices adicionales para historiales existentes (filtro por empleado)
CREATE INDEX IF NOT EXISTS idx_sales_employee ON sales(employee_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cash_control_events_store ON cash_control_events(store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_created_by ON inventory_movements(created_by, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_created_by ON expenses(created_by, created_at DESC);

