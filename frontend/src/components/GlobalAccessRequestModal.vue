<script setup lang="ts">
/**
 * GlobalAccessRequestModal
 * OT-5: Blocking modal overlay for admin — fires when an employee requests access.
 *
 * Visibility: pendingRequests.length > 0 && !isModalMinimized
 * Rendered via <Teleport to="body"> at z-[400] — above CriticalAlertModal (z-[300]).
 *
 * Actions:
 *   Aprobar  → devicesStore.approveDevice(id)   (server UPDATE → Realtime closes modal)
 *   Rechazar → devicesStore.rejectRequest(id)    (server UPDATE → Realtime closes modal)
 *   Ignorar  → isModalMinimized = true           (client only — no server call)
 */
import { computed, ref } from 'vue';
import { useDevicesStore } from '../stores/devices';
import { ShieldCheck, Check, X, Smartphone, ChevronDown, Clock } from 'lucide-vue-next';

const devicesStore = useDevicesStore();

// Show modal when there are pending requests AND the admin hasn't minimized it
const isVisible = computed(
  () => devicesStore.pendingRequests.length > 0 && !devicesStore.isModalMinimized
);

// The primary request shown in the modal (most recent = first after descending sort)
const primaryRequest = computed(() => devicesStore.pendingRequests[0] ?? null);

// Count of additional requests waiting behind the primary one
const extraCount = computed(() => Math.max(0, devicesStore.pendingRequests.length - 1));

// Loading state per action to prevent double-clicks
const loadingAction = ref<'approve' | 'reject' | null>(null);

const formatTime = (isoDate: string): string => {
  if (!isoDate) return '';
  return new Date(isoDate).toLocaleTimeString('es-CO', {
    hour: '2-digit',
    minute: '2-digit',
  });
};

const parseDevice = (ua: string): string => {
  if (!ua || ua === 'N/A') return 'Dispositivo desconocido';
  if (ua.includes('iPhone')) return 'iPhone';
  if (ua.includes('Android')) return 'Android';
  if (ua.includes('Windows')) return 'Windows';
  if (ua.includes('Mac')) return 'Mac';
  return 'Dispositivo';
};

const handleApprove = async () => {
  if (!primaryRequest.value || loadingAction.value) return;
  loadingAction.value = 'approve';
  try {
    await devicesStore.approveDevice(primaryRequest.value.id);
    // Realtime UPDATE 'approved' will clear the request from pendingRequests.
    // Modal auto-hides when pendingRequests becomes empty (reactive).
  } finally {
    loadingAction.value = null;
  }
};

const handleReject = async () => {
  if (!primaryRequest.value || loadingAction.value) return;
  loadingAction.value = 'reject';
  try {
    await devicesStore.rejectRequest(primaryRequest.value.id);
    // Realtime UPDATE 'rejected' will clear the request from pendingRequests.
  } finally {
    loadingAction.value = null;
  }
};

const handleMinimize = () => {
  // Client-only: collapses modal to the Security Widget — no server call
  devicesStore.isModalMinimized = true;
};
</script>

<template>
  <Teleport to="body">
    <Transition name="modal-global">
      <div
        v-if="isVisible && primaryRequest"
        class="fixed inset-0 z-[400] flex items-center justify-center p-4"
        role="dialog"
        aria-modal="true"
        aria-labelledby="access-modal-title"
      >
        <!-- Dark overlay — click does NOT close (admin must choose an action) -->
        <div class="absolute inset-0 bg-black/75 backdrop-blur-sm" />

        <!-- Modal Card -->
        <div
          class="relative w-full max-w-sm bg-white dark:bg-slate-800 rounded-2xl shadow-2xl overflow-hidden border-t-4 border-amber-500 animate-scale-in"
        >
          <!-- Pulsing top accent bar -->
          <div class="absolute top-0 left-0 right-0 h-1 bg-amber-400 animate-pulse" />

          <!-- Header -->
          <div class="flex items-center gap-3 px-5 pt-6 pb-4">
            <div class="flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-900/40">
              <ShieldCheck class="text-amber-600 dark:text-amber-400" :size="26" :stroke-width="1.8" />
            </div>
            <div>
              <p id="access-modal-title" class="text-xs font-bold uppercase tracking-widest text-amber-600 dark:text-amber-400">
                Solicitud de Acceso
              </p>
              <h2 class="text-lg font-extrabold text-slate-900 dark:text-white leading-tight">
                {{ primaryRequest.employeeName }}
              </h2>
            </div>
          </div>

          <!-- Body: device info + time -->
          <div class="px-5 pb-4 space-y-2">
            <div class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400">
              <Smartphone :size="15" />
              <span>{{ parseDevice(primaryRequest.userAgent) }}</span>
            </div>
            <div class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400">
              <Clock :size="15" />
              <span>Solicitado a las {{ formatTime(primaryRequest.requestedAt) }}</span>
            </div>

            <!-- Extra requests badge -->
            <div
              v-if="extraCount > 0"
              class="mt-2 inline-flex items-center gap-1.5 rounded-full bg-amber-50 dark:bg-amber-900/30 border border-amber-200 dark:border-amber-700 px-3 py-1 text-xs font-semibold text-amber-700 dark:text-amber-300"
            >
              <span class="h-1.5 w-1.5 rounded-full bg-amber-500 animate-pulse" />
              +{{ extraCount }} más esperando
            </div>
          </div>

          <!-- Divider -->
          <div class="mx-5 h-px bg-slate-100 dark:bg-slate-700" />

          <!-- Actions -->
          <div class="flex flex-col gap-3 p-5">
            <!-- Aprobar (primary) -->
            <button
              id="modal-btn-approve"
              @click="handleApprove"
              :disabled="!!loadingAction"
              class="w-full h-12 rounded-xl bg-green-600 hover:bg-green-700 disabled:opacity-60 disabled:cursor-not-allowed text-white font-bold text-sm flex items-center justify-center gap-2 transition-all shadow-md active:scale-[0.98]"
            >
              <span v-if="loadingAction === 'approve'" class="h-4 w-4 rounded-full border-2 border-white border-t-transparent animate-spin" />
              <Check v-else :size="18" :stroke-width="2.5" />
              Aprobar Acceso
            </button>

            <!-- Rechazar (secondary) -->
            <button
              id="modal-btn-reject"
              @click="handleReject"
              :disabled="!!loadingAction"
              class="w-full h-11 rounded-xl border border-slate-200 dark:border-slate-600 hover:bg-red-50 dark:hover:bg-red-900/20 hover:border-red-300 dark:hover:border-red-700 hover:text-red-700 dark:hover:text-red-300 disabled:opacity-60 disabled:cursor-not-allowed text-slate-600 dark:text-slate-400 font-semibold text-sm flex items-center justify-center gap-2 transition-all active:scale-[0.98]"
            >
              <span v-if="loadingAction === 'reject'" class="h-4 w-4 rounded-full border-2 border-current border-t-transparent animate-spin" />
              <X v-else :size="16" :stroke-width="2.5" />
              Rechazar
            </button>

            <!-- Ignorar (text link — client-only minimize) -->
            <button
              id="modal-btn-minimize"
              @click="handleMinimize"
              :disabled="!!loadingAction"
              class="flex items-center justify-center gap-1.5 text-xs text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300 disabled:opacity-40 transition-colors mt-1"
            >
              <ChevronDown :size="14" />
              Ignorar por ahora
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* Entry animation */
.modal-global-enter-active,
.modal-global-leave-active {
  transition: opacity 0.25s ease;
}

.modal-global-enter-from,
.modal-global-leave-to {
  opacity: 0;
}

/* Card scale-in (same keyframe as CriticalAlertModal) */
.animate-scale-in {
  animation: scaleIn 0.28s cubic-bezier(0.34, 1.56, 0.64, 1);
}

@keyframes scaleIn {
  from {
    opacity: 0;
    transform: scale(0.88);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}
</style>
