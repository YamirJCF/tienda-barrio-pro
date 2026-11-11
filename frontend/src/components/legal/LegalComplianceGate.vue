<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  ShieldAlert,
  Info,
  X,
  RefreshCw,
  LogOut,
  CheckCircle2,
  LifeBuoy,
  FileText,
} from 'lucide-vue-next';
import { useAuthStore } from '../../stores/auth';
import { useCartStore } from '../../stores/cart';
import BaseModal from '../ui/BaseModal.vue';
import type { ActiveLegalDocument } from '../../data/repositories/legalRepository';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const cartStore = useCartStore();

const isAcceptedChecked = ref(false);
const showSupportHelp = ref(false);
const actionError = ref('');
const logoutError = ref('');
const previewMinorDoc = ref<ActiveLegalDocument | null>(null);

// RN-10: Nunca interrumpir una venta que ya esté en curso en POS
const isActiveSaleInProgress = computed(() => {
  return route.path === '/pos' && cartStore.items.length > 0;
});

const isAdminSession = computed(() => authStore.isAuthenticated && authStore.isAdmin);

const shouldShowCheckError = computed(() => {
  return (
    isAdminSession.value &&
    Boolean(authStore.legalCheckError) &&
    !isActiveSaleInProgress.value &&
    authStore.legalComplianceStatus !== 'requires_major_acceptance'
  );
});

const shouldShowMajorModal = computed(() => {
  return (
    isAdminSession.value &&
    authStore.legalComplianceStatus === 'requires_major_acceptance' &&
    authStore.legalPendingMajorDocs.length > 0 &&
    !isActiveSaleInProgress.value
  );
});

const shouldShowMinorBanner = computed(() => {
  return (
    isAdminSession.value &&
    authStore.legalComplianceStatus === 'minor_notice_available' &&
    authStore.legalPendingMinorNotices.length > 0 &&
    !authStore.minorNoticeDismissed &&
    !shouldShowMajorModal.value
  );
});

// Si aparece una versión nueva (v2 -> v3), desmarcar casilla para exigir revisión real
watch(
  () => authStore.legalPendingMajorDocs.map((d) => d.version_id).join(','),
  () => {
    isAcceptedChecked.value = false;
    actionError.value = '';
  }
);

const docLabel = (docType: ActiveLegalDocument['document_type']) =>
  docType === 'terms_of_service'
    ? 'Términos y Condiciones del Servicio'
    : 'Política de Tratamiento de Datos Personales';

const formatDate = (iso: string) => {
  try {
    return new Intl.DateTimeFormat('es-CO', { dateStyle: 'medium' }).format(new Date(iso));
  } catch {
    return iso;
  }
};

const handleRetryCheck = async () => {
  actionError.value = '';
  await authStore.checkLegalCompliance();
};

const handleAcceptMajor = async () => {
  if (!isAcceptedChecked.value || authStore.isAcceptingLegal) return;
  actionError.value = '';
  try {
    const versionIds = authStore.legalPendingMajorDocs.map((d) => d.version_id);
    await authStore.acceptPendingLegalVersions(versionIds, 'web_login_gate');
  } catch (err: any) {
    actionError.value =
      err?.message || 'No se pudo registrar tu aceptación legal. Intenta nuevamente.';
  }
};

const handleLogoutDueToRejection = async () => {
  logoutError.value = '';
  const ok = await authStore.logout();
  if (!ok) {
    logoutError.value =
      'No pudimos cerrar la sesión en este momento. Verifica tu conexión o sincroniza los movimientos pendientes.';
    return;
  }
  router.push('/login');
};
</script>

<template>
  <!-- Aviso no bloqueante ante versión menor (RN-11) -->
  <div
    v-if="shouldShowMinorBanner"
    role="region"
    aria-label="Aviso de actualización legal menor"
    class="w-full bg-amber-50 dark:bg-amber-950/60 border-b border-amber-300 dark:border-amber-700 px-4 py-3 text-slate-900 dark:text-amber-50"
  >
    <div class="flex items-start gap-2.5">
      <Info :size="18" class="text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
      <div class="flex-1 min-w-0 text-xs sm:text-sm space-y-1">
        <p class="font-semibold">
          Actualización informativa en tus documentos legales
        </p>
        <ul class="space-y-0.5 text-slate-700 dark:text-amber-100/90">
          <li v-for="doc in authStore.legalPendingMinorNotices" :key="doc.version_id">
            <strong>{{ docLabel(doc.document_type) }}</strong>
            <span class="tabular-money ml-1 text-xs">(v{{ doc.version_code }})</span>:
            {{ doc.change_summary }}
            <button
              type="button"
              @click="previewMinorDoc = doc"
              class="ml-1.5 underline font-semibold text-primary dark:text-primary-light hover:opacity-80"
            >
              Leer documento
            </button>
          </li>
        </ul>
      </div>
      <button
        type="button"
        @click="authStore.dismissMinorNotice()"
        aria-label="Cerrar aviso informativo"
        class="p-1.5 rounded-lg text-amber-800 dark:text-amber-200 hover:bg-amber-200/50 dark:hover:bg-amber-900/50 transition-colors"
      >
        <X :size="16" />
      </button>
    </div>
  </div>

  <!-- Falla al verificar cumplimiento legal (sin fallo silencioso) -->
  <div
    v-if="shouldShowCheckError"
    role="alert"
    class="w-full bg-red-50 dark:bg-red-950/60 border-b border-red-200 dark:border-red-800 px-4 py-3 flex items-center justify-between gap-3"
  >
    <div class="flex items-center gap-2 text-xs text-red-800 dark:text-red-200">
      <ShieldAlert :size="16" class="shrink-0" />
      <span>{{ authStore.legalCheckError }}</span>
    </div>
    <button
      type="button"
      @click="handleRetryCheck"
      :disabled="authStore.isCheckingLegal"
      class="shrink-0 inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-red-600 text-white text-xs font-semibold hover:bg-red-700 active:scale-95"
    >
      <RefreshCw :size="13" :class="{ 'animate-spin': authStore.isCheckingLegal }" />
      Reintentar
    </button>
  </div>

  <!-- Modal Bloqueante ante Versión Mayor Pendiente (RN-10, RN-12, RN-13) -->
  <Teleport to="body">
    <div
      v-if="shouldShowMajorModal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="legal-gate-title"
      class="fixed inset-0 z-[70] flex items-center justify-center bg-slate-950/75 p-4"
    >
      <div
        class="w-full max-w-lg max-h-[90vh] flex flex-col bg-surface-light dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-700 shadow-2xl overflow-hidden text-slate-900 dark:text-white"
      >
        <header class="px-5 py-4 border-b border-slate-200 dark:border-slate-700 flex items-start gap-3">
          <div class="p-2 rounded-xl bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 shrink-0">
            <ShieldAlert :size="22" />
          </div>
          <div>
            <h2 id="legal-gate-title" class="text-lg font-bold tracking-tight">
              Actualización Legal Requerida
            </h2>
            <p class="text-xs sm:text-sm text-slate-600 dark:text-slate-300 mt-0.5">
              Para continuar operando tu tienda, revisa y acepta los cambios vigentes.
            </p>
          </div>
        </header>

        <div class="flex-1 overflow-y-auto px-5 py-4 space-y-4">
          <article
            v-for="doc in authStore.legalPendingMajorDocs"
            :key="doc.version_id"
            class="rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/60 overflow-hidden"
          >
            <div class="px-4 py-3 border-b border-slate-200 dark:border-slate-700 flex flex-wrap items-center justify-between gap-2">
              <div class="flex items-center gap-2">
                <FileText :size="16" class="text-primary shrink-0" />
                <h3 class="text-sm font-bold">{{ docLabel(doc.document_type) }}</h3>
              </div>
              <span class="text-xs font-semibold tabular-money px-2 py-0.5 rounded bg-surface-light dark:bg-slate-900 border border-slate-200 dark:border-slate-600">
                v{{ doc.version_code }} · {{ formatDate(doc.published_at) }}
              </span>
            </div>

            <div class="px-4 py-3 space-y-2">
              <p class="text-xs font-medium text-slate-700 dark:text-slate-200">
                <strong>Qué cambió:</strong> {{ doc.change_summary }}
              </p>
              <div class="max-h-44 overflow-y-auto rounded-lg bg-surface-light dark:bg-slate-900 border border-slate-200 dark:border-slate-700 p-3 text-xs leading-relaxed text-slate-700 dark:text-slate-300 whitespace-pre-line">
                {{ doc.content }}
              </div>
            </div>
          </article>

          <!-- Error de envío -->
          <div
            v-if="actionError"
            role="alert"
            class="p-3 rounded-xl bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 text-xs sm:text-sm text-red-700 dark:text-red-200 font-medium"
          >
            {{ actionError }}
          </div>

          <!-- Casilla de aceptación sin marcado previo (RN-02) -->
          <label
            for="legal-gate-checkbox"
            class="flex items-start gap-3 p-3.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-surface-light dark:bg-slate-800 cursor-pointer"
          >
            <input
              id="legal-gate-checkbox"
              v-model="isAcceptedChecked"
              type="checkbox"
              class="mt-0.5 h-5 w-5 rounded border-slate-300 text-primary focus:ring-primary shrink-0"
            />
            <span class="text-xs sm:text-sm font-medium text-slate-800 dark:text-slate-100 leading-snug">
              He leído el contenido completo y acepto expresamente los documentos legales vigentes listados arriba.
            </span>
          </label>

          <!-- Canal de soporte / rechazo (RN-12) -->
          <div
            v-if="showSupportHelp"
            class="p-3.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/80 space-y-2 text-xs text-slate-700 dark:text-slate-200"
          >
            <div class="flex items-start gap-2">
              <LifeBuoy :size="16" class="text-primary shrink-0 mt-0.5" />
              <div class="space-y-1">
                <p class="font-bold">Canal oficial de atención y cierre de cuenta</p>
                <p>
                  {{
                    authStore.legalSupportChannel?.message ||
                    'Si no estás de acuerdo con las nuevas condiciones o deseas cerrar tu cuenta, contáctanos antes de continuar.'
                  }}
                </p>
                <p class="font-mono font-semibold text-primary">
                  {{ authStore.legalSupportChannel?.contact || 'soporte@tiendabarriopro.co' }}
                </p>
              </div>
            </div>
            <p v-if="logoutError" class="text-red-600 dark:text-red-300 font-medium">
              {{ logoutError }}
            </p>
            <button
              type="button"
              @click="handleLogoutDueToRejection"
              class="inline-flex items-center gap-1.5 min-h-[40px] px-3 py-1.5 rounded-lg border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 font-semibold hover:bg-red-50 dark:hover:bg-red-900/30 active:scale-95 transition-all"
            >
              <LogOut :size="14" />
              No acepto, cerrar sesión
            </button>
          </div>
        </div>

        <footer class="px-5 py-4 border-t border-slate-200 dark:border-slate-700 flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 bg-surface-light dark:bg-surface-dark">
          <button
            type="button"
            @click="showSupportHelp = !showSupportHelp"
            class="min-h-[44px] px-3 py-2 text-xs sm:text-sm font-semibold text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            {{ showSupportHelp ? 'Ocultar ayuda' : 'No acepto / Consultar soporte' }}
          </button>

          <button
            type="button"
            @click="handleAcceptMajor"
            :disabled="!isAcceptedChecked || authStore.isAcceptingLegal"
            class="min-h-[44px] px-5 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white text-sm font-semibold inline-flex items-center justify-center gap-2 transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <RefreshCw v-if="authStore.isAcceptingLegal" :size="16" class="animate-spin" />
            <CheckCircle2 v-else :size="16" />
            {{ authStore.isAcceptingLegal ? 'Registrando...' : 'Aceptar y Continuar' }}
          </button>
        </footer>
      </div>
    </div>
  </Teleport>

  <!-- Lector modal para aviso menor -->
  <BaseModal
    :modelValue="Boolean(previewMinorDoc)"
    :title="previewMinorDoc ? docLabel(previewMinorDoc.document_type) : ''"
    :showCloseButton="true"
    @update:modelValue="(v) => { if (!v) previewMinorDoc = null; }"
  >
    <div v-if="previewMinorDoc" class="p-5 space-y-3">
      <div class="flex flex-wrap items-center justify-between gap-2 text-xs text-slate-600 dark:text-slate-300">
        <span class="tabular-money font-semibold px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800">
          v{{ previewMinorDoc.version_code }}
        </span>
        <span class="tabular-money">Publicado: {{ formatDate(previewMinorDoc.published_at) }}</span>
      </div>
      <p class="text-xs font-medium text-slate-700 dark:text-slate-200">
        <strong>Cambio reportado:</strong> {{ previewMinorDoc.change_summary }}
      </p>
      <div class="text-sm leading-relaxed text-slate-700 dark:text-slate-200 whitespace-pre-line border-t border-slate-200 dark:border-slate-700 pt-3">
        {{ previewMinorDoc.content }}
      </div>
    </div>
  </BaseModal>
</template>
