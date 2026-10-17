#!/usr/bin/env node
/**
 * Verificador del Git Pre-Commit Hook — Ecógrafo Estructural (Regla 10)
 * Bloquea cualquier commit que modifique capas compartidas (SQL, Stores, Servicios, RVC)
 * si el agente no ejecutó previamente `node scripts/scan-impact.mjs <entidad>` en los últimos 30 min.
 */

import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');

const args = process.argv.slice(2);
const simulateIdx = args.indexOf('--simulate');
let stagedFiles = [];

if (simulateIdx !== -1 && args[simulateIdx + 1]) {
  stagedFiles = args.slice(simulateIdx + 1);
} else {
  try {
    const out = execSync('git diff --cached --name-only', {
      cwd: ROOT_DIR,
      encoding: 'utf8'
    });
    stagedFiles = out
      .split(/\r?\n/)
      .map((s) => s.trim())
      .filter(Boolean);
  } catch (err) {
    console.error('❌ [Ecógrafo Pre-Commit] Error al consultar git diff --cached:', err.message);
    process.exit(1);
  }
}

if (stagedFiles.length === 0) {
  process.exit(0);
}

// Patrones de capas compartidas que activan el Modo Quirúrgico de la Regla 10
const SHARED_PATTERNS = [
  /^supabase\/migrations\/.*\.sql$/i,
  /^frontend\/src\/stores\/.*\.(ts|js)$/i,
  /^frontend\/src\/services\/.*\.(ts|js)$/i,
  /^frontend\/src\/repositories\/.*\.(ts|js)$/i,
  /^frontend\/src\/composables\/.*\.(ts|js)$/i,
  /^frontend\/src\/data\/.*\.(ts|js)$/i,
  /^documentation\/01_requirements\/REGISTRO\/RVC_registro_vivo_contratos\.md$/i
];

const touchedSharedFiles = stagedFiles.filter((file) => {
  const normalized = file.replace(/\\/g, '/');
  return SHARED_PATTERNS.some((regex) => regex.test(normalized));
});

if (touchedSharedFiles.length === 0) {
  console.log(
    '🟢 [Ecógrafo Pre-Commit] Cambio local/cosmético sin alteración de contratos compartidos. Pase directo.'
  );
  process.exit(0);
}

const stampPath = path.join(ROOT_DIR, '.git', '.impact_scan_stamp');
const EXPIRY_MS = 30 * 60 * 1000; // 30 minutos
const now = Date.now();

let isValidStamp = false;
let stampData = null;

if (fs.existsSync(stampPath)) {
  try {
    stampData = JSON.parse(fs.readFileSync(stampPath, 'utf8'));
    if (
      stampData &&
      typeof stampData.timestamp === 'number' &&
      now - stampData.timestamp <= EXPIRY_MS &&
      Array.isArray(stampData.scannedTerms) &&
      stampData.scannedTerms.length > 0
    ) {
      isValidStamp = true;
    }
  } catch {
    isValidStamp = false;
  }
}

if (!isValidStamp) {
  console.error('========================================================================');
  console.error('❌ BLOQUEO DE ECOGRAFÍA ESTRUCTURAL (REGLA 10 - AGENTS.md)');
  console.error('========================================================================');
  console.error('Estás intentando hacer commit sobre archivos de capa compartida:');
  for (const f of touchedSharedFiles) {
    console.error(`  • ${f}`);
  }
  console.error('\nsin haber ejecutado el Ecógrafo de Radio de Impacto en los últimos 30 minutos.');
  console.error('\n👉 ACCIÓN OBLIGATORIA PARA DESBLOQUEAR:');
  console.error('   1. Ejecuta: node scripts/scan-impact.mjs <nombre_tabla_rpc_o_store>');
  console.error('   2. Revisa que tu solución no rompa los consumidores listados.');
  console.error('   3. Vuelve a ejecutar git commit.');
  console.error('========================================================================');
  process.exit(1);
}

const ageMinutes = Math.round((now - stampData.timestamp) / 60000);
console.log('========================================================================');
console.log('✅ [Ecógrafo Pre-Commit] Sello de impacto verificado.');
console.log(`   • Términos escaneados: [${stampData.scannedTerms.join(', ')}] (hace ${ageMinutes} min)`);
console.log(`   • Archivos compartidos validados: ${touchedSharedFiles.length}`);
console.log('========================================================================');
process.exit(0);
