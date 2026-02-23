<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { Users, AlertTriangle, ArrowRight, Clock } from 'lucide-vue-next';
import type { ClientLedgerSummary } from '../../stores/financial';

const props = defineProps<{
    ledger: ClientLedgerSummary | null;
    isLoading: boolean;
}>();

const router = useRouter();
const { formatCurrency } = useCurrencyFormat();

function goToClients() {
    router.push('/clients?filter=morosos');
}

const hasDebtors = computed(() => {
    return props.ledger && props.ledger.clientes_morosos > 0;
});
</script>

<template>
    <!-- Skeleton Loading -->
    <div v-if="isLoading" class="bg-white dark:bg-slate-800 p-5 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm animate-pulse">
        <div class="h-6 w-1/3 bg-slate-200 dark:bg-slate-700 rounded mb-4"></div>
        <div class="h-10 w-1/2 bg-slate-200 dark:bg-slate-700 rounded mb-6"></div>
        <div class="space-y-3">
            <div class="h-4 w-full bg-slate-200 dark:bg-slate-700 rounded"></div>
            <div class="h-4 w-5/6 bg-slate-200 dark:bg-slate-700 rounded"></div>
        </div>
    </div>

    <!-- Empty/No Data State -->
    <div v-else-if="!ledger" class="bg-slate-50 dark:bg-slate-800/50 p-5 rounded-2xl border border-slate-200 dark:border-slate-700 flex flex-col items-center justify-center text-center gap-3">
        <Users :size="32" class="text-slate-400" />
        <p class="text-sm text-slate-500 dark:text-slate-400">Datos de cartera no disponibles</p>
    </div>

    <!-- Active Widget -->
    <button
        v-else
        @click="goToClients"
        class="w-full text-left bg-white dark:bg-slate-800 p-5 rounded-2xl border transition-all active:scale-[0.98] shadow-sm hover:border-amber-300 dark:hover:border-amber-700"
        :class="hasDebtors ? 'border-amber-200 dark:border-amber-900/40' : 'border-slate-100 dark:border-slate-700'"
    >
        <div class="flex items-start justify-between mb-4">
            <div class="flex items-center gap-2">
                <div class="p-2 rounded-xl" :class="hasDebtors ? 'bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400' : 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400'">
                    <AlertTriangle v-if="hasDebtors" :size="20" />
                    <Users v-else :size="20" />
                </div>
                <div>
                    <h3 class="font-bold text-slate-900 dark:text-white">Fiado Vencido</h3>
                    <p class="text-xs text-slate-500 dark:text-slate-400">Cartera > 30 días</p>
                </div>
            </div>
            <ArrowRight :size="20" class="text-slate-400" />
        </div>

        <div class="mb-4">
            <p class="text-3xl font-black tracking-tight" :class="hasDebtors ? 'text-amber-600 dark:text-amber-400' : 'text-slate-900 dark:text-white'">
                $ {{ formatCurrency(ledger.cartera_vencida) }}
            </p>
            <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
                De <span class="font-bold">{{ ledger.cartera_total ? formatCurrency(ledger.cartera_total) : '0' }}</span> prestados en total
            </p>
        </div>

        <div v-if="hasDebtors" class="bg-amber-50 dark:bg-amber-900/20 rounded-xl p-3 border border-amber-100 dark:border-amber-900/40">
            <p class="text-xs font-semibold text-amber-800 dark:text-amber-300 mb-2 uppercase tracking-wide">
                {{ ledger.clientes_morosos }} Clientes Morosos
            </p>
            <div class="space-y-2">
                <div v-for="(client, idx) in ledger.top_deudores.slice(0, 3)" :key="client.client_id" class="flex justify-between items-center text-sm">
                    <span class="text-slate-700 dark:text-slate-300 truncate pr-2 max-w-[120px]">{{ client.client_name }}</span>
                    <div class="flex items-center gap-2 text-amber-700 dark:text-amber-400 font-medium">
                        <Clock :size="12" />
                        <span class="text-xs">{{ client.dias_sin_pagar }}d</span>
                        <span class="ml-1">${{ formatCurrency(client.balance) }}</span>
                    </div>
                </div>
            </div>
        </div>
        
        <div v-else class="bg-green-50 dark:bg-green-900/20 rounded-xl p-3 border border-green-100 dark:border-green-900/40 text-center">
            <p class="text-sm font-medium text-green-700 dark:text-green-400">
                ¡Cartera sana! No hay fiado retrasado.
            </p>
        </div>
    </button>
</template>
