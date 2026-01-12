<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const router = useRouter();
const authStore = useAuthStore();

// ============================================
// FORM STATE
// ============================================
const storeName = ref('');
const ownerName = ref('');
const email = ref('');
const password = ref('');
const pin = ref('');
const showPassword = ref(false);

// ============================================
// UI STATE
// ============================================
const errorMessage = ref('');
const isLoading = ref(false);

// ============================================
// VALIDATION RULES
// ============================================
// Regex para validación estricta de email
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Computed validations
const isStoreNameValid = computed(() => storeName.value.trim().length >= 3);
const isOwnerNameValid = computed(() => ownerName.value.trim().length > 0);
const isEmailValid = computed(() => emailRegex.test(email.value.trim()));
const isPasswordValid = computed(() => password.value.length >= 6);
// PIN: exactamente 6 dígitos numéricos
const isPinComplete = computed(() => /^\d{6}$/.test(pin.value));

// Botón habilitado solo si todo es válido y no está cargando
const canSubmit = computed(() => {
    return isStoreNameValid.value &&
        isOwnerNameValid.value &&
        isEmailValid.value &&
        isPasswordValid.value &&
        isPinComplete.value &&
        !isLoading.value;
});

// ============================================
// NAVIGATION METHODS
// ============================================
const goBack = () => {
    router.back();
};

// ============================================
// PIN KEYPAD HANDLERS
// ============================================
const handleKeypadPress = (num: string) => {
    if (pin.value.length < 6) {
        pin.value += num;
    }
};

const handleBackspace = () => {
    if (pin.value.length > 0) {
        pin.value = pin.value.slice(0, -1);
    }
};

// ============================================
// PASSWORD VISIBILITY TOGGLE
// ============================================
const togglePassword = () => {
    showPassword.value = !showPassword.value;
};

// ============================================
// FORM SUBMISSION (ASYNC + ERROR HANDLING)
// ============================================
const handleSubmit = async () => {
    // Guard clause: previene doble-click y envíos inválidos
    if (!canSubmit.value || isLoading.value) return;

    isLoading.value = true;
    errorMessage.value = '';

    try {
        // Espera artificial para:
        // 1. Dar feedback visual (spinner/loading state)
        // 2. Asegurar que localStorage complete la escritura antes de navegar
        await new Promise(resolve => setTimeout(resolve, 600));

        // Intentar registro en el store
        const result = authStore.registerStore({
            storeName: storeName.value.trim(),
            ownerName: ownerName.value.trim(),
            email: email.value.trim().toLowerCase(),
            password: password.value,
            pin: pin.value
        });

        if (result) {
            console.log('✅ Tienda registrada exitosamente:', result.storeName);
            // Redirección al Dashboard
            router.push('/');
        } else {
            // Email duplicado (único error conocido del store)
            errorMessage.value = 'Este correo electrónico ya está registrado.';
            isLoading.value = false;
        }
    } catch (error) {
        // Captura errores inesperados (quota de localStorage, etc.)
        console.error('❌ Error crítico en registro:', error);
        errorMessage.value = 'Error del sistema. Por favor, intenta nuevamente.';
        isLoading.value = false;
    }
};
</script>

<template>
    <div class="bg-[#f8fcfb] dark:bg-[#0f231d] min-h-screen text-[#0d1c17] dark:text-white font-display">
        <!-- Header -->
        <header
            class="sticky top-0 z-50 bg-[#f8fcfb]/95 dark:bg-[#0f231d]/95 backdrop-blur-sm border-b border-[#cee9e0]/30">
            <div class="flex items-center px-4 h-16 max-w-lg mx-auto">
                <button @click="goBack" aria-label="Volver"
                    class="flex items-center justify-center w-10 h-10 -ml-2 rounded-full active:bg-gray-100 dark:active:bg-white/10 text-[#0d1c17] dark:text-white transition-colors">
                    <span class="material-symbols-outlined text-2xl">arrow_back_ios_new</span>
                </button>
                <h1 class="flex-1 text-center text-lg font-bold tracking-tight pr-8">Registra tu Negocio</h1>
            </div>
        </header>

        <main class="flex flex-col w-full max-w-lg mx-auto pb-10">
            <!-- Section 1: Tu Negocio -->
            <section class="px-5 pt-6 animate-[fadeIn_0.3s_ease-out]">
                <h2 class="text-xl font-bold text-[#0d1c17] dark:text-white mb-4 flex items-center gap-2">
                    <span
                        class="bg-emerald-500/10 text-emerald-600 w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold">1</span>
                    Tu Negocio
                </h2>
                <div class="space-y-5">
                    <div class="flex flex-col gap-1.5">
                        <label class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
                            for="storeName">Nombre de la Tienda</label>
                        <div class="relative">
                            <input v-model="storeName" type="text" id="storeName"
                                class="w-full bg-white dark:bg-white/5 border border-[#cee9e0] dark:border-white/10 rounded-xl px-4 py-3.5 text-base outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all placeholder:text-gray-400 dark:placeholder:text-gray-500"
                                placeholder="Ej. Abastos La Estrella" />
                            <span v-if="isStoreNameValid"
                                class="absolute right-4 top-1/2 -translate-y-1/2 text-emerald-500 transition-opacity">
                                <span class="material-symbols-outlined">check_circle</span>
                            </span>
                        </div>
                        <p class="text-xs text-[#489d82] dark:text-gray-400 ml-1">Así aparecerá en tus recibos
                            digitales.</p>
                    </div>

                    <div class="flex flex-col gap-1.5">
                        <label class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
                            for="ownerName">Nombre del Dueño</label>
                        <input v-model="ownerName" type="text" id="ownerName"
                            class="w-full bg-white dark:bg-white/5 border border-[#cee9e0] dark:border-white/10 rounded-xl px-4 py-3.5 text-base outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all placeholder:text-gray-400 dark:placeholder:text-gray-500"
                            placeholder="Ej. Juan Pérez" />
                        <p class="text-xs text-[#489d82] dark:text-gray-400 ml-1">Para dirigirnos a ti personalmente.
                        </p>
                    </div>
                </div>
            </section>

            <div class="h-px bg-[#cee9e0]/50 dark:bg-white/10 my-6 mx-5"></div>

            <!-- Section 2: Tus Credenciales -->
            <section class="px-5 animate-[fadeIn_0.4s_ease-out]">
                <h2 class="text-xl font-bold text-[#0d1c17] dark:text-white mb-4 flex items-center gap-2">
                    <span
                        class="bg-emerald-500/10 text-emerald-600 w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold">2</span>
                    Tus Credenciales
                </h2>
                <div class="space-y-5">
                    <div class="flex flex-col gap-1.5">
                        <label class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1" for="email">Correo
                            Electrónico</label>
                        <div class="relative">
                            <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400">
                                <span class="material-symbols-outlined text-xl">mail</span>
                            </span>
                            <input v-model="email" type="email" id="email"
                                class="w-full pl-11 bg-white dark:bg-white/5 border border-[#cee9e0] dark:border-white/10 rounded-xl px-4 py-3.5 text-base outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all placeholder:text-gray-400 dark:placeholder:text-gray-500"
                                placeholder="tucorreo@ejemplo.com" />
                        </div>
                    </div>

                    <div class="flex flex-col gap-1.5">
                        <label class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
                            for="password">Contraseña</label>
                        <div class="relative">
                            <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400">
                                <span class="material-symbols-outlined text-xl">lock</span>
                            </span>
                            <input v-model="password" :type="showPassword ? 'text' : 'password'" id="password"
                                class="w-full pl-11 pr-11 bg-white dark:bg-white/5 border border-[#cee9e0] dark:border-white/10 rounded-xl px-4 py-3.5 text-base outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all placeholder:text-gray-400 dark:placeholder:text-gray-500"
                                placeholder="Mínimo 6 caracteres" />
                            <button type="button" @click="togglePassword"
                                class="absolute right-0 top-0 bottom-0 px-4 flex items-center text-gray-400 hover:text-emerald-500 transition-colors focus:outline-none">
                                <span class="material-symbols-outlined text-xl">{{ showPassword ? 'visibility_off' :
                                    'visibility' }}</span>
                            </button>
                        </div>
                    </div>
                </div>
            </section>

            <div class="h-px bg-[#cee9e0]/50 dark:bg-white/10 my-6 mx-5"></div>

            <!-- Section 3: Seguridad (PIN) -->
            <section class="px-5 mb-8 animate-[fadeIn_0.5s_ease-out]">
                <h2 class="text-xl font-bold text-[#0d1c17] dark:text-white mb-2 flex items-center gap-2">
                    <span
                        class="bg-emerald-500/10 text-emerald-600 w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold">3</span>
                    Seguridad
                </h2>
                <p class="text-sm text-[#0d1c17]/80 dark:text-gray-300 mb-6 leading-relaxed">
                    Crea un <span class="font-bold text-emerald-600">PIN de 6 dígitos</span>. Esta será tu llave rápida
                    para abrir la tienda todos los días.
                </p>

                <!-- PIN Display -->
                <div class="flex justify-between max-w-[320px] mx-auto mb-8 gap-2" id="pinDisplay">
                    <div v-for="i in 6" :key="i"
                        class="w-10 h-14 sm:w-12 sm:h-14 rounded-lg border-2 border-[#cee9e0] dark:border-white/20 bg-white dark:bg-white/5 flex items-center justify-center transition-all duration-200"
                        :class="{ 'border-emerald-500 ring-2 ring-emerald-500/20': pin.length === i - 1 }">
                        <div v-if="pin.length >= i"
                            class="w-3 h-3 rounded-full bg-emerald-500 animate-[popIn_0.2s_cubic-bezier(0.175,0.885,0.32,1.275)]">
                        </div>
                    </div>
                </div>

                <!-- Keypad -->
                <div
                    class="bg-gray-50 dark:bg-white/5 rounded-2xl p-4 max-w-[340px] mx-auto shadow-inner border border-[#cee9e0]/30 dark:border-white/5">
                    <div class="grid grid-cols-3 gap-3">
                        <button v-for="num in ['1', '2', '3', '4', '5', '6', '7', '8', '9']" :key="num"
                            @click="handleKeypadPress(num)"
                            class="keypad-btn h-14 rounded-xl bg-white dark:bg-gray-800 shadow-sm border border-gray-100 dark:border-white/5 text-xl font-medium text-[#0d1c17] dark:text-white flex items-center justify-center transition-transform touch-manipulation select-none active:bg-emerald-500/10 active:scale-95">
                            {{ num }}
                        </button>
                        <!-- Empty space -->
                        <div class="h-14"></div>
                        <!-- 0 -->
                        <button @click="handleKeypadPress('0')"
                            class="keypad-btn h-14 rounded-xl bg-white dark:bg-gray-800 shadow-sm border border-gray-100 dark:border-white/5 text-xl font-medium text-[#0d1c17] dark:text-white flex items-center justify-center transition-transform touch-manipulation select-none active:bg-emerald-500/10 active:scale-95">
                            0
                        </button>
                        <!-- Backspace -->
                        <button @click="handleBackspace"
                            class="keypad-btn h-14 rounded-xl bg-transparent text-gray-500 dark:text-gray-400 flex items-center justify-center transition-transform touch-manipulation select-none active:scale-95">
                            <span class="material-symbols-outlined text-2xl">backspace</span>
                        </button>
                    </div>
                </div>
            </section>

            <!-- Submit Button -->
            <div class="w-full p-4 mt-4 max-w-lg mx-auto">
                <button @click="handleSubmit" :disabled="!canSubmit"
                    class="w-full h-14 bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 disabled:bg-gray-300 disabled:cursor-not-allowed text-white rounded-xl text-lg font-bold shadow-lg shadow-emerald-600/30 disabled:shadow-none transition-all transform active:scale-[0.98] flex items-center justify-center gap-2">
                    <span>Abrir mi Tienda</span>
                    <span class="material-symbols-outlined text-xl">storefront</span>
                </button>
                <p class="text-xs text-center text-[#489d82] mt-3">
                    Al crear la cuenta aceptas los <a class="underline hover:text-emerald-600" href="#">términos de
                        servicio</a>.
                </p>
            </div>
        </main>
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
