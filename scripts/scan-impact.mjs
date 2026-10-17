#!/usr/bin/env node
/**
 * Ecógrafo Estructural de Radio de Impacto (Regla 10 - AGENTS.md)
 * Escanea en vivo las 4 capas del proyecto (RVC, SQL/Backend, Stores/UI Frontend, SDD/FRD)
 * y genera el sello criptográfico temporal en .git/.impact_scan_stamp para autorizar commits.
 *
 * Uso: node scripts/scan-impact.mjs <termino1> [termino2 ...]
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');

const args = process.argv.slice(2).map((a) => a.trim()).filter(Boolean);

if (args.length === 0 || args.some((a) => a.length < 2)) {
  console.error('================================================================');
  console.error('❌ ERROR DE INVOCACIÓN — ECÓGRAFO ESTRUCTURAL (REGLA 10)');
  console.error('================================================================');
  console.error('Debes proporcionar al menos un término válido (mínimo 2 caracteres):');
  console.error('tabla, columna, función RPC, trigger o store.');
  console.error('\nEjemplo de uso:');
  console.error('  node scripts/scan-impact.mjs supplier_invoices rpc_pay_supplier_invoice');
  console.error('================================================================');
  process.exit(1);
}

const termsLower = args.map((t) => t.toLowerCase());

/**
 * Recorre recursivamente un directorio devolviendo rutas absolutas filtradas por extensión
 */
function walkDir(dirPath, allowedExts) {
  if (!fs.existsSync(dirPath)) return [];
  const results = [];
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === 'node_modules' || entry.name === '.git' || entry.name === 'dist') continue;
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkDir(fullPath, allowedExts));
    } else if (allowedExts.some((ext) => entry.name.toLowerCase().endsWith(ext))) {
      results.push(fullPath);
    }
  }
  return results;
}

/**
 * Busca coincidencias línea por línea dentro de un archivo
 */
function scanFileLines(filePath) {
  if (!fs.existsSync(filePath)) return [];
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split(/\r?\n/);
  const matches = [];
  for (let i = 0; i < lines.length; i++) {
    const lineLower = lines[i].toLowerCase();
    if (termsLower.some((term) => lineLower.includes(term))) {
      matches.push({
        lineNumber: i + 1,
        text: lines[i].trim()
      });
    }
  }
  return matches;
}

console.log('========================================================================');
console.log(`🔬 ECOGRAFÍA ESTRUCTURAL EN VIVO — TÉRMINOS: [${args.join(', ')}]`);
console.log('========================================================================\n');

// ---------------------------------------------------------------------------
// EJE 1: CONTRATOS RVC BLOQUEANTES
// ---------------------------------------------------------------------------
const rvcPath = path.join(
  ROOT_DIR,
  'documentation',
  '01_requirements',
  'REGISTRO',
  'RVC_registro_vivo_contratos.md'
);
const rvcMatches = scanFileLines(rvcPath);

console.log('1️⃣  [EJE 1: CONTRATOS RVC BLOQUEANTES] (RVC_registro_vivo_contratos.md)');
if (rvcMatches.length === 0) {
  console.log('   ⚪ Sin filas directas en el RVC para este término.');
} else {
  for (const m of rvcMatches) {
    console.log(`   🔒 L${m.lineNumber}: ${m.text.slice(0, 140)}${m.text.length > 140 ? '...' : ''}`);
  }
}
console.log('');

// ---------------------------------------------------------------------------
// EJE 2: VECINOS BACKEND / SQL (supabase/migrations)
// ---------------------------------------------------------------------------
const migrationsDir = path.join(ROOT_DIR, 'supabase', 'migrations');
const sqlFiles = walkDir(migrationsDir, ['.sql']);
const sqlHits = [];

for (const file of sqlFiles) {
  const matches = scanFileLines(file);
  if (matches.length > 0) {
    sqlHits.push({
      relPath: path.relative(ROOT_DIR, file).replace(/\\/g, '/'),
      matches
    });
  }
}

console.log('2️⃣  [EJE 2: VECINOS BACKEND / SQL] (supabase/migrations/)');
if (sqlHits.length === 0) {
  console.log('   ⚪ Ninguna migración SQL referencia directamente este término.');
} else {
  for (const hit of sqlHits) {
    const lineNums = hit.matches.map((m) => `L${m.lineNumber}`).slice(0, 8).join(', ');
    const extra = hit.matches.length > 8 ? ` (+${hit.matches.length - 8} más)` : '';
    const sample = hit.matches.find((m) =>
      /create\s+|alter\s+|function\s+|trigger\s+|policy\s+/i.test(m.text)
    ) || hit.matches[0];
    console.log(`   🗄️  ${hit.relPath} [${lineNums}${extra}]`);
    console.log(`       ↳ Ejemplo (L${sample.lineNumber}): ${sample.text.slice(0, 110)}`);
  }
}
console.log('');

// ---------------------------------------------------------------------------
// EJE 3: CONSUMIDORES FRONTEND (frontend/src)
// ---------------------------------------------------------------------------
const frontendSrcDir = path.join(ROOT_DIR, 'frontend', 'src');
const frontendFiles = walkDir(frontendSrcDir, ['.ts', '.vue', '.js']);
const frontendHits = [];

for (const file of frontendFiles) {
  const matches = scanFileLines(file);
  if (matches.length > 0) {
    frontendHits.push({
      relPath: path.relative(ROOT_DIR, file).replace(/\\/g, '/'),
      matches
    });
  }
}

console.log('3️⃣  [EJE 3: CONSUMIDORES FRONTEND] (frontend/src/)');
if (frontendHits.length === 0) {
  console.log('   ⚪ Ningún archivo en frontend/src/ referencia directamente este término.');
} else {
  for (const hit of frontendHits) {
    const lineNums = hit.matches.map((m) => `L${m.lineNumber}`).slice(0, 8).join(', ');
    const extra = hit.matches.length > 8 ? ` (+${hit.matches.length - 8} más)` : '';
    const sample = hit.matches[0];
    console.log(`   📱 ${hit.relPath} [${lineNums}${extra}]`);
    console.log(`       ↳ L${sample.lineNumber}: ${sample.text.slice(0, 110)}`);
  }
}
console.log('');

// ---------------------------------------------------------------------------
// EJE 4: DOCUMENTOS DE DISEÑO (SDD / FRD)
// ---------------------------------------------------------------------------
const sddDir = path.join(ROOT_DIR, 'documentation', '01_requirements', 'SDD');
const frdDir = path.join(ROOT_DIR, 'documentation', '01_requirements', 'FRD');
const docFiles = [...walkDir(sddDir, ['.md']), ...walkDir(frdDir, ['.md'])];
const docHits = [];

for (const file of docFiles) {
  const matches = scanFileLines(file);
  if (matches.length > 0) {
    docHits.push({
      relPath: path.relative(ROOT_DIR, file).replace(/\\/g, '/'),
      count: matches.length,
      firstLine: matches[0].lineNumber
    });
  }
}

console.log('4️⃣  [EJE 4: DOCUMENTOS DE DISEÑO Y REGLAS] (SDD / FRD)');
if (docHits.length === 0) {
  console.log('   ⚪ Sin coincidencias directas en archivos SDD/FRD.');
} else {
  for (const hit of docHits.slice(0, 12)) {
    console.log(`   📐 ${hit.relPath} (${hit.count} menciones, primera en L${hit.firstLine})`);
  }
  if (docHits.length > 12) {
    console.log(`   ... y ${docHits.length - 12} documentos adicionales.`);
  }
}
console.log('');

// ---------------------------------------------------------------------------
// REGISTRO DE SELLO TEMPORAL (.git/.impact_scan_stamp)
// ---------------------------------------------------------------------------
const gitDir = path.join(ROOT_DIR, '.git');
if (fs.existsSync(gitDir)) {
  const stampPath = path.join(gitDir, '.impact_scan_stamp');
  let previousTerms = [];
  const now = Date.now();
  const EXPIRY_MS = 30 * 60 * 1000; // 30 minutos

  if (fs.existsSync(stampPath)) {
    try {
      const prev = JSON.parse(fs.readFileSync(stampPath, 'utf8'));
      if (prev.timestamp && now - prev.timestamp < EXPIRY_MS && Array.isArray(prev.scannedTerms)) {
        previousTerms = prev.scannedTerms;
      }
    } catch {
      previousTerms = [];
    }
  }

  const mergedTerms = Array.from(new Set([...previousTerms, ...args]));
  const stampPayload = {
    timestamp: now,
    isoDate: new Date(now).toISOString(),
    scannedTerms: mergedTerms,
    summary: {
      rvcMatches: rvcMatches.length,
      sqlFilesCount: sqlHits.length,
      frontendFilesCount: frontendHits.length,
      docFilesCount: docHits.length
    }
  };

  fs.writeFileSync(stampPath, JSON.stringify(stampPayload, null, 2), 'utf8');
}

console.log('========================================================================');
console.log('🚦 LÍMITES DE CONTENCIÓN ACTIVOS (REGLA 10 - FASE A & B)');
console.log('------------------------------------------------------------------------');
console.log('• [FASE A - Diagnóstico Mecánico]: Imprime en tu respuesta los 4 ejes');
console.log('  anteriores antes de editar. Cero suposiciones.');
console.log('• [Muro 1]: Si el problema nace en el dato/cálculo -> PROHIBIDO parchar en .vue/.ts.');
console.log('• [Muro 2]: Si cambias firma/payload -> OBLIGATORIO actualizar los ' + frontendHits.length + ' archivos Frontend');
console.log('  y ' + sqlHits.length + ' archivos SQL listados arriba.');
console.log('• [Muro 3]: PROHIBIDO silenciar errores con defaults (0, null, [], catch vacío).');
console.log('• [FASE B - Cancha Creativa]: Propón 2-3 caminos creativos dentro de estos muros.');
console.log('✅ Sello de escaneo registrado en .git/.impact_scan_stamp (válido por 30 min).');
console.log('========================================================================');
