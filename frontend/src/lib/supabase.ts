/**
 * Supabase Client (Legacy Adapter)
 * Redirects to the centralized singleton in data/supabaseClient
 * to ensure shared session state and prevent "Multiple GoTrueClient" errors.
 */
import { requireSupabase } from '../data/supabaseClient';

// Re-export the singleton instance
// This enforces that AuthRepository and other consumers use the SAME client instance
export const supabase = requireSupabase();

