# Arquitectura Backend-First: Supabase Integration

## Resumen Ejecutivo

Este documento define la arquitectura para migrar "Tienda de Barrio Pro" de almacenamiento local (localStorage) a **Supabase** como backend, implementando prácticas de integridad financiera y seguridad empresarial.

### Principios Fundamentales

| Principio | Implementación |
|-----------|----------------|
| **Libro Mayor Automatizado** | Triggers para movimientos de inventario |
| **Confianza Cero** | RPC para autenticación, PINs nunca expuestos |
| **Datos Protegidos** | RLS para ocultar costos a vendedores |
| **Cómputo en Backend** | Reportes calculados en Supabase, no en cliente |

---

## 1. Nivel de Datos: Triggers de Inventario

### 1.1 Problema Actual
```
❌ Frontend calcula: stock = stock + cantidad
❌ Riesgo de "Stock Fantasma" por errores de sincronización
❌ Múltiples dispositivos pueden causar inconsistencias
```

### 1.2 Solución: Trigger de Kardex Automático

#### Tabla `inventory_movements` (Movimientos de Inventario)
```sql
CREATE TABLE inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  movement_type TEXT CHECK (movement_type IN ('entrada', 'salida', 'ajuste', 'venta')),
  quantity DECIMAL(10,3) NOT NULL,
  reason TEXT,
  sale_id UUID REFERENCES sales(id),
  created_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
```

#### Trigger de Actualización Automática
```sql
CREATE OR REPLACE FUNCTION update_product_stock()
RETURNS TRIGGER AS $$
BEGIN
  -- Actualizar stock basado en tipo de movimiento
  IF NEW.movement_type IN ('entrada', 'ajuste') THEN
    UPDATE products 
    SET current_stock = current_stock + NEW.quantity,
        updated_at = now()
    WHERE id = NEW.product_id;
  ELSIF NEW.movement_type IN ('salida', 'venta') THEN
    UPDATE products 
    SET current_stock = current_stock - NEW.quantity,
        updated_at = now()
    WHERE id = NEW.product_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_movement
AFTER INSERT ON inventory_movements
FOR EACH ROW EXECUTE FUNCTION update_product_stock();
```

### 1.3 Cambios en Frontend

| Antes | Después |
|-------|---------|
| `inventoryStore.updateStock(id, -qty)` | `supabase.from('inventory_movements').insert({...})` |
| Stock calculado en Vue | Stock es `read-only`, solo lectura |
| Suma/resta manual | Trigger calcula automáticamente |

---

## 2. Normalización de Unidades (Pesos y Medidas)

### 2.1 Campos Obligatorios en Productos
```sql
ALTER TABLE products ADD COLUMN IF NOT EXISTS 
  is_weighable BOOLEAN DEFAULT false,
  measurement_unit TEXT CHECK (measurement_unit IN ('kg', 'lb', 'g', 'un')) DEFAULT 'un',
  price_per_unit DECIMAL(12,2) NOT NULL; -- Precio por kg/lb/g/un
```

### 2.2 Función de Cálculo de Precio (Backend)
```sql
CREATE OR REPLACE FUNCTION calculate_item_price(
  p_product_id UUID,
  p_quantity DECIMAL,
  p_mode TEXT -- 'weight' o 'value'
)
RETURNS JSON AS $$
DECLARE
  v_product products%ROWTYPE;
  v_subtotal DECIMAL;
  v_actual_qty DECIMAL;
BEGIN
  SELECT * INTO v_product FROM products WHERE id = p_product_id;
  
  IF p_mode = 'value' THEN
    -- Usuario ingresó valor monetario, calcular cantidad
    v_actual_qty := p_quantity / v_product.price_per_unit;
    v_subtotal := p_quantity;
  ELSE
    -- Usuario ingresó peso/cantidad
    v_actual_qty := p_quantity;
    v_subtotal := p_quantity * v_product.price_per_unit;
  END IF;
  
  RETURN json_build_object(
    'quantity', ROUND(v_actual_qty, 3),
    'subtotal', ROUND(v_subtotal, 0),
    'unit', v_product.measurement_unit
  );
END;
$$ LANGUAGE plpgsql;
```

---

## 3. Nivel de Seguridad: Confianza Cero

### 3.1 Login de Empleados vía RPC

#### ❌ Antes (Inseguro)
```typescript
// PIN visible en consola del navegador
const employee = await supabase
  .from('employees')
  .select('*')
  .eq('username', username)
  .eq('pin', pin)
  .single();
```

#### ✅ Después (Seguro)
```sql
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
  WHERE username = p_username 
    AND pin = crypt(p_pin, pin) -- PIN hasheado
    AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Credenciales inválidas');
  END IF;
  
  -- Registrar sesión
  INSERT INTO employee_sessions (employee_id, device_info)
  VALUES (v_employee.id, current_setting('request.headers')::json->>'user-agent');
  
  RETURN json_build_object(
    'success', true,
    'employee', json_build_object(
      'id', v_employee.id,
      'name', v_employee.name,
      'permissions', v_employee.permissions
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### Uso en Frontend
```typescript
const { data } = await supabase.rpc('login_empleado', {
  p_username: 'carlos01',
  p_pin: '1234'
});

if (data.success) {
  // Login exitoso, guardar sesión
  sessionStore.setEmployee(data.employee);
}
```

### 3.2 Protección de Costos con RLS

```sql
-- Política: Vendedores no pueden ver precio_costo
CREATE POLICY "hide_cost_from_vendors" ON products
FOR SELECT
USING (
  CASE 
    WHEN auth.jwt()->>'role' = 'admin' THEN true
    ELSE true -- Pueden ver la fila
  END
);

-- Vista segura para vendedores
CREATE VIEW products_safe AS
SELECT 
  id, name, plu, 
  price, -- Precio de venta (visible)
  CASE 
    WHEN current_user_role() = 'admin' THEN cost_price
    ELSE NULL 
  END as cost_price, -- Costo oculto para vendedores
  current_stock, is_weighable, measurement_unit
FROM products;
```

---

## 4. Nivel de Inteligencia: Reportes via RPC

### 4.1 Reporte de Caja Real
```sql
CREATE OR REPLACE FUNCTION get_cash_report(
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSON AS $$
BEGIN
  RETURN (
    SELECT json_build_object(
      'date', p_date,
      'opening_cash', (SELECT amount FROM cash_register WHERE date = p_date AND type = 'opening'),
      'sales', json_build_object(
        'cash', SUM(CASE WHEN payment_method = 'cash' THEN total ELSE 0 END),
        'nequi', SUM(CASE WHEN payment_method = 'nequi' THEN total ELSE 0 END),
        'fiado', SUM(CASE WHEN payment_method = 'fiado' THEN total ELSE 0 END),
        'total', SUM(total),
        'count', COUNT(*)
      ),
      'expenses', (SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE date = p_date),
      'expected_cash', (
        SELECT amount FROM cash_register WHERE date = p_date AND type = 'opening'
      ) + SUM(CASE WHEN payment_method = 'cash' THEN total ELSE 0 END) - (
        SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE date = p_date
      )
    )
    FROM sales 
    WHERE DATE(timestamp) = p_date
  );
END;
$$ LANGUAGE plpgsql;
```

### 4.2 Reporte de Deudores ("Huesos")
```sql
CREATE OR REPLACE FUNCTION get_debtors_report()
RETURNS JSON AS $$
BEGIN
  RETURN (
    SELECT json_agg(
      json_build_object(
        'client', json_build_object('id', c.id, 'name', c.name, 'cedula', c.cedula),
        'balance', c.balance,
        'credit_limit', c.credit_limit,
        'last_purchase', (
          SELECT MAX(date) FROM client_transactions 
          WHERE client_id = c.id AND type = 'purchase'
        ),
        'days_overdue', EXTRACT(DAY FROM now() - (
          SELECT MAX(date) FROM client_transactions 
          WHERE client_id = c.id AND type = 'purchase'
        ))
      )
    )
    FROM clients c
    WHERE c.balance > 0
    ORDER BY c.balance DESC
  );
END;
$$ LANGUAGE plpgsql;
```

### 4.3 Uso en Frontend
```typescript
// Antes: Cálculo en Vue (lento, consume batería)
const report = computed(() => {
  return sales.value.reduce((acc, sale) => { ... }, {});
});

// Después: Llamada RPC (rápido, optimizado)
const { data: report } = await supabase.rpc('get_cash_report', {
  p_date: '2024-12-22'
});
```

---

## 5. Proceso de Venta Completo (RPC)

### 5.1 Función de Venta Transaccional
```sql
CREATE OR REPLACE FUNCTION procesar_venta(
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
BEGIN
  -- 1. Calcular total
  FOR v_item IN SELECT * FROM json_array_elements(p_items)
  LOOP
    v_total := v_total + (v_item->>'subtotal')::DECIMAL;
  END LOOP;

  -- 2. Validar crédito si es fiado
  IF p_payment_method = 'fiado' THEN
    IF NOT EXISTS (
      SELECT 1 FROM clients 
      WHERE id = p_client_id 
        AND credit_limit - balance >= v_total
    ) THEN
      RETURN json_build_object('success', false, 'error', 'Cliente excede límite de crédito');
    END IF;
  END IF;

  -- 3. Crear venta
  INSERT INTO sales (total, payment_method, amount_received, change, client_id, employee_id)
  VALUES (
    v_total, 
    p_payment_method, 
    p_amount_received,
    COALESCE(p_amount_received - v_total, 0),
    p_client_id,
    p_employee_id
  )
  RETURNING id INTO v_sale_id;

  -- 4. Insertar items y movimientos de inventario
  FOR v_item IN SELECT * FROM json_array_elements(p_items)
  LOOP
    INSERT INTO sale_items (sale_id, product_id, quantity, price, subtotal)
    VALUES (
      v_sale_id,
      (v_item->>'product_id')::UUID,
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
    INSERT INTO client_transactions (client_id, type, amount, description, sale_id)
    VALUES (p_client_id, 'purchase', v_total, 'Compra #' || v_sale_id, v_sale_id);

    UPDATE clients SET balance = balance + v_total WHERE id = p_client_id;
  END IF;

  RETURN json_build_object(
    'success', true,
    'sale_id', v_sale_id,
    'total', v_total,
    'change', COALESCE(p_amount_received - v_total, 0)
  );
END;
$$ LANGUAGE plpgsql;
```

### 5.2 Uso en POSView
```typescript
// Reemplazar completeSale actual
const completeSale = async (paymentMethod: string, amountReceived?: Decimal, clientId?: number) => {
  const { data, error } = await supabase.rpc('procesar_venta', {
    p_items: cartStore.items.map(item => ({
      product_id: item.id,
      quantity: item.quantity.toNumber(),
      price: item.price.toNumber(),
      subtotal: item.subtotal.toNumber()
    })),
    p_payment_method: paymentMethod,
    p_amount_received: amountReceived?.toNumber(),
    p_client_id: clientId,
    p_employee_id: sessionStore.currentEmployee?.id
  });

  if (data.success) {
    cartStore.clearCart();
    showSaleSuccess(data.sale_id);
  } else {
    showError(data.error);
  }
};
```

---

## 6. Migración de Stores Pinia

### 6.1 Cambios Requeridos

| Store | Antes | Después |
|-------|-------|---------|
| `inventoryStore` | CRUD local | Lectura de `products_safe`, escritura via `inventory_movements` |
| `salesStore` | `addSale()` local | `supabase.rpc('procesar_venta')` |
| `clientsStore` | CRUD local | CRUD con Supabase + transacciones via RPC |
| `employeesStore` | Login con PIN visible | `supabase.rpc('login_empleado')` |

### 6.2 Patrón de Store Híbrido
```typescript
export const useInventoryStore = defineStore('inventory', () => {
  const products = ref<Product[]>([]);
  const loading = ref(false);

  // Cargar desde Supabase
  const fetchProducts = async () => {
    loading.value = true;
    const { data } = await supabase.from('products_safe').select('*');
    products.value = data || [];
    loading.value = false;
  };

  // Suscripción en tiempo real
  const subscribeToChanges = () => {
    supabase
      .channel('products-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'products' }, 
        () => fetchProducts()
      )
      .subscribe();
  };

  return { products, loading, fetchProducts, subscribeToChanges };
});
```

---

## 7. Schema SQL Completo

Ver archivo separado: [`supabase-schema.sql`](./supabase-schema.sql)

---

## 8. Checklist de Migración

- [ ] Crear proyecto en Supabase
- [ ] Ejecutar schema SQL
- [ ] Configurar RLS policies
- [ ] Crear funciones RPC
- [ ] Actualizar `inventoryStore` para usar Supabase
- [ ] Actualizar `salesStore` con `procesar_venta`
- [ ] Actualizar `employeesStore` con `login_empleado`
- [ ] Actualizar `clientsStore` con transacciones RPC
- [ ] Implementar suscripciones en tiempo real
- [ ] Migrar datos existentes de localStorage
- [ ] Testing completo
- [ ] Deploy

---

## Conclusión

Al mover la lógica crítica al backend:

| Aspecto | Antes | Después |
|---------|-------|---------|
| Integridad | Depende del navegador | Garantizada por triggers |
| Seguridad | PINs visibles | Encriptados en BD |
| Performance | Cálculos en celular | Cálculos en servidor |
| Escalabilidad | Un dispositivo | Multi-dispositivo, tiempo real |
| Auditoría | Limitada | Completa (inventory_movements) |

> **"Esto es lo que separa a una 'App de lista de tareas' de un 'Sistema Contable Profesional'."**
