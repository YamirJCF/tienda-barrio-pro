<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';

const router = useRouter();

// State
const email = ref('');
const isSuccess = ref(false);
const isLoading = ref(false);

// Methods
const handleSubmit = async () => {
    if (!email.value) return;

    isLoading.value = true;

    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1500));

    isLoading.value = false;
    isSuccess.value = true;

    console.log('Password recovery email sent to:', email.value);
};

const goBackToLogin = () => {
    router.push('/login');
};

const goToHome = () => {
    router.push('/login');
};
</script>

<template>
    <div class="bg-gray-50 dark:bg-background-dark min-h-screen flex flex-col items-center justify-center p-4">

        <!-- Input State Card -->
        <main v-if="!isSuccess"
            class="w-full max-w-md bg-white dark:bg-[#1a2632] rounded-xl shadow-xl border border-slate-100 dark:border-slate-800 overflow-hidden relative">
            <!-- Decorative top line -->
            <div class="h-1.5 w-full bg-primary"></div>

            <div class="p-6 sm:p-8 flex flex-col items-center text-center">
                <!-- Icon Container -->
                <div class="mb-6 flex items-center justify-center w-20 h-20 rounded-full bg-primary/10 text-primary">
                    <span class="material-symbols-outlined text-[40px]">lock_open</span>
                </div>

                <!-- Header Section -->
                <header class="mb-6">
                    <h1 class="text-2xl font-bold text-slate-900 dark:text-white mb-3 tracking-tight">
                        Recuperar Acceso
                    </h1>
                    <p class="text-slate-600 dark:text-slate-400 text-base font-normal leading-relaxed">
                        Ingresa el correo electrónico asociado a tu tienda. Te enviaremos un enlace seguro para
                        restablecer tu contraseña.
                    </p>
                </header>

                <!-- Form Section -->
                <form @submit.prevent="handleSubmit" class="w-full flex flex-col gap-5">
                    <!-- Email Input Field -->
                    <div class="text-left w-full">
                        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2 ml-1"
                            for="email">
                            Correo Electrónico
                        </label>
                        <div class="relative flex items-center group">
                            <!-- Icon -->
                            <div class="absolute left-4 text-primary pointer-events-none flex items-center">
                                <span class="material-symbols-outlined">mail</span>
                            </div>
                            <!-- Input -->
                            <input v-model="email" type="email" id="email" name="email" required
                                class="w-full h-14 pl-12 pr-4 rounded-xl border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all text-base outline-none"
                                placeholder="ejemplo@tienda.com" />
                        </div>
                    </div>

                    <!-- Primary Button -->
                    <button type="submit" :disabled="isLoading"
                        class="w-full h-12 mt-2 bg-primary hover:bg-primary-dark active:scale-[0.98] disabled:opacity-70 disabled:cursor-not-allowed text-white text-base font-bold rounded-xl shadow-md shadow-primary/20 transition-all duration-200 flex items-center justify-center gap-2">
                        <span v-if="isLoading"
                            class="material-symbols-outlined animate-spin text-[20px]">progress_activity</span>
                        <span v-else>Enviar Enlace de Recuperación</span>
                    </button>

                    <!-- Secondary Button -->
                    <button type="button" @click="goBackToLogin"
                        class="w-full py-2 text-slate-500 dark:text-slate-400 hover:text-primary dark:hover:text-primary font-medium text-sm transition-colors rounded-lg">
                        Volver al Login
                    </button>
                </form>
            </div>
        </main>

        <!-- Success State Card -->
        <section v-else
            class="w-full max-w-md bg-white dark:bg-[#1a2632] rounded-xl shadow-xl border border-slate-100 dark:border-slate-800 overflow-hidden relative animate-[fadeIn_0.3s_ease-out]">
            <div class="h-1.5 w-full bg-green-500"></div>

            <div class="p-6 sm:p-8 flex flex-col items-center text-center">
                <!-- Success Icon -->
                <div
                    class="mb-6 flex items-center justify-center w-20 h-20 rounded-full bg-green-50 dark:bg-green-900/20 text-green-500">
                    <span class="material-symbols-outlined text-[48px]">check_circle</span>
                </div>

                <!-- Success Message -->
                <div class="mb-8">
                    <h2 class="text-2xl font-bold text-slate-900 dark:text-white mb-3">
                        ¡Correo enviado!
                    </h2>
                    <p class="text-slate-600 dark:text-slate-400 text-base leading-relaxed">
                        Revisa tu bandeja de entrada (y spam) para continuar.
                    </p>
                </div>

                <!-- Back to Home Button -->
                <button @click="goToHome"
                    class="w-full h-12 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 text-slate-900 dark:text-white text-base font-bold rounded-xl transition-all duration-200">
                    Volver al inicio
                </button>
            </div>
        </section>
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
</style>
