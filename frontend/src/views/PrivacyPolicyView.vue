<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ArrowLeft, FileText, RefreshCw, AlertCircle, ShieldCheck } from 'lucide-vue-next';
import {
  legalRepository,
  type ActiveLegalCatalog,
  type LegalDocumentType,
} from '../data/repositories/legalRepository';

const route = useRoute();
const router = useRouter();

const catalog = ref<ActiveLegalCatalog | null>(null);
const isLoading = ref(true);
const errorMessage = ref('');
const selectedType = ref<LegalDocumentType>('privacy_policy');

const syncFromQuery = () => {
  const qDoc = route.query.doc;
  if (qDoc === 'terms' || qDoc === 'terms_of_service') {
    selectedType.value = 'terms_of_service';
  } else {
    selectedType.value = 'privacy_policy';
  }
};

const loadDocuments = async () => {
  isLoading.value = true;
  errorMessage.value = '';
  try {
    catalog.value = await legalRepository.getActiveDocuments();
  } catch (err: any) {
    errorMessage.value =
      err?.message || 'No pudimos consultar el documento legal vigente en este momento.';
  } finally {
    isLoading.value = false;
  }
};

watch(() => route.query.doc, syncFromQuery, { immediate: true });

onMounted(() => {
  loadDocuments();
});

const currentDocument = computed(() => {
  if (!catalog.value) return null;
  return selectedType.value === 'terms_of_service'
    ? catalog.value.terms_of_service
    : catalog.value.privacy_policy;
});

const documentTitle = computed(() =>
  selectedType.value === 'terms_of_service'
    ? 'Términos y Condiciones del Servicio'
    : 'Política de Tratamiento de Datos Personales'
);

const formatPublishedDate = (isoDate: string) => {
  try {
    return new Intl.DateTimeFormat('es-CO', {
      dateStyle: 'long',
      timeStyle: 'short',
    }).format(new Date(isoDate));
  } catch {
    return isoDate;
  }
};

const selectTab = (docType: LegalDocumentType) => {
  selectedType.value = docType;
  router.replace({
    path: route.path,
    query: { doc: docType === 'terms_of_service' ? 'terms' : 'privacy' },
  });
};

const goBack = () => {
  if (window.history.length > 1) {
    router.back();
  } else {
    router.push('/login');
  }
};
</script>

<template>
  <div class="min-h-screen bg-background-light dark:bg-background-dark text-slate-900 dark:text-white">
    <header
      class="sticky top-0 z-30 bg-surface-light/95 dark:bg-surface-dark/95 border-b border-slate-200 dark:border-slate-700"
    >
      <div class="max-w-3xl mx-auto px-4 h-16 flex items-center justify-between gap-3">
        <button
          type="button"
          @click="goBack"
          aria-label="Volver"
          class="flex items-center justify-center min-h-[44px] min-w-[44px] -ml-2 rounded-lg text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 active:scale-95 transition-all"
        >
          <ArrowLeft :size="22" :stroke-width="1.75" />
        </button>
        <h1 class="text-base sm:text-lg font-bold tracking-tight truncate flex-1">
          Documentos Legales Vigentes
        </h1>
        <router-link
          to="/login"
          class="text-xs sm:text-sm font-semibold text-primary hover:text-primary-dark px-2 py-2 rounded-lg"
        >
          Ir al inicio
        </router-link>
      </div>
    </header>

    <main class="max-w-3xl mx-auto px-4 py-6 space-y-5">
      <!-- Selector de documento -->
      <div
        role="tablist"
        aria-label="Seleccionar documento legal"
        class="grid grid-cols-2 gap-2 p-1 rounded-xl bg-slate-200/70 dark:bg-slate-800 border border-slate-200 dark:border-slate-700"
      >
        <button
          type="button"
          role="tab"
          :aria-selected="selectedType === 'terms_of_service'"
          @click="selectTab('terms_of_service')"
          class="min-h-[44px] px-3 py-2 rounded-lg text-xs sm:text-sm font-semibold transition-all active:scale-95"
          :class="
            selectedType === 'terms_of_service'
              ? 'bg-surface-light dark:bg-surface-dark text-primary shadow-sm'
              : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'
          "
        >
          Términos y Condiciones
        </button>
        <button
          type="button"
          role="tab"
          :aria-selected="selectedType === 'privacy_policy'"
          @click="selectTab('privacy_policy')"
          class="min-h-[44px] px-3 py-2 rounded-lg text-xs sm:text-sm font-semibold transition-all active:scale-95"
          :class="
            selectedType === 'privacy_policy'
              ? 'bg-surface-light dark:bg-surface-dark text-primary shadow-sm'
              : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'
          "
        >
          Política de Datos (Ley 1581)
        </button>
      </div>

      <!-- Loading skeleton -->
      <div
        v-if="isLoading"
        class="bg-surface-light dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-700 p-6 space-y-4 animate-pulse"
      >
        <div class="h-6 bg-slate-200 dark:bg-slate-700 rounded w-2/3"></div>
        <div class="h-4 bg-slate-200 dark:bg-slate-700 rounded w-1/3"></div>
        <div class="space-y-2.5 pt-4">
          <div class="h-3.5 bg-slate-200 dark:bg-slate-700 rounded w-full"></div>
          <div class="h-3.5 bg-slate-200 dark:bg-slate-700 rounded w-11/12"></div>
          <div class="h-3.5 bg-slate-200 dark:bg-slate-700 rounded w-10/12"></div>
          <div class="h-3.5 bg-slate-200 dark:bg-slate-700 rounded w-full"></div>
        </div>
      </div>

      <!-- Error state -->
      <div
        v-else-if="errorMessage"
        class="bg-surface-light dark:bg-surface-dark rounded-2xl border border-red-200 dark:border-red-900/50 p-6 space-y-4"
      >
        <div class="flex items-start gap-3">
          <AlertCircle :size="22" class="text-red-600 shrink-0 mt-0.5" />
          <div class="space-y-1">
            <h2 class="text-base font-bold text-slate-900 dark:text-white">
              No se pudo cargar el documento legal
            </h2>
            <p class="text-sm text-slate-600 dark:text-slate-300">
              {{ errorMessage }}
            </p>
          </div>
        </div>
        <button
          type="button"
          @click="loadDocuments"
          class="inline-flex items-center justify-center gap-2 min-h-[44px] px-4 py-2.5 rounded-xl bg-primary text-white text-sm font-semibold hover:bg-primary-dark active:scale-95 transition-all"
        >
          <RefreshCw :size="16" />
          Reintentar carga
        </button>
      </div>

      <!-- Loaded active document -->
      <article
        v-else-if="currentDocument"
        class="bg-surface-light dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-700 overflow-hidden shadow-sm"
      >
        <div class="px-5 py-5 sm:px-6 border-b border-slate-200 dark:border-slate-700 space-y-3">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <div class="flex items-center gap-2 text-slate-900 dark:text-white">
              <ShieldCheck :size="20" class="text-primary shrink-0" />
              <h2 class="text-lg sm:text-xl font-bold tracking-tight">
                {{ documentTitle }}
              </h2>
            </div>
            <span
              class="inline-flex items-center px-2.5 py-1 rounded-lg bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-600 text-xs font-semibold tabular-money text-slate-700 dark:text-slate-200"
            >
              v{{ currentDocument.version_code }} ·
              {{ currentDocument.change_level === 'major' ? 'Versión mayor' : 'Versión menor' }}
            </span>
          </div>

          <div class="text-xs text-slate-600 dark:text-slate-400 flex flex-wrap gap-x-4 gap-y-1">
            <span>
              <strong>Publicado:</strong>
              <span class="tabular-money ml-1">{{ formatPublishedDate(currentDocument.published_at) }}</span>
            </span>
            <span><strong>Responsable:</strong> Tienda Barrio Pro</span>
          </div>

          <div
            v-if="currentDocument.change_summary"
            class="px-3.5 py-2.5 rounded-xl bg-slate-50 dark:bg-slate-800/70 border border-slate-200 dark:border-slate-700 text-xs sm:text-sm text-slate-700 dark:text-slate-200"
          >
            <span class="font-semibold">Resumen de esta versión:</span>
            {{ currentDocument.change_summary }}
          </div>
        </div>

        <div class="px-5 py-5 sm:px-6">
          <div
            class="text-sm sm:text-[15px] leading-relaxed text-slate-700 dark:text-slate-200 whitespace-pre-line max-w-[70ch]"
          >
            {{ currentDocument.content }}
          </div>

          <div class="mt-8 pt-5 border-t border-slate-200 dark:border-slate-700 flex flex-wrap items-center justify-between gap-3">
            <div class="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400">
              <FileText :size="15" />
              <span>Consultas de privacidad: soporte@tiendabarriopro.co</span>
            </div>
            <button
              type="button"
              @click="goBack"
              class="min-h-[44px] px-4 py-2 rounded-xl bg-slate-100 dark:bg-slate-800 text-slate-800 dark:text-slate-200 text-sm font-semibold hover:bg-slate-200 dark:hover:bg-slate-700 active:scale-95 transition-all"
            >
              Volver
            </button>
          </div>
        </div>
      </article>
    </main>
  </div>
</template>
