/**
 * Supabase Client Stub (Improved for Repository Chaining)
 * TODO: Configure with actual Supabase credentials when available
 */

const queryBuilder = {
  select: (...args: any[]) => queryBuilder,
  insert: (...args: any[]) => queryBuilder,
  update: (...args: any[]) => queryBuilder,
  delete: (...args: any[]) => queryBuilder,
  eq: (...args: any[]) => queryBuilder,
  neq: (...args: any[]) => queryBuilder,
  gt: (...args: any[]) => queryBuilder,
  lt: (...args: any[]) => queryBuilder,
  gte: (...args: any[]) => queryBuilder,
  lte: (...args: any[]) => queryBuilder,
  like: (...args: any[]) => queryBuilder,
  ilike: (...args: any[]) => queryBuilder,
  is: (...args: any[]) => queryBuilder,
  in: (...args: any[]) => queryBuilder,
  contains: (...args: any[]) => queryBuilder,
  order: (...args: any[]) => queryBuilder,
  limit: (...args: any[]) => queryBuilder,
  range: (...args: any[]) => queryBuilder,
  single: (...args: any[]) => queryBuilder,
  maybeSingle: (...args: any[]) => queryBuilder,
  csv: (...args: any[]) => queryBuilder,
  // Final methods that return data
  then: (resolve: any) => resolve({ data: [], error: null }),
  catch: (reject: any) => reject(new Error('Supabase not configured')),
};

export const supabase = {
  auth: {
    signInWithPassword: async (credentials: { email: string; password: string }) => {
      console.warn('[Supabase Stub] signInWithPassword called');
      return { data: null, error: { message: 'Supabase not configured' } };
    },
    signOut: async () => {
      console.warn('[Supabase Stub] signOut called');
      return { error: null };
    },
    getSession: async () => {
      return { data: { session: null }, error: null };
    },
    onAuthStateChange: (callback: (event: string, session: unknown) => void) => {
      return { data: { subscription: { unsubscribe: () => { } } } };
    },
  },
  from: (table: string) => queryBuilder,
  rpc: async (fn: string, params?: unknown) => {
    console.warn('[Supabase Stub] rpc called:', fn);
    // Mock response for login_empleado_unificado to allow testing flow
    if (fn === 'login_empleado_unificado') {
      return {
        data: {
          success: true,
          employee: {
            id: 'demo-emp-1',
            name: 'Empleado Demo',
            username: 'demo',
            store_id: 'demo-store-001',
            permissions: { canSell: true, canViewInventory: true, canOpenCloseCash: true }
          },
          store_state: { is_open: true }
        },
        error: null
      };
    }
    return { data: null, error: null };
  },
};

export default supabase;
