<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { ShieldCheck, FilePlus2, ArrowLeft, LogOut, RefreshCw, AlertCircle, CheckCircle2 } from 'lucide-vue-next';
import {
  legalRepository,
  type LegalChangeLevel,
  type LegalDocumentType,
  type LegalVersionRecord,
} from '../data/repositories/legalRepository';

const router = useRouter();

const sessionEmail = ref<string | null>(null);
const loginEmail = ref('');
const loginPassword = ref('');
const authError = ref('');
const isAuthenticating = ref(false);

const versions = ref<LegalVersionRecord[]>([]);
const isLoadingVersions = ref(false);
const versionsError = ref('');

const documentType = ref<LegalDocumentType>('terms_of_service');
const versionCode = ref('');
const changeLevel = ref<LegalChangeLevel>('major');
const changeSummary = ref('');
const content = ref('');
const isPublishing = ref(false);
const publishError = ref('');
const publishSuccess = ref('');

const syncAuthState = async () => {
  sessionEmail.value = await legalRepository.getPlatformSessionEmail();
};

const loadVersions = async () => {
  isLoadingVersions.value = true;
  versionsError.value = '';
  try {
    versions.value = await legalRepository.listAllVersions();
  } catch (err: any) {
    versionsError.value = err?.message || 'Error consultando versiones legales.';
  } finally {
    isLoadingVersions.value = false;
  }
};

onMounted(async () => {
  await syncAuthState();
  await loadVersions();
});

const handlePlatformLogin = async () => {
  authError.value = '';
  isAuthenticating.value = true;
  try {
    sessionEmail.value = await legalRepository.signInPlatformAdmin(loginEmail.value, loginPassword.value);
    loginPassword.value = '';
    await loadVersions();
  } catch (err: any) {
    authError.value = err?.message || 'Error al iniciar sesión.';
  } finally {
    isAuthenticating.value = false;
  }
};

const handlePlatformLogout = async () => {
  await legalRepository.signOutPlatformAdmin();
  sessionEmail.value = null;
  publishError.value = '';
  publishSuccess.value = '';
};

const handlePublish = async () => {
  publishError.value = '';
  publishSuccess.value = '';
  isPublishing.value = true;
  try {
    const result = await legalRepository.publishLegalVersion({
      documentType: documentType.value,
      versionCode: versionCode.value.trim(),
      changeLevel: changeLevel.value,
      changeSummary: changeSummary.value.trim(),
      content: content.value.trim(),
    });
    publishSuccess.value = `Versión ${result.version_code} publicada como vigente (${result.document_type}).`;
    versionCode.value = '';
    changeSummary.value = '';
    content.value = '';
    await loadVersions();
  } catch (err: any) {
    publishError.value = err?.message || 'Error al publicar versión legal.';
  } finally {
    isPublishing.value = false;
  }
};
</script>

<template>
  <div class="min-h-screen bg-background-light dark:bg-background-dark text-slate-900 dark:text-white pb-12">
    <header class="sticky top-0 z-30 bg-surface-light/95 dark:bg-surface-dark/95 border-b border-slate-200 dark:border-slate-700">
      <div class="max-w-3xl mx-auto px-4 h-16 flex items-center justify-between gap-3">
        <button
          type="button"
          @click="router.push('/login')"
          aria-label="Volver al inicio"
          class="flex items-center justify-center min-h-[44px] min-w-[44px] -ml-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800"
        >
          <ArrowLeft :size="20" />
        </button>
        <div class="flex items-center gap-2 flex-1 min-w-0">
          <ShieldCheck :size="20" class="text-primary shrink-0" />
          <h1 class="text-base sm:text-lg font-bold truncate">
            Administración Legal de Plataforma
          </h1>
        </div>
        <button
          v-if="sessionEmail"
          type="button"
          @click="handlePlatformLogout"
          class="inline-flex items-center gap-1.5 text-xs font-semibold px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800"
        >
          <LogOut :size="14" />
          Salir
        </button>
      </div>
    </header>

    <main class="max-w-3xl mx-auto px-4 py-6 space-y-6">
      <!-- Auth Panel -->
      <section class="bg-surface-light dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-700 p-5 space-y-4">
        <div v-if="sessionEmail" class="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h2 class="text-sm font-bold">Sesión actual</h2>
            <p class="text-xs font-mono text-slate-600 dark:text-slate-300 mt-0.5">{{ sessionEmail }}</p>
          </div>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            El servidor valida permiso exclusivo de Dueño de Plataforma.
          </span>
        </div>

        <form v-else @submit.prevent="handlePlatformLogin" class="space-y-3">
          <h2 class="text-base font-bold">Acceso Dueño de Plataforma SaaS</h2>
          <div class="grid sm:grid-cols-2 gap-3">
            <input
              v-model="loginEmail"
              type="email"
              required
              placeholder="Correo Dueño de Plataforma"
              class="h-11 px-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-sm"
            />
            <input
              v-model="loginPassword"
              type="password"
              required
              placeholder="Contraseña"
              class="h-11 px-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-sm"
            />
          </div>
          <p v-if="authError" class="text-xs text-red-600 dark:text-red-400 font-medium">{{ authError }}</p>
          <button
            type="submit"
            :disabled="isAuthenticating"
            class="min-h-[44px] px-4 py-2 rounded-xl bg-primary text-white text-sm font-semibold hover:bg-primary-dark disabled:opacity-50"
          >
            {{ isAuthenticating ? 'Verificando...' : 'Ingresar como Dueño de Plataforma' }}
          </button>
        </form>
      </section>

      <!-- Publish Form -->
      <section class="bg-surface-light dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-700 p-5 space-y-4">
        <div class="flex items-center gap-2">
          <FilePlus2 :size="18" class="text-primary" />
          <h2 class="text-base font-bold">Publicar Nueva Versión Legal</h2>
        </div>

        <form @submit.prevent="handlePublish" class="space-y-4">
          <div class="grid sm:grid-cols-3 gap-3">
            <label class="flex flex-col gap-1 text-xs font-semibold">
              Documento
              <select
                v-model="documentType"
                class="h-11 px-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-sm font-normal"
              >
                <option value="terms_of_service">Términos y Condiciones</option>
                <option value="privacy_policy">Política de Datos</option>
              </select>
            </label>

            <label class="flex flex-col gap-1 text-xs font-semibold">
              Código Versión
              <input
                v-model="versionCode"
                type="text"
                required
                placeholder="Ej. 2.0"
                class="h-11 px-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-sm font-mono font-normal"
              />
            </label>

            <label class="flex flex-col gap-1 text-xs font-semibold">
              Nivel de Cambio
              <select
                v-model="changeLevel"
                class="h-11 px-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-sm font-normal"
              >
                <option value="major">Mayor (Exige aceptación)</option>
                <option value="minor">Menor (Solo informativo)</option>
              </select>
            </label>
          </div>

          <label class="flex flex-col gap-1 text-xs font-semibold">
            Resumen de Cambios
            <input
              v-model="changeSummary"
              type="text"
              required
              placeholder="Ej. Actualización de finalidades de respaldo contable"
              class="h-11 px-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-sm font-normal"
            />
          </label>

          <label class="flex flex-col gap-1 text-xs font-semibold">
            Texto Íntegro del Documento
            <textarea
              v-model="content"
              rows="6"
              required
              placeholder="Texto legal completo..."
              class="p-3 rounded-xl border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-sm font-normal"
            ></textarea>
          </label>

          <div v-if="publishError" class="flex items-start gap-2 p-3 rounded-xl bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 text-xs text-red-700 dark:text-red-200">
            <AlertCircle :size="16" class="shrink-0 mt-0.5" />
            <span>{{ publishError }}</span>
          </div>

          <div v-if="publishSuccess" class="flex items-start gap-2 p-3 rounded-xl bg-emerald-50 dark:bg-emerald-900/30 border border-emerald-200 dark:border-emerald-800 text-xs text-emerald-700 dark:text-emerald-200">
            <CheckCircle2 :size="16" class="shrink-0 mt-0.5" />
            <span>{{ publishSuccess }}</span>
          </div>

          <button
            type="submit"
            :disabled="isPublishing || !sessionEmail"
            class="min-h-[44px] px-5 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white text-sm font-semibold disabled:opacity-50"
          >
            {{ isPublishing ? 'Publicando...' : 'Publicar como Versión Vigente' }}
          </button>
        </form>
      </section>

      <!-- History List -->
      <section class="bg-surface-light dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-700 p-5 space-y-3">
        <div class="flex items-center justify-between">
          <h2 class="text-base font-bold">Historial de Versiones Publicadas</h2>
          <button
            type="button"
            @click="loadVersions"
            class="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500"
            aria-label="Actualizar historial"
          >
            <RefreshCw :size="16" :class="{ 'animate-spin': isLoadingVersions }" />
          </button>
        </div>

        <p v-if="versionsError" class="text-xs text-red-600">{{ versionsError }}</p>
        <p v-else-if="versions.length === 0" class="text-sm text-slate-500">
          No hay versiones legales registradas aún.
        </p>
        <div v-else class="divide-y divide-slate-200 dark:divide-slate-700">
          <div v-for="ver in versions" :key="ver.id" class="py-3 space-y-1">
            <div class="flex flex-wrap items-center justify-between gap-2">
              <span class="text-sm font-semibold">
                {{ ver.document_type === 'terms_of_service' ? 'Términos' : 'Política de Datos' }}
                <span class="font-mono ml-1">v{{ ver.version_code }}</span>
              </span>
              <div class="flex items-center gap-2 text-xs font-mono">
                <span class="px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800">
                  {{ ver.change_level }}
                </span>
                <span
                  v-if="ver.is_active"
                  class="px-2 py-0.5 rounded bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 font-semibold"
                >
                  VIGENTE
                </span>
              </div>
            </div>
            <p class="text-xs text-slate-600 dark:text-slate-300">{{ ver.change_summary }}</p>
          </div>
        </div>
      </section>
    </main>
  </div>
</template>
