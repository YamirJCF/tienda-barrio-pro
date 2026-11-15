/**
 * Supabase Client (Legacy Adapter)
 * Redirects to the centralized singleton in data/supabaseClient
 * to ensure shared session state and prevent "Multiple GoTrueClient" errors.
 */
import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '../types/database.types';
import { requireSupabase } from '../data/supabaseClient';

// Lazy Proxy: avoids throwing at module import time in non-browser/unconfigured environments
// while enforcing the exact same client instance returned by requireSupabase().
export const supabase = new Proxy({} as SupabaseClient<Database>, {
  get(_target, prop, receiver) {
    const client = requireSupabase();
    const value = Reflect.get(client, prop, receiver);
    return typeof value === 'function' ? value.bind(client) : value;
  },
});

