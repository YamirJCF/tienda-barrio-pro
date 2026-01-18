/**
 * Supabase Client Stub
 * TODO: Configure with actual Supabase credentials when available
 * 
 * This is a temporary stub to allow the app to compile
 * while SPEC-006 (PIN validation) is in development.
 */

// Stub implementation for development
export const supabase = {
    auth: {
        signInWithPassword: async (credentials: { email: string; password: string }) => {
            // Stub: Always returns error until Supabase is configured
            console.warn('[Supabase Stub] signInWithPassword called - not connected to real backend');
            return {
                data: null,
                error: { message: 'Supabase not configured' }
            };
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
        }
    },
    from: (table: string) => ({
        select: () => ({ data: [], error: null }),
        insert: (data: unknown) => ({ data: null, error: null }),
        update: (data: unknown) => ({ match: () => ({ data: null, error: null }) }),
        delete: () => ({ match: () => ({ data: null, error: null }) }),
    }),
    rpc: async (fn: string, params?: unknown) => {
        console.warn('[Supabase Stub] rpc called:', fn);
        return { data: null, error: null };
    }
};

export default supabase;
