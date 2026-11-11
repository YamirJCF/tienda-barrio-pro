<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { logger } from '../utils/logger';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseModal from '@/components/ui/BaseModal.vue';
import {
  legalRepository,
  type ActiveLegalCatalog,
  type ActiveLegalDocument,
} from '../data/repositories/legalRepository';
import {
  ArrowLeft,
  CheckCircle2,
  CircleSlash,
  Mail,
  Lock,
  Store,
  User,
  Eye,
  EyeOff,
  FileText,
  RefreshCw,
  AlertCircle,
} from 'lucide-vue-next';

const router = useRouter();
const authStore = useAuthStore();

// ============================================
// FORM STATE
// ============================================
const storeName = ref('');
const ownerName = ref('');
const email = ref('');
const password = ref('');
const confirmPassword = ref('');
// SPEC-006: PIN eliminado del registro, se configura en AdminHub
const showPassword = ref(false);
const showConfirmPassword = ref(false);

// SDD-029: Doble aceptación separada, siempre desmarcada por defecto (RN-01, RN-02)
const acceptedTerms = ref(false);
const acceptedPrivacy = ref(false);
const legalCatalog = ref<ActiveLegalCatalog | null>(null);
const isLoadingLegal = ref(true);
const legalLoadError = ref('');
const previewDoc = ref<ActiveLegalDocument | null>(null);

const loadLegalDocuments = async () => {
  isLoadingLegal.value = true;
  legalLoadError.value = '';
  try {
    legalCatalog.value = await legalRepository.getActiveDocuments();
  } catch (err: any) {
    legalCatalog.value = null;
    legalLoadError.value =
      err?.message || 'No se pudieron cargar los documentos legales vigentes.';
  } finally {
    isLoadingLegal.value = false;
  }
};

onMounted(() => {
  loadLegalDocuments();
});

// ============================================
// UI STATE
// ============================================
const errorMessage = ref('');
// isLoading handled by useAsyncAction

// ============================================
// VALIDATION RULES
// ============================================
// Regex para validación estricta de email (mínimo 2 letras en el TLD)
const emailRegex = /^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$/;

// Computed validations
const isStoreNameValid = computed(() => storeName.value.trim().length >= 3);
const isOwnerNameValid = computed(() => ownerName.value.trim().length > 0);
// Detección proactiva de errores tipográficos en dominios comunes y TLDs incompletos
const emailTypoWarning = computed(() => {
  const trimmed = email.value.trim().toLowerCase();
  if (!trimmed.includes('@')) return '';

  const domain = trimmed.split('@')[1] || '';

  if (domain.startsWith('gmail.')) {
    if (domain !== 'gmail.com') {
      return 'Los correos de Gmail deben terminar en @gmail.com';
    }
  }

  if (domain.startsWith('hotmail.')) {
    if (domain !== 'hotmail.com' && domain !== 'hotmail.es') {
      return 'Los correos de Hotmail deben terminar en @hotmail.com o .es';
    }
  }

  if (domain.startsWith('outlook.')) {
    if (domain !== 'outlook.com' && domain !== 'outlook.es') {
      return 'Los correos de Outlook deben terminar en @outlook.com o .es';
    }
  }

  const parts = domain.split('.');
  if (parts.length > 1) {
    const ext = parts[parts.length - 1];
    if (ext.length === 1) {
      return 'La extensión del correo debe tener mínimo 2 letras (ej. .com, .co)';
    }
  }

  return '';
});

const isEmailValid = computed(() => emailRegex.test(email.value.trim()) && !emailTypoWarning.value);
// WO-PHASE4-001 AU-07: Strong Password Policy (Min 8, 1 Letter, 1 Number, Special chars allowed)
const passwordRegex = /^(?=.*[A-Za-z])(?=.*\d).{8,}$/;
const isPasswordValid = computed(() => passwordRegex.test(password.value));
// T-004: Validación de confirmación de contraseña
const isConfirmPasswordValid = computed(
  () => confirmPassword.value.length >= 6 && confirmPassword.value === password.value,
);
// SPEC-006: PIN ya no se valida en registro
const isLegalAccepted = computed(
  () => acceptedTerms.value === true && acceptedPrivacy.value === true && legalCatalog.value !== null
);

// Botón habilitado solo si todo es válido, ambas casillas marcadas y no está cargando
const canSubmit = computed(() => {
  return (
    isStoreNameValid.value &&
    isOwnerNameValid.value &&
    isEmailValid.value &&
    isPasswordValid.value &&
    isConfirmPasswordValid.value &&
    isLegalAccepted.value &&
    !isLoadingLegal.value &&
    !isLoading.value
  );
});

// ============================================
// NAVIGATION METHODS
// ============================================
const goBack = () => {
  router.back();
};

// SPEC-006: Keypad handlers eliminados (PIN se configura en AdminHub)

// ============================================
// PASSWORD VISIBILITY TOGGLE
// ============================================
const togglePassword = () => {
  showPassword.value = !showPassword.value;
};

// T-004: Toggle para confirmar contraseña
const toggleConfirmPassword = () => {
  showConfirmPassword.value = !showConfirmPassword.value;
};

// ============================================
// FORM SUBMISSION (ASYNC + ERROR HANDLING)
// ============================================
// Composable: Request Management
import { useAsyncAction } from '../composables/useAsyncAction';
const { execute: executeRegister, isLoading } = useAsyncAction();

// ============================================
// FORM SUBMISSION (ASYNC + ERROR HANDLING)
// ============================================
const handleSubmit = async () => {
  // Guard clause: previene doble-click (isLoading manejado internamente, pero mantenemos check de canSubmit)
  if (!canSubmit.value) return;

  errorMessage.value = '';

  await executeRegister(async () => {
    try {
      if (!legalCatalog.value) {
        throw new Error('Los documentos legales vigentes aún no han cargado.');
      }

      const result = await authStore.registerStore({
        storeName: storeName.value.trim(),
        ownerName: ownerName.value.trim(),
        email: email.value.trim().toLowerCase(),
        password: password.value,
        acceptedTermsVersionId: legalCatalog.value.terms_of_service.version_id,
        acceptedPrivacyVersionId: legalCatalog.value.privacy_policy.version_id,
        originChannel: 'web_register',
        clientUserAgent: typeof navigator !== 'undefined' ? navigator.userAgent : undefined,
      });

      const cleanEmail = email.value.trim().toLowerCase();

      if (!result.success) {
        if (
          result.error_code === 'LEGAL_VERSION_SUPERSEDED' ||
          result.error_code === 'LEGAL_ACCEPTANCE_REQUIRED'
        ) {
          acceptedTerms.value = false;
          acceptedPrivacy.value = false;
          await loadLegalDocuments();
          throw new Error(
            'La versión vigente de los documentos legales fue actualizada. Revísala nuevamente y vuelve a marcar tus aceptaciones.'
          );
        }
        // Mensajes amigables traducidos según Regla 2.2 de UX
        if (result.error?.includes('already registered') || result.error_code === 'user_already_exists') {
          throw new Error('Este correo ya está registrado. Por favor, inicia sesión.');
        }
        if (result.error?.includes('rate limit') || result.error_code === 'over_email_send_rate_limit') {
          throw new Error('Límite de envíos alcanzado por seguridad. Por favor, espera unos minutos antes de intentar de nuevo.');
        }
        if (result.error?.includes('invalid') || result.error_code === 'email_address_invalid') {
          throw new Error('La dirección de correo electrónico ingresada no es válida.');
        }
        // Error general devuelto por Supabase/Repo
        throw new Error(result.error || 'No fue posible registrar la cuenta.');
      }

      // Flujo Obligatorio: Toda cuenta nueva debe confirmar correo y pasar por la Sala de Espera
      logger.log('✅ Tienda registrada exitosamente (Esperando confirmación obligatoria)');
      sessionStorage.setItem('pending_verification_email', cleanEmail);
      // Redirección a sala de espera WO-008 pasando el email
      router.push({
        path: '/auth/waiting-verification',
        query: { email: cleanEmail }
      });
    } catch (err: any) {
      errorMessage.value = err?.message || 'Error al registrar la cuenta.';
      throw err;
    }
  }, {
    errorMessage: 'Error del sistema. Por favor, intenta nuevamente.',
    successMessage: 'Tienda registrada correctamente',
    checkConnectivity: true
  });
};
</script>

<template>
  <div
    class="bg-background-light dark:bg-background-dark min-h-screen text-slate-900 dark:text-white font-display"
  >
    <!-- Header -->
    <header
      class="sticky top-0 z-50 bg-surface-light/95 dark:bg-surface-dark/95 backdrop-blur-sm border-b border-slate-200 dark:border-slate-700"
    >
      <div class="flex items-center px-4 h-16 max-w-lg mx-auto">
        <button
          @click="goBack"
          aria-label="Volver"
          class="flex items-center justify-center w-10 h-10 -ml-2 rounded-full active:bg-slate-100 dark:active:bg-white/10 text-slate-900 dark:text-white transition-colors"
        >
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </button>
        <h1 class="flex-1 text-center text-lg font-bold tracking-tight pr-8">
          Registra tu Negocio
        </h1>
      </div>
    </header>

    <main class="flex flex-col w-full max-w-lg mx-auto pb-10">
      <!-- Section 1: Tu Negocio -->
      <section class="px-5 pt-6 animate-[fadeIn_0.3s_ease-out]">
        <h2 class="text-xl font-bold text-[#0d1c17] dark:text-white mb-4 flex items-center gap-2">
          <span
            class="bg-emerald-500/10 text-emerald-600 w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold"
            >1</span
          >
          Tu Negocio
        </h2>
        <div class="space-y-5">
          <div class="flex flex-col gap-1.5">
            <label
              class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
              for="storeName"
              >Nombre de la Tienda</label
            >
            <div class="relative">
              <BaseInput
                v-model="storeName"
                id="storeName"
                placeholder="Ej. Abastos La Estrella"
                :class="{'text-emerald-500': isStoreNameValid}"
              >
                  <template #prefix>
                      <Store :size="18" class="text-gray-400" :class="{'text-emerald-500': isStoreNameValid}" />
                  </template>
              </BaseInput>
  
            </div>
            <p class="text-xs text-[#489d82] dark:text-gray-400 ml-1">
              Así aparecerá en tus recibos digitales.
            </p>
          </div>

          <div class="flex flex-col gap-1.5">
            <label
              class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
              for="ownerName"
              >Nombre del Dueño</label
            >
            <BaseInput
              v-model="ownerName"
              id="ownerName"
              placeholder="Ej. Juan Pérez"
            >
                <template #prefix>
                    <User :size="18" class="text-gray-400" />
                </template>
            </BaseInput>
            <p class="text-xs text-[#489d82] dark:text-gray-400 ml-1">
              Para dirigirnos a ti personalmente.
            </p>
          </div>
        </div>
      </section>

      <div class="h-px bg-[#cee9e0]/50 dark:bg-white/10 my-6 mx-5"></div>

      <!-- Section 2: Tus Credenciales -->
      <section class="px-5 animate-[fadeIn_0.4s_ease-out]">
        <h2 class="text-xl font-bold text-[#0d1c17] dark:text-white mb-4 flex items-center gap-2">
          <span
            class="bg-emerald-500/10 text-emerald-600 w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold"
            >2</span
          >
          Tus Credenciales
        </h2>
        <div class="space-y-5">
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1" for="email"
              >Correo Electrónico</label
            >
            <BaseInput
                v-model="email"
                type="email"
                id="email"
                placeholder="tucorreo@ejemplo.com"
            >
                <template #prefix>
                    <Mail :size="18" class="text-gray-400" />
                </template>
            </BaseInput>
            <p v-if="emailTypoWarning" class="text-xs text-amber-600 dark:text-amber-400 font-medium ml-1">
              {{ emailTypoWarning }}
            </p>
          </div>

          <div class="flex flex-col gap-1.5">
            <label
              class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
              for="password"
              >Contraseña</label
            >
            <div class="relative">
              <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400">
                <Lock :size="20" />
              </span>
              <input
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                id="password"
                autocomplete="off"
                class="w-full pl-11 pr-11 bg-white dark:bg-white/5 border rounded-xl px-4 py-3.5 text-base outline-none transition-all placeholder:text-gray-400 dark:placeholder:text-gray-500"
                :class="
                  password.length > 0 
                  ? isPasswordValid 
                    ? 'border-[#cee9e0] dark:border-white/10 focus:border-emerald-500 focus:ring-emerald-500' // Neutral/Valid
                    : 'border-red-400 focus:ring-red-400' // Invalid
                  : 'border-[#cee9e0] dark:border-white/10 focus:border-emerald-500 focus:ring-emerald-500' // Empty
                "
                placeholder="Mínimo 8 caracteres, letras y números"
              />
              <button
                type="button"
                @click="togglePassword"
                class="absolute right-0 top-0 bottom-0 px-4 flex items-center text-gray-400 hover:text-emerald-500 transition-colors focus:outline-none"
              >
                <component :is="showPassword ? Eye : EyeOff" :size="20" />
              </button>
               <span
                v-if="password.length > 0 && isPasswordValid"
                class="absolute right-10 top-1/2 -translate-y-1/2 text-emerald-500"
              >
                <CheckCircle2 :size="20" />
              </span>
            </div>
            <!-- Feedback msg -->
             <p
              v-if="password.length > 0 && !isPasswordValid"
              class="text-xs text-red-500 ml-1"
            >
              Debe tener min. 8 caracteres, 1 número y 1 letra.
            </p>
          </div>

          <!-- T-004: Campo Confirmar Contraseña -->
          <div class="flex flex-col gap-1.5">
            <label
              class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
              for="confirmPassword"
              >Confirmar Contraseña</label
            >
            <div class="relative">
              <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400">
                <Lock :size="20" />
              </span>
              <input
                v-model="confirmPassword"
                :type="showConfirmPassword ? 'text' : 'password'"
                id="confirmPassword"
                autocomplete="off"
                class="w-full pl-11 pr-11 bg-white dark:bg-white/5 border rounded-xl px-4 py-3.5 text-base outline-none transition-all placeholder:text-gray-400 dark:placeholder:text-gray-500"
                :class="
                  confirmPassword.length > 0
                    ? isConfirmPasswordValid
                      ? 'border-emerald-500 focus:ring-emerald-500'
                      : 'border-red-400 focus:ring-red-400'
                    : 'border-[#cee9e0] dark:border-white/10 focus:border-emerald-500 focus:ring-emerald-500'
                "
                placeholder="Repite tu contraseña"
              />
              <button
                type="button"
                @click="toggleConfirmPassword"
                class="absolute right-10 top-0 bottom-0 px-2 flex items-center text-gray-400 hover:text-emerald-500 transition-colors focus:outline-none"
              >
                <component :is="showConfirmPassword ? Eye : EyeOff" :size="20" />
              </button>
              <span
                v-if="confirmPassword.length > 0"
                class="absolute right-4 top-1/2 -translate-y-1/2 transition-opacity"
                :class="isConfirmPasswordValid ? 'text-emerald-500' : 'text-red-400'"
              >
                <component :is="isConfirmPasswordValid ? CheckCircle2 : CircleSlash" :size="20" />
              </span>
            </div>
            <p
              v-if="confirmPassword.length > 0 && !isConfirmPasswordValid"
              class="text-xs text-red-500 ml-1"
            >
              Las contraseñas no coinciden
            </p>
          </div>
        </div>
      </section>

      <!-- Legal Compliance Section (SDD-029: Doble casilla separada sin premarcado) -->
      <section class="px-5 mt-6 space-y-3" aria-label="Autorizaciones legales obligatorias">
        <!-- Skeleton mientras carga catálogo -->
        <div
          v-if="isLoadingLegal"
          class="p-4 rounded-xl border border-slate-200 dark:border-slate-700 bg-surface-light dark:bg-surface-dark space-y-3 animate-pulse"
        >
          <div class="h-4 bg-slate-200 dark:bg-slate-700 rounded w-3/4"></div>
          <div class="h-4 bg-slate-200 dark:bg-slate-700 rounded w-2/3"></div>
        </div>

        <!-- Error de carga legal (bloqueante, sin fallo silencioso) -->
        <div
          v-else-if="legalLoadError"
          role="alert"
          class="p-4 rounded-xl border border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-900/20 space-y-2.5"
        >
          <div class="flex items-start gap-2.5 text-sm text-red-800 dark:text-red-200">
            <AlertCircle :size="18" class="shrink-0 mt-0.5" />
            <span>{{ legalLoadError }}</span>
          </div>
          <button
            type="button"
            @click="loadLegalDocuments"
            class="inline-flex items-center gap-1.5 min-h-[40px] px-3 py-1.5 rounded-lg bg-red-600 hover:bg-red-700 text-white text-xs font-semibold active:scale-95 transition-all"
          >
            <RefreshCw :size="14" />
            Reintentar carga legal
          </button>
        </div>

        <!-- Casillas obligatorias v1/vN -->
        <div v-else-if="legalCatalog" class="space-y-2.5">
          <!-- Casilla 1: Términos y Condiciones -->
          <div class="flex items-start gap-3 p-3.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-surface-light dark:bg-surface-dark">
            <input
              id="accept-terms"
              v-model="acceptedTerms"
              type="checkbox"
              class="mt-0.5 w-5 h-5 text-primary border-slate-300 rounded focus:ring-primary bg-white shrink-0"
            />
            <div class="flex-1 text-sm leading-snug">
              <label for="accept-terms" class="font-medium text-slate-800 dark:text-slate-100 cursor-pointer">
                Acepto los
                <button
                  type="button"
                  @click="previewDoc = legalCatalog.terms_of_service"
                  class="text-primary font-semibold underline hover:text-primary-dark ml-0.5"
                >
                  Términos y Condiciones
                </button>
                <span class="tabular-money text-xs text-slate-500 dark:text-slate-400 ml-1.5">
                  (v{{ legalCatalog.terms_of_service.version_code }})
                </span>
              </label>
            </div>
          </div>

          <!-- Casilla 2: Política de Datos Personales -->
          <div class="flex items-start gap-3 p-3.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-surface-light dark:bg-surface-dark">
            <input
              id="accept-privacy"
              v-model="acceptedPrivacy"
              type="checkbox"
              class="mt-0.5 w-5 h-5 text-primary border-slate-300 rounded focus:ring-primary bg-white shrink-0"
            />
            <div class="flex-1 text-sm leading-snug">
              <label for="accept-privacy" class="font-medium text-slate-800 dark:text-slate-100 cursor-pointer">
                Autorizo la
                <button
                  type="button"
                  @click="previewDoc = legalCatalog.privacy_policy"
                  class="text-primary font-semibold underline hover:text-primary-dark ml-0.5"
                >
                  Política de Tratamiento de Datos Personales
                </button>
                <span class="tabular-money text-xs text-slate-500 dark:text-slate-400 ml-1.5">
                  (v{{ legalCatalog.privacy_policy.version_code }})
                </span>
              </label>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                Autorización libre, previa y expresa conforme a la Ley 1581 de 2012.
              </p>
            </div>
          </div>
        </div>
      </section>

      <!-- Inline error banner (Regla 3: nunca fallos silenciosos) -->
      <div v-if="errorMessage" role="alert" class="px-5 mt-4">
        <div class="p-3.5 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-sm text-red-700 dark:text-red-200 flex items-start gap-2">
          <AlertCircle :size="18" class="shrink-0 mt-0.5" />
          <span>{{ errorMessage }}</span>
        </div>
      </div>

      <!-- Submit Button -->
      <div class="w-full p-4 mt-4 max-w-lg mx-auto">
        <BaseButton
          @click="handleSubmit"
          :disabled="!canSubmit"
          :loading="isLoading"
          size="lg"
          variant="primary"
          class="w-full h-14 bg-primary hover:bg-primary-dark text-white"
        >
          <span>Abrir mi Tienda</span>
          <Store :size="20" class="ml-2" />
        </BaseButton>
      </div>
    </main>

    <!-- Lector completo sin salir del formulario (RN-03) -->
    <BaseModal
      :modelValue="Boolean(previewDoc)"
      :title="previewDoc?.document_type === 'terms_of_service' ? 'Términos y Condiciones' : 'Política de Tratamiento de Datos'"
      :showCloseButton="true"
      @update:modelValue="(v) => { if (!v) previewDoc = null; }"
    >
      <div v-if="previewDoc" class="p-5 space-y-3">
        <div class="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
          <span class="tabular-money font-semibold px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200 inline-flex items-center gap-1">
            <FileText :size="13" />
            Versión {{ previewDoc.version_code }}
          </span>
          <span class="tabular-money">
            {{ new Date(previewDoc.published_at).toLocaleDateString('es-CO') }}
          </span>
        </div>
        <div class="text-sm leading-relaxed text-slate-700 dark:text-slate-200 whitespace-pre-line border-t border-slate-200 dark:border-slate-700 pt-3">
          {{ previewDoc.content }}
        </div>
      </div>
      <template #footer>
        <div class="p-4 pt-2 border-t border-slate-100 dark:border-slate-700">
          <BaseButton variant="primary" class="w-full" @click="previewDoc = null">
            Entendido
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>

<style scoped>
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes popIn {
  from {
    transform: scale(0);
    opacity: 0;
  }

  to {
    transform: scale(1);
    opacity: 1;
  }
}
</style>
