<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { Users, AlertTriangle, ArrowRight, Clock, ChevronRight } from 'lucide-vue-next';
import type { ClientLedgerSummary } from '../../stores/financial';

const props = defineProps<{
    ledger: ClientLedgerSummary | null;
    isLoading: boolean;
}>();

const router = useRouter();
const { formatWithSign } = useCurrencyFormat();

function goToClients() {
    router.push({ path: '/clients', query: { debt: 'with_debt' } });
}

function goToClientDetail(clientId: string) {
    if (!clientId) return;
    router.push(`/clients/${clientId}`);
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
    <div
        v-else
        class="w-full text-left bg-white dark:bg-slate-800 p-5 rounded-2xl border shadow-sm transition-colors"
        :class="hasDebtors ? 'border-amber-200 dark:border-amber-900/40' : 'border-slate-100 dark:border-slate-700'"
    >
        <button
            type="button"
            data-testid="ledger-clients-link"
            @click="goToClients"
            class="w-full text-left flex items-start justify-between mb-4 group cursor-pointer"
        >
            <div class="flex items-center gap-2">
                <div class="p-2 rounded-xl" :class="hasDebtors ? 'bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400' : 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400'">
                    <AlertTriangle v-if="hasDebtors" :size="20" />
                    <Users v-else :size="20" />
                </div>
                <div>
                    <h3 class="font-bold text-slate-900 dark:text-white group-hover:text-primary transition-colors">Fiado Vencido</h3>
                    <p class="text-xs text-slate-500 dark:text-slate-400">Cartera &gt; 30 días</p>
                </div>
            </div>
            <span class="inline-flex items-center gap-1 text-xs font-semibold text-slate-500 dark:text-slate-400 group-hover:text-primary transition-colors">
                Ver cartera
                <ArrowRight :size="16" />
            </span>
        </button>

        <div class="mb-4">
            <p class="text-3xl font-black font-mono tabular-nums tracking-tight" :class="hasDebtors ? 'text-amber-600 dark:text-amber-400' : 'text-slate-900 dark:text-white'">
                {{ formatWithSign(ledger.cartera_vencida) }}
            </p>
            <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
                De <span class="font-bold font-mono tabular-nums text-slate-700 dark:text-slate-200">{{ formatWithSign(ledger.cartera_total || 0) }}</span> prestados en total
            </p>
        </div>

        <div v-if="hasDebtors" class="bg-amber-50 dark:bg-amber-900/20 rounded-xl p-3 border border-amber-100 dark:border-amber-900/40">
            <p class="text-xs font-semibold text-amber-800 dark:text-amber-300 mb-2 uppercase tracking-wide">
                {{ ledger.clientes_morosos }} Clientes Morosos
            </p>
            <div class="space-y-1.5">
                <button
                    v-for="client in ledger.top_deudores.slice(0, 3)"
                    :key="client.client_id"
                    type="button"
                    data-testid="ledger-debtor-link"
                    @click="goToClientDetail(client.client_id)"
                    class="w-full flex justify-between items-center text-sm px-2 py-1.5 rounded-lg hover:bg-amber-100/70 dark:hover:bg-amber-900/40 transition-colors cursor-pointer text-left"
                >
                    <span class="text-slate-800 dark:text-slate-200 font-medium truncate pr-2 max-w-[140px]">{{ client.client_name }}</span>
                    <div class="flex items-center gap-2 text-amber-700 dark:text-amber-400 font-medium font-mono tabular-nums shrink-0">
                        <Clock :size="12" />
                        <span class="text-xs">{{ client.dias_sin_pagar }}d</span>
                        <span class="ml-1 font-bold">{{ formatWithSign(client.balance) }}</span>
                        <ChevronRight :size="14" class="opacity-70" />
                    </div>
                </button>
            </div>
        </div>
        
        <div v-else class="bg-green-50 dark:bg-green-900/20 rounded-xl p-3 border border-green-100 dark:border-green-900/40 text-center">
            <p class="text-sm font-medium text-green-700 dark:text-green-400">
                Cartera sana. No hay fiado retrasado.
            </p>
        </div>
    </div>
</template>
