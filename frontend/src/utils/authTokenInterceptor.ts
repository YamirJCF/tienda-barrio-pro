/**
 * Auth Token Interceptor
 * 
 * Intercepts Supabase auth tokens from the URL hash fragment BEFORE
 * Vue Hash Router processes them. This solves the conflict where
 * Hash Router interprets `#access_token=JWT` as a route path.
 * 
 * Must be called in main.ts BEFORE createApp() / router initialization.
 * 
 * @module utils/authTokenInterceptor
 */

import { logger } from './logger';

export interface InterceptResult {
    intercepted: boolean;
    type?: 'signup' | 'recovery' | 'magiclink';
    userId?: string;
    error?: string;
}

/**
 * Validates that a string looks like a JWT token (3 base64 segments separated by dots).
 * Does NOT validate the signature — that's Supabase's job via setSession().
 */
function isValidJWTFormat(token: string): boolean {
    const parts = token.split('.');
    if (parts.length !== 3) return false;
    // Each part should be at least a few characters of base64
    return parts.every(part => part.length >= 4);
}

/**
 * Parses key=value pairs from a raw hash string.
 * Handles formats: #access_token=...&refresh_token=... 
 *                  #/access_token=...&refresh_token=...
 */
function parseRawHashParams(hash: string): Record<string, string> {
    const params: Record<string, string> = {};

    // Strip leading #/ or # 
    let content = hash;
    if (content.startsWith('#/')) {
        content = content.substring(2);
    } else if (content.startsWith('#')) {
        content = content.substring(1);
    }

    if (!content) return params;

    const pairs = content.split('&');
    for (const pair of pairs) {
        const eqIndex = pair.indexOf('=');
        if (eqIndex > 0) {
            const key = pair.substring(0, eqIndex);
            const value = pair.substring(eqIndex + 1);
            params[key] = decodeURIComponent(value);
        }
    }

    return params;
}

/**
 * Safely truncates a token for logging (security: never log full tokens).
 */
function safeTokenLog(token: string): string {
    return token.substring(0, 8) + '...';
}

/**
 * Main interceptor function.
 * 
 * Reads window.location.hash RAW (before Hash Router),
 * extracts Supabase tokens, establishes session, and cleans the hash.
 * 
 * Stores the admin profile data in sessionStorage for the auth store
 * to pick up during initialization.
 */
export async function interceptAuthTokens(): Promise<InterceptResult> {
    const hash = window.location.hash;

    // Quick exit if no tokens in hash
    if (!hash.includes('access_token')) {
        return { intercepted: false };
    }

    logger.log('[AuthInterceptor] Detected auth tokens in URL hash');

    try {
        const params = parseRawHashParams(hash);
        const accessToken = params['access_token'];
        const refreshToken = params['refresh_token'];
        const type = (params['type'] || 'signup') as InterceptResult['type'];

        // Validate required tokens exist
        if (!accessToken || !refreshToken) {
            logger.warn('[AuthInterceptor] Missing access_token or refresh_token');
            return { intercepted: false, error: 'Missing tokens' };
        }

        // Validate JWT format (security: reject obviously invalid tokens)
        if (!isValidJWTFormat(accessToken)) {
            logger.warn('[AuthInterceptor] Invalid JWT format for access_token:', safeTokenLog(accessToken));
            return { intercepted: false, error: 'Invalid token format' };
        }

        logger.log(`[AuthInterceptor] Processing ${type} callback with token ${safeTokenLog(accessToken)}`);

        // Dynamically import supabase client to avoid circular deps
        const { requireSupabase } = await import('../data/supabaseClient');
        const supabase = requireSupabase();

        // Establish the Supabase session
        const { data, error } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken,
        });

        if (error) {
            logger.error('[AuthInterceptor] setSession failed:', error.message);
            // Clean hash even on error to prevent infinite loops
            window.location.hash = '#/';
            return { intercepted: true, type, error: error.message };
        }

        if (!data.session || !data.user) {
            logger.error('[AuthInterceptor] setSession returned no session/user');
            window.location.hash = '#/';
            return { intercepted: true, type, error: 'No session returned' };
        }

        const userId = data.user.id;
        logger.log(`[AuthInterceptor] Session established for user ${userId.substring(0, 8)}...`);

        // For signup confirmations: fetch admin profile and store for Pinia init
        if (type === 'signup') {
            try {
                const { authRepository } = await import('../data/repositories/authRepository');
                const profileResponse = await authRepository.getAdminProfile(userId);

                if (profileResponse.success) {
                    // Store profile in sessionStorage for auth store to pick up
                    sessionStorage.setItem('__auth_callback_profile__', JSON.stringify(profileResponse));
                    logger.log('[AuthInterceptor] Admin profile cached for store initialization');
                } else {
                    logger.warn('[AuthInterceptor] Could not fetch admin profile:', profileResponse.error);
                    // Session is still valid — store will need to init manually
                }
            } catch (profileErr) {
                logger.warn('[AuthInterceptor] Profile fetch failed (non-fatal):', profileErr);
            }
        }

        // For recovery: store the type so the router/callback can redirect
        if (type === 'recovery') {
            sessionStorage.setItem('__auth_callback_type__', 'recovery');
        }

        // Clean the hash — replace with root route for Hash Router
        window.location.hash = '#/';

        logger.log(`[AuthInterceptor] ✅ Complete. Type: ${type}, hash cleaned.`);

        return { intercepted: true, type, userId };

    } catch (err) {
        logger.error('[AuthInterceptor] Unexpected error:', err);
        // Always clean hash to prevent stuck state
        window.location.hash = '#/';
        return { intercepted: false, error: 'Unexpected error' };
    }
}
