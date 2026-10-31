/**
 * SDD-013 v3.1.0: Guardia de Verificación Continua de Sesión
 * 
 * Centraliza la autoridad del servidor sobre la validez de la sesión:
 * - Deduplicación de llamadas (single-flight promise)
 * - Sondeo reactivo ante foco (visibilitychange), reconexión de red (online) y timer periódico (5m)
 * - Sincronización multiventana vía BroadcastChannel ('tienda-auth-sync')
 * - Manejador unificado de errores 400 / P0001 (STORE_ACCESS_DENIED)
 */

import { onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useNotificationsStore } from '../stores/notificationsStore';
import { logger } from '../utils/logger';
import type { SessionVerificationResult } from '../data/repositories/authRepository';
import { useToast } from 'vue-toastification';

let activeVerificationPromise: Promise<SessionVerificationResult> | null = null;
let lastAlertTimestamp = 0;
const ALERT_COOLDOWN_MS = 5000; // Deduplicación de avisos dentro de 5 segundos

/**
 * Consulta deduplicada al servidor. Si ya hay una verificación en vuelo,
 * retorna la misma promesa sin duplicar requests de red.
 */
export async function verifySessionDeduped(): Promise<SessionVerificationResult> {
  const authStore = useAuthStore();
  if (!authStore.isAuthenticated) {
    return {
      success: false,
      status: 'requires_login',
      reason: 'NOT_AUTHENTICATED'
    };
  }

  if (activeVerificationPromise) {
    return activeVerificationPromise;
  }

  activeVerificationPromise = authStore.verifySessionWithServer()
    .finally(() => {
      activeVerificationPromise = null;
    });

  return activeVerificationPromise;
}

/**
 * Muestra notificación amigable al usuario deduplicada por cooldown
 */
function showNotificationOnce(message: string, title: string, type: 'warning' | 'error' = 'warning') {
  const now = Date.now();
  if (now - lastAlertTimestamp < ALERT_COOLDOWN_MS) {
    return;
  }
  lastAlertTimestamp = now;

  try {
    const toast = useToast();
    if (type === 'error') {
      toast.error(message);
    } else {
      toast.warning(message);
    }
  } catch {
    // Si toast no está disponible en este ciclo de vida, no bloquear
  }

  try {
    const notificationsStore = useNotificationsStore();
    notificationsStore.addNotification({
      type: 'security',
      audience: 'all',
      title,
      message,
      isRead: false,
      icon: 'ShieldAlert'
    });
  } catch {
    // Fallback silencioso
  }
}

/**
 * Maneja la transición de la UI cuando el servidor determina pérdida o expiración de acceso
 */
export function handleSessionStatusTransition(
  status: SessionVerificationResult['status'],
  router?: any,
  reason?: string
) {
  if (status === 'active') return;

  const currentRoute = router?.currentRoute?.value;
  const isGuestRoute = currentRoute?.meta?.guest || 
    currentRoute?.name === 'login' || 
    currentRoute?.name === 'register' || 
    currentRoute?.path === '/login';

  if (status === 'requires_daily_pass') {
    showNotificationOnce(
      'Tu turno o pase diario ha finalizado para la jornada de hoy. Por favor solicita un nuevo pase para continuar.',
      'Pase Diario Requerido',
      'warning'
    );
    if (router && !isGuestRoute && currentRoute?.name !== 'daily-waiting-room') {
      router.push({ name: 'daily-waiting-room' });
    }
  } else if (status === 'requires_login' || status === 'revoked_or_disabled') {
    const msg = status === 'revoked_or_disabled'
      ? 'Tu acceso ha sido revocado o deshabilitado por el administrador.'
      : 'Tu sesión ha expirado o el acceso fue denegado. Inicia sesión nuevamente.';
    showNotificationOnce(msg, 'Sesión Expirada', 'error');
    if (router && !isGuestRoute) {
      router.push({ name: 'login' });
    }
  }
}

/**
 * Intercepta errores de RPC/PostgREST para detectar STORE_ACCESS_DENIED y unificar la respuesta
 */
export async function handleAccessDeniedError(error: any, router?: any): Promise<boolean> {
  const errString = typeof error === 'string' 
    ? error 
    : (error?.message || error?.details || error?.error_description || JSON.stringify(error || ''));

  const isAccessDenied = errString.includes('STORE_ACCESS_DENIED') ||
    errString.includes('P0001') ||
    errString.includes('El usuario no tiene acceso') ||
    errString.includes('JWT expired') ||
    errString.includes('invalid claim') ||
    (error?.status === 400 && (errString.includes('store') || errString.includes('access')));

  if (isAccessDenied) {
    logger.warn('[SessionGuard] Acceso denegado detectado en llamada backend:', errString);
    const result = await verifySessionDeduped();
    handleSessionStatusTransition(result.status, router, result.reason);
    return true;
  }
  return false;
}

/**
 * Composable para montaje en App.vue.
 * Registra listeners de ciclo de vida, visibilidad, red y BroadcastChannel.
 */
export function useSessionGuard() {
  const authStore = useAuthStore();
  const router = useRouter();
  let intervalId: any = null;
  let broadcastChannel: BroadcastChannel | null = null;

  const verifyAndReact = async () => {
    if (!authStore.isAuthenticated) return;
    try {
      const result = await verifySessionDeduped();
      handleSessionStatusTransition(result.status, router, result.reason);
    } catch (err) {
      logger.error('[SessionGuard] Error en verificación reactiva:', err);
    }
  };

  const onVisibilityChange = () => {
    if (document.visibilityState === 'visible') {
      verifyAndReact();
    }
  };

  const onOnline = () => {
    verifyAndReact();
  };

  onMounted(() => {
    // 1. Verificación inicial si el store reporta autenticado
    if (authStore.isAuthenticated) {
      verifyAndReact();
    }

    // 2. Intervalo periódico de 5 minutos (P_INTERVALO_VERIFICACION_SESION)
    intervalId = setInterval(verifyAndReact, 5 * 60 * 1000);

    // 3. Eventos de entorno (Foco y Conectividad)
    document.addEventListener('visibilitychange', onVisibilityChange);
    window.addEventListener('online', onOnline);

    // 4. Sincronización multiventana (RN-013-13)
    if (typeof BroadcastChannel !== 'undefined') {
      try {
        broadcastChannel = new BroadcastChannel('tienda-auth-sync');
        broadcastChannel.onmessage = (event) => {
          if (event.data?.type === 'SESSION_STATE_CHANGED') {
            handleSessionStatusTransition(event.data.status, router, event.data.reason);
          }
        };
      } catch (e) {
        logger.warn('[SessionGuard] Fallo al iniciar BroadcastChannel:', e);
      }
    }
  });

  onUnmounted(() => {
    if (intervalId) clearInterval(intervalId);
    document.removeEventListener('visibilitychange', onVisibilityChange);
    window.removeEventListener('online', onOnline);
    if (broadcastChannel) {
      broadcastChannel.close();
      broadcastChannel = null;
    }
  });

  return {
    verifySessionDeduped,
    verifyAndReact,
    handleAccessDeniedError: (err: any) => handleAccessDeniedError(err, router),
  };
}

export default useSessionGuard;
