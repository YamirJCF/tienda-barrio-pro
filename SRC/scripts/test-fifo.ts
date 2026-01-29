
import { createClient } from '@supabase/supabase-js';

// Configuration (Hardcoded for this test script based on what we found)
// NOTE: Ideally this comes from env, but for a headless script in this environment we set it directly
// to ensure we target the project we just migrated.
const SUPABASE_URL = 'https://zolanvecewgdcmfwzqdb.supabase.co';
const SUPABASE_KEY = process.env.VITE_SUPABASE_ANON_KEY || ''; // We need the key.

// If key is missing, we can't run. But I will generate the script structure first.
// The user might need to provide the KEY or we assume it's in the environment where this runs.

async function runFifoTest() {
    console.log('🧪 Starting FIFO Headless Test...');

    if (!SUPABASE_KEY) {
        console.error('❌ Missing VITE_SUPABASE_ANON_KEY. Please run with env var.');
        return;
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

    // 1. Create a Test Product
    const testPlu = `TEST-${Date.now()}`;
    console.log(`Step 1: Creating Test Product PLU: ${testPlu}`);

    // We need a store_id. Let's fetch one.
    const { data: stores } = await supabase.from('stores').select('id').limit(1);
    if (!stores || stores.length === 0) throw new Error('No stores found');
    const storeId = stores[0].id;

    const { data: product, error: prodError } = await supabase.from('products').insert({
        store_id: storeId,
        name: 'FIFA TEST PROD',
        price: 1000,
        cost_price: 500, // Initial Cost
        current_stock: 10, // Initial Stock -> Should create Batch #1
        plu: testPlu
    }).select().single();

    if (prodError) throw new Error(`Product create failed: ${prodError.message}`);
    console.log('✅ Product Created:', product.id);

    // 2. Verify Batch #1 was created (Seeding Trigger? No, seeding was one-off script)
    // Wait! The migration script seeded EXISTING products. THIS new product 
    // needs logic to create a batch if we want to test FIFO.
    // The current migration ONLY converted old stock.
    // The APP is responsible for creating batches on new entries.
    // So we must manually simulate an "Entry" to create Batch #1.

    // Actually, for this test to be valid for the "Migration", we should check if 
    // the initial stock (10) was converted?
    // NO. The migration script ran ONCE. New inserts to 'products' do NOT automatically create batches 
    // unless we add a trigger for that too, or the App handles it.
    // The FRD says "App calls endpoint".

    // So let's manually insert Batch #1 (Simulating App Logic)
    console.log('Step 2: Simulating Purchase (Batch #1, 10 units @ $500)');
    await supabase.from('inventory_batches').insert({
        product_id: product.id,
        quantity_initial: 10,
        quantity_remaining: 10,
        cost_unit: 500
    });

    // Step 3: Simulate Second Purchase (Batch #2, 10 units @ $800)
    console.log('Step 3: Simulating Purchase (Batch #2, 10 units @ $800)');
    await supabase.from('inventory_batches').insert({
        product_id: product.id,
        quantity_initial: 10,
        quantity_remaining: 10,
        cost_unit: 800
    });

    // Check Total Stock Sync Trigger
    const { data: prodRefreshed } = await supabase.from('products').select('current_stock').eq('id', product.id).single();
    console.log(`   -> Current Stock in Product Table: ${prodRefreshed.current_stock} (Expected 20)`);
    if (prodRefreshed.current_stock !== 20) throw new Error('Trigger Sync Failed');

    // Step 4: Consume FIFO (Sale of 15 units)
    // Expected: 10 from Batch #1 ($500) + 5 from Batch #2 ($800)
    // Total Cost = 5000 + 4000 = 9000.
    console.log('Step 4: Executing FIFO Consumption (Selling 15 units)...');

    const { data: consumption, error: fifoError } = await supabase.rpc('consume_stock_fifo', {
        p_product_id: product.id,
        p_quantity_needed: 15
    });

    if (fifoError) throw new Error(`FIFO RPC Failed: ${fifoError.message}`);

    console.log('   -> Consumption Result:', consumption);

    // Validate Results
    let totalCost = 0;
    let totalQty = 0;
    consumption.forEach((c: any) => {
        totalQty += c.quantity_taken;
        totalCost += (c.quantity_taken * c.cost_unit);
    });

    console.log(`   -> Total Qty Consumed: ${totalQty} (Expected 15)`);
    console.log(`   -> Total Cost COGS: $${totalCost} (Expected $9000)`);

    if (totalQty !== 15) throw new Error('Qty mismatch');
    if (totalCost !== 9000) throw new Error('FIFO Logic Failed! Cost mismatch.');

    console.log('🎉 SUCCESS: FIFO Architecture Verified.');
}

runFifoTest().catch(console.error);
