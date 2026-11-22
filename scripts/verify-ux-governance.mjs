#!/usr/bin/env node
/**
 * Verificador de Gobernanza UX en 5 Anillos (WO-UX-GOV-000 / Regla 12)
 *
 * Modos de ejecución:
 *   node scripts/verify-ux-governance.mjs --pre-commit
 *   node scripts/verify-ux-governance.mjs --commit-msg <archivo_mensaje>
 *   node scripts/verify-ux-governance.mjs --ci [--base origin/master]
 *   node scripts/verify-ux-governance.mjs --simulate --files <csv> [--msg "<texto>"] [--adr-valid true|false] [--debt-increased true|false]
 */

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');

const EMPTY_TREE_SHA = '4b825dc642cb6eb9a060e54bf8d69288fbee4904';

const MANIFEST_PATH = 'documentation/03_ui_ux_design/ux-manifest.json';
const ARCH_DOC_PATH = 'documentation/03_ui_ux_design/UX_ARQUITECTURA_SISTEMA.md';
const ADR_LOG_PATH = 'documentation/03_ui_ux_design/UX_ADR_LOG.md';
const FITNESS_TEST_PATH = 'frontend/src/__tests__/architecture/ux-fitness.spec.ts';

const GOVERNANCE_UX_FILES = new Set([MANIFEST_PATH, ARCH_DOC_PATH]);

const GUARDRAIL_EXACT_FILES = new Set([
  FITNESS_TEST_PATH,
  'scripts/verify-ux-governance.mjs',
  'scripts/verify-impact-hook.mjs',
  '.github/workflows/architecture-guard.yml',
  '.github/CODEOWNERS',
  '.agent/LOCKFILE.md',
  '.agent/AGENTS.md',
]);

const HIGH_FRICTION_PRODUCT_EXACT = new Set([
  'frontend/src/router/index.ts',
  'frontend/src/App.vue',
  'frontend/src/components/BottomNav.vue',
]);

const WEAKENING_TEST_PATTERNS = [
  /(?:\.skip|\.only|\.todo)\s*\(/,
  /\bxit\s*\(/,
  /\bxdescribe\s*\(/,
];

function normalizePath(p) {
  return p.replace(/\\/g, '/').trim();
}

function isGovernanceUx(file) {
  return GOVERNANCE_UX_FILES.has(file);
}

function isGuardrailOrLockfile(file) {
  return GUARDRAIL_EXACT_FILES.has(file) || file.startsWith('.githooks/');
}

function isProductCode(file) {
  if (file.startsWith('frontend/src/__tests__/')) return false;
  if (file === 'frontend/src/App.vue') return true;
  return (
    file.startsWith('frontend/src/views/') ||
    file.startsWith('frontend/src/components/') ||
    file.startsWith('frontend/src/stores/') ||
    file.startsWith('frontend/src/composables/') ||
    file.startsWith('frontend/src/data/') ||
    file.startsWith('frontend/src/router/')
  );
}

function isHighFrictionProduct(file, status) {
  if (HIGH_FRICTION_PRODUCT_EXACT.has(file)) return true;
  if (file.startsWith('frontend/src/views/') && (status === 'A' || status === 'D' || status === 'R')) {
    return true;
  }
  return false;
}

function runGit(args, allowFailure = false) {
  try {
    return execFileSync('git', args, {
      cwd: ROOT_DIR,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (err) {
    if (allowFailure) return null;
    throw new Error(`git ${args.join(' ')} falló: ${err.stderr || err.message}`);
  }
}

function gitFileExistsAtRef(ref, repoPath) {
  try {
    execFileSync('git', ['cat-file', '-e', `${ref}:${repoPath}`], {
      cwd: ROOT_DIR,
      stdio: 'ignore',
    });
    return true;
  } catch {
    return false;
  }
}

function gitReadFileAtRef(ref, repoPath) {
  return runGit(['show', `${ref}:${repoPath}`], true);
}

function gitReadStagedFile(repoPath) {
  return runGit(['show', `:${repoPath}`], true);
}

function parseNameStatus(output) {
  if (!output) return [];
  return output
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const parts = line.split(/\t+/);
      const status = parts[0]?.[0] || 'M';
      const file = normalizePath(parts[parts.length - 1] || '');
      return { status, file };
    })
    .filter((entry) => entry.file.length > 0);
}

function validateAdrAddedLines(addedText) {
  const errors = [];
  const adrHeadingMatch = addedText.match(/^##\s+(UX-ADR-\d{3,})\b/m);
  if (!adrHeadingMatch || adrHeadingMatch.index === undefined) {
    errors.push(
      `Debe agregarse una nueva entrada '## UX-ADR-XXX: ...' en ${ADR_LOG_PATH}.`
    );
    return errors;
  }

  const adrBody = addedText.slice(adrHeadingMatch.index);

  const requiredSections = [
    { label: '### 1. Contexto y Objeto (ORCA)', regex: /^###\s+1\.\s+Contexto y Objeto\b/im },
    { label: '### 2. Verdad Contable (Read Model / Invariante)', regex: /^###\s+2\.\s+Verdad Contable\b/im },
    { label: '### 3. Arquetipo, Señalización y Top Tasks', regex: /^###\s+3\.\s+Arquetipo\b/im },
    { label: '### 4. Higiene de Crecimiento (Qué se consolida o elimina)', regex: /^###\s+4\.\s+Higiene de Crecimiento\b/im },
  ];

  for (const sec of requiredSections) {
    if (!sec.regex.test(adrBody)) {
      errors.push(`Falta la sección obligatoria '${sec.label}' del Gate UX-0 en el nuevo UX-ADR.`);
    }
  }

  return errors;
}

function extractAddedLinesFromDiff(diffText) {
  if (!diffText) return '';
  return diffText
    .split(/\r?\n/)
    .filter((line) => line.startsWith('+') && !line.startsWith('+++'))
    .map((line) => line.slice(1))
    .join('\n');
}

function checkBaselineDebtMonotonicity(baseManifestRaw, newManifestRaw) {
  const errors = [];
  let newManifest;
  try {
    newManifest = JSON.parse(newManifestRaw);
  } catch (err) {
    return [`${MANIFEST_PATH} no contiene JSON válido: ${err.message}`];
  }

  if (!baseManifestRaw) {
    if (newManifest.adrVersion !== 'UX-ADR-000') {
      errors.push(
        `La creación inicial de ${MANIFEST_PATH} solo se permite con adrVersion === "UX-ADR-000".`
      );
    }
    return errors;
  }

  let baseManifest;
  try {
    baseManifest = JSON.parse(baseManifestRaw);
  } catch {
    return [`La versión base de ${MANIFEST_PATH} no es JSON válido.`];
  }

  const baseDebt = baseManifest.baselineDebt || {};
  const newDebt = newManifest.baselineDebt || {};

  for (const [key, value] of Object.entries(newDebt)) {
    if (!(key in baseDebt)) {
      errors.push(`Prohibido crear nuevas categorías en baselineDebt ('${key}').`);
      continue;
    }
    if (!Array.isArray(value) || !Array.isArray(baseDebt[key])) {
      errors.push(`baselineDebt.${key} debe ser un array.`);
      continue;
    }
    const baseSet = new Set(baseDebt[key]);
    const addedItems = value.filter((item) => !baseSet.has(item));
    if (addedItems.length > 0) {
      errors.push(
        `Prohibido aumentar baselineDebt.${key}. Elementos nuevos rechazados: ${addedItems.join(', ')}`
      );
    }
  }

  return errors;
}

function checkFitnessNotWeakened(content, status) {
  if (status === 'D' || content === null) {
    return [`Prohibido eliminar ${FITNESS_TEST_PATH}.`];
  }
  const errors = [];
  for (const pattern of WEAKENING_TEST_PATTERNS) {
    if (pattern.test(content)) {
      errors.push(
        `Prohibido debilitar ${FITNESS_TEST_PATH} con ${pattern.toString()} (.skip/.only/.todo/xit/xdescribe).`
      );
    }
  }
  return errors;
}

function runFitnessSuite() {
  const vitestEntry = path.join(ROOT_DIR, 'frontend', 'node_modules', 'vitest', 'vitest.mjs');
  if (!fs.existsSync(vitestEntry)) {
    throw new Error(`No se encontró Vitest en ${vitestEntry}. Ejecuta npm ci en frontend/.`);
  }
  execFileSync(
    process.execPath,
    [vitestEntry, 'run', 'src/__tests__/architecture/ux-fitness.spec.ts'],
    {
      cwd: path.join(ROOT_DIR, 'frontend'),
      stdio: 'inherit',
    }
  );
}

function evaluateChangeSet({
  entries,
  commitMessage = null,
  checkCommitMsg = false,
  adrAddedText = null,
  adrLogContent = null,
  baseManifestRaw = null,
  newManifestRaw = null,
  manifestExistedInBase = false,
  fitnessContent = null,
  fitnessStatus = 'M',
}) {
  const errors = [];
  const warnings = [];

  const govFiles = entries.filter((e) => isGovernanceUx(e.file));
  const guardFiles = entries.filter((e) => isGuardrailOrLockfile(e.file));
  const productFiles = entries.filter((e) => isProductCode(e.file));
  const highFrictionProduct = entries.filter((e) => isHighFrictionProduct(e.file, e.status));
  const touchesGovernanceOrGuard = govFiles.length > 0 || guardFiles.length > 0;

  // Regla 1: Prohibido mezclar gobernanza/guardarraíles con código de producto
  if (touchesGovernanceOrGuard && productFiles.length > 0) {
    errors.push(
      [
        'REGLA 1 (Separación Obligatoria): Prohibido mezclar cambios de Gobernanza UX / Guardarraíles con Código de Producto en el mismo commit.',
        `  • Gobernanza/Guardarraíles: ${[...govFiles, ...guardFiles].map((e) => e.file).join(', ')}`,
        `  • Código de Producto: ${productFiles.map((e) => e.file).join(', ')}`,
        '  👉 Separa en 2 commits: (1) arch(ux) [UX-ARCH-APPROVED] y luego (2) feat/refactor de producto.',
      ].join('\n')
    );
  }

  // Regla 2: Todo cambio a ux-manifest.json o UX_ARQUITECTURA_SISTEMA.md exige UX-ADR-XXX completo + [UX-ARCH-APPROVED]
  if (govFiles.length > 0) {
    const adrTouched = entries.some((e) => e.file === ADR_LOG_PATH);
    if (!adrTouched) {
      errors.push(
        `REGLA 2: Modificaste ${govFiles.map((e) => e.file).join(', ')} sin agregar una entrada UX-ADR-XXX en ${ADR_LOG_PATH}.`
      );
    } else if (adrAddedText !== null) {
      const adrErrors = validateAdrAddedLines(adrAddedText);
      for (const ae of adrErrors) errors.push(`REGLA 2: ${ae}`);
    }

    if (newManifestRaw !== null) {
      try {
        const parsed = JSON.parse(newManifestRaw);
        if (adrLogContent !== null && parsed.adrVersion) {
          const versionHeading = new RegExp(`^##\\s+${parsed.adrVersion}\\b`, 'm');
          if (!versionHeading.test(adrLogContent)) {
            errors.push(
              `REGLA 2: adrVersion "${parsed.adrVersion}" en ${MANIFEST_PATH} no existe como '## ${parsed.adrVersion}' en ${ADR_LOG_PATH}.`
            );
          }
        }
      } catch (err) {
        errors.push(`REGLA 2: ${MANIFEST_PATH} no es JSON válido (${err.message}).`);
      }
    }

    if (checkCommitMsg) {
      if (!commitMessage || !commitMessage.includes('[UX-ARCH-APPROVED]')) {
        errors.push(
          'REGLA 2: Todo commit que modifique la Zona de Gobernanza UX debe incluir [UX-ARCH-APPROVED] en el mensaje.'
        );
      }
    }
  }

  // Regla 3: Integridad de Guardarraíles, Lockfile y Monotonicidad de baselineDebt
  const manifestTouched = entries.some((e) => e.file === MANIFEST_PATH);
  if (manifestTouched && newManifestRaw !== null) {
    const debtErrors = checkBaselineDebtMonotonicity(
      manifestExistedInBase ? baseManifestRaw : null,
      newManifestRaw
    );
    for (const de of debtErrors) errors.push(`REGLA 3: ${de}`);

    if (!manifestExistedInBase && checkCommitMsg) {
      if (!commitMessage || !commitMessage.includes('[LOCKFILE-APPROVED]')) {
        errors.push(
          'REGLA 3: La creación inicial de ux-manifest.json con baselineDebt requiere [LOCKFILE-APPROVED] en el mensaje.'
        );
      }
    }
  }

  if (guardFiles.length > 0 && checkCommitMsg) {
    if (!commitMessage || !commitMessage.includes('[LOCKFILE-APPROVED]')) {
      errors.push(
        `REGLA 3: Tocaste Zona de Guardarraíles/Lockfile (${guardFiles.map((e) => e.file).join(', ')}) sin [LOCKFILE-APPROVED] en el mensaje de commit.`
      );
    }
  }

  const fitnessTouched = entries.some((e) => e.file === FITNESS_TEST_PATH);
  if (fitnessTouched && (fitnessContent !== null || fitnessStatus === 'D')) {
    const fitErrors = checkFitnessNotWeakened(fitnessContent, fitnessStatus);
    for (const fe of fitErrors) errors.push(`REGLA 3: ${fe}`);
  }

  // Regla 4: Aviso en Zona de Alta Fricción de Producto
  if (highFrictionProduct.length > 0) {
    warnings.push(
      `REGLA 4: Cambio en Zona de Alta Fricción de Producto (${highFrictionProduct.map((e) => `${e.status}:${e.file}`).join(', ')}). Debe coincidir 1:1 con ${MANIFEST_PATH} previamente aprobado.`
    );
  }

  return { errors, warnings, govFiles, guardFiles, productFiles, highFrictionProduct };
}

function handlePreCommit() {
  const raw = runGit(['diff', '--cached', '--name-status', '--no-renames']);
  const entries = parseNameStatus(raw);
  if (entries.length === 0) {
    process.exit(0);
  }

  const headExists = runGit(['rev-parse', '--verify', 'HEAD'], true) !== null;
  const manifestExistedInBase = headExists && gitFileExistsAtRef('HEAD', MANIFEST_PATH);
  const baseManifestRaw = manifestExistedInBase ? gitReadFileAtRef('HEAD', MANIFEST_PATH) : null;
  const newManifestRaw = entries.some((e) => e.file === MANIFEST_PATH)
    ? gitReadStagedFile(MANIFEST_PATH)
    : null;

  const adrTouched = entries.some((e) => e.file === ADR_LOG_PATH);
  const adrDiff = adrTouched
    ? runGit(['diff', '--cached', '--no-renames', '-U0', '--', ADR_LOG_PATH], true)
    : null;
  const adrAddedText = adrTouched ? extractAddedLinesFromDiff(adrDiff) : null;
  const adrLogContent = adrTouched ? gitReadStagedFile(ADR_LOG_PATH) : null;

  const fitnessEntry = entries.find((e) => e.file === FITNESS_TEST_PATH);
  const fitnessContent = fitnessEntry && fitnessEntry.status !== 'D'
    ? gitReadStagedFile(FITNESS_TEST_PATH)
    : null;

  const result = evaluateChangeSet({
    entries,
    checkCommitMsg: false,
    adrAddedText,
    adrLogContent,
    baseManifestRaw,
    newManifestRaw,
    manifestExistedInBase,
    fitnessContent,
    fitnessStatus: fitnessEntry?.status || 'M',
  });

  for (const w of result.warnings) console.warn(`⚠️  ${w}`);

  if (result.errors.length > 0) {
    console.error('========================================================================');
    console.error('❌ BLOQUEO DE GOBERNANZA UX (pre-commit)');
    console.error('========================================================================');
    for (const err of result.errors) console.error(`\n${err}`);
    console.error('========================================================================');
    process.exit(1);
  }

  // Si toca código frontend/src o ux-fitness.spec.ts, ejecutar fitness suite obligatoria
  const touchesFrontendSrc = entries.some((e) => e.file.startsWith('frontend/src/'));
  const touchesFitness = Boolean(fitnessEntry);
  if (touchesFrontendSrc || touchesFitness) {
    console.log('🧪 [UX-Gov pre-commit] Ejecutando Architectural Fitness Functions (ux-fitness.spec.ts)...');
    try {
      runFitnessSuite();
    } catch {
      console.error('❌ [UX-Gov pre-commit] Fallaron las Architectural Fitness Functions.');
      process.exit(1);
    }
  } else if (result.govFiles.length > 0) {
    console.log(
      'ℹ️  [UX-Gov pre-commit] Commit exclusivo de Gobernanza UX (Commit 1). La paridad 1:1 completa se validará en Commit 2 y en GitHub CI.'
    );
  }

  console.log('✅ [UX-Gov pre-commit] Validación de gobernanza UX aprobada.');
  process.exit(0);
}

function handleCommitMsg(msgFilePath) {
  if (!msgFilePath || !fs.existsSync(msgFilePath)) {
    console.error('❌ [UX-Gov commit-msg] No se recibió archivo de mensaje de commit válido.');
    process.exit(1);
  }
  const commitMessage = fs.readFileSync(msgFilePath, 'utf8');
  const raw = runGit(['diff', '--cached', '--name-status', '--no-renames']);
  const entries = parseNameStatus(raw);
  if (entries.length === 0) process.exit(0);

  const headExists = runGit(['rev-parse', '--verify', 'HEAD'], true) !== null;
  const manifestExistedInBase = headExists && gitFileExistsAtRef('HEAD', MANIFEST_PATH);
  const baseManifestRaw = manifestExistedInBase ? gitReadFileAtRef('HEAD', MANIFEST_PATH) : null;
  const newManifestRaw = entries.some((e) => e.file === MANIFEST_PATH)
    ? gitReadStagedFile(MANIFEST_PATH)
    : null;

  const result = evaluateChangeSet({
    entries,
    commitMessage,
    checkCommitMsg: true,
    baseManifestRaw,
    newManifestRaw,
    manifestExistedInBase,
  });

  if (result.errors.length > 0) {
    console.error('========================================================================');
    console.error('❌ BLOQUEO DE GOBERNANZA UX (commit-msg)');
    console.error('========================================================================');
    for (const err of result.errors) console.error(`\n${err}`);
    console.error('========================================================================');
    process.exit(1);
  }

  console.log('✅ [UX-Gov commit-msg] Marcadores de aprobación verificados.');
  process.exit(0);
}

function handleCi(baseRef) {
  const resolvedBase = runGit(['rev-parse', '--verify', baseRef], true)?.trim();
  if (!resolvedBase) {
    console.error(`❌ [UX-Gov CI] No se encontró la referencia base '${baseRef}'.`);
    process.exit(1);
  }

  const commitsRaw = runGit(['rev-list', '--no-merges', '--reverse', `${resolvedBase}..HEAD`]);
  const commits = commitsRaw
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter(Boolean);

  if (commits.length === 0) {
    console.log(`ℹ️  [UX-Gov CI] Sin commits nuevos entre ${baseRef} y HEAD.`);
    process.exit(0);
  }

  const allErrors = [];

  for (const sha of commits) {
    const parentCheck = runGit(['rev-parse', '--verify', `${sha}^`], true);
    const parentRef = parentCheck ? `${sha}^` : EMPTY_TREE_SHA;
    const diffNameRaw = runGit(['diff', '--name-status', '--no-renames', parentRef, sha]);
    const entries = parseNameStatus(diffNameRaw);
    const commitMessage = runGit(['log', '-1', '--format=%B', sha]);

    const manifestExistedInBase = parentCheck
      ? gitFileExistsAtRef(parentRef, MANIFEST_PATH)
      : false;
    const baseManifestRaw = manifestExistedInBase ? gitReadFileAtRef(parentRef, MANIFEST_PATH) : null;
    const newManifestRaw = entries.some((e) => e.file === MANIFEST_PATH)
      ? gitReadFileAtRef(sha, MANIFEST_PATH)
      : null;

    const adrTouched = entries.some((e) => e.file === ADR_LOG_PATH);
    const adrDiff = adrTouched
      ? runGit(['diff', '--no-renames', '-U0', parentRef, sha, '--', ADR_LOG_PATH], true)
      : null;
    const adrAddedText = adrTouched ? extractAddedLinesFromDiff(adrDiff) : null;
    const adrLogContent = adrTouched ? gitReadFileAtRef(sha, ADR_LOG_PATH) : null;

    const fitnessEntry = entries.find((e) => e.file === FITNESS_TEST_PATH);
    const fitnessContent = fitnessEntry && fitnessEntry.status !== 'D'
      ? gitReadFileAtRef(sha, FITNESS_TEST_PATH)
      : null;

    const res = evaluateChangeSet({
      entries,
      commitMessage,
      checkCommitMsg: true,
      adrAddedText,
      adrLogContent,
      baseManifestRaw,
      newManifestRaw,
      manifestExistedInBase,
      fitnessContent,
      fitnessStatus: fitnessEntry?.status || 'M',
    });

    for (const w of res.warnings) console.warn(`⚠️  [${sha.slice(0, 7)}] ${w}`);
    for (const err of res.errors) {
      allErrors.push(`[Commit ${sha.slice(0, 7)}] ${err}`);
    }
  }

  // Validación agregada <base>..HEAD sobre integridad de baselineDebt y ux-fitness.spec.ts
  const headFitnessContent = gitReadFileAtRef('HEAD', FITNESS_TEST_PATH);
  const headFitnessExists = gitFileExistsAtRef('HEAD', FITNESS_TEST_PATH);
  if (!headFitnessExists) {
    allErrors.push(`[PR Agregado] ${FITNESS_TEST_PATH} debe existir en HEAD.`);
  } else {
    for (const fe of checkFitnessNotWeakened(headFitnessContent, 'M')) {
      allErrors.push(`[PR Agregado] ${fe}`);
    }
  }

  if (gitFileExistsAtRef(resolvedBase, MANIFEST_PATH) && gitFileExistsAtRef('HEAD', MANIFEST_PATH)) {
    const baseManifest = gitReadFileAtRef(resolvedBase, MANIFEST_PATH);
    const headManifest = gitReadFileAtRef('HEAD', MANIFEST_PATH);
    for (const de of checkBaselineDebtMonotonicity(baseManifest, headManifest)) {
      allErrors.push(`[PR Agregado] ${de}`);
    }
  }

  if (allErrors.length > 0) {
    console.error('========================================================================');
    console.error('❌ BLOQUEO DE GOBERNANZA UX (CI)');
    console.error('========================================================================');
    for (const err of allErrors) console.error(`\n${err}`);
    console.error('========================================================================');
    process.exit(1);
  }

  console.log(
    `✅ [UX-Gov CI] ${commits.length} commit(s) verificado(s) contra ${baseRef} sin violaciones.`
  );
  process.exit(0);
}

function handleSimulate(argv) {
  const getArg = (flag, fallback = null) => {
    const idx = argv.indexOf(flag);
    return idx !== -1 && argv[idx + 1] !== undefined ? argv[idx + 1] : fallback;
  };

  const filesCsv = getArg('--files', '');
  const commitMessage = getArg('--msg', '');
  const adrValid = getArg('--adr-valid', 'false') === 'true';
  const debtIncreased = getArg('--debt-increased', 'false') === 'true';
  const hasFitnessWeakening = getArg('--fitness-weakened', 'false') === 'true';

  const entries = filesCsv
    .split(',')
    .map((s) => normalizePath(s))
    .filter(Boolean)
    .map((file) => ({ status: 'M', file }));

  const syntheticAdrText = adrValid
    ? [
        '## UX-ADR-999: Simulación válida',
        '### 1. Contexto y Objeto (ORCA)',
        'Simulado',
        '### 2. Verdad Contable (Read Model / Invariante)',
        'Simulado',
        '### 3. Arquetipo, Señalización y Top Tasks',
        'Simulado',
        '### 4. Higiene de Crecimiento (Qué se consolida o elimina)',
        'Simulado',
      ].join('\n')
    : '';

  if (adrValid && !entries.some((e) => e.file === ADR_LOG_PATH)) {
    entries.push({ status: 'M', file: ADR_LOG_PATH });
  }

  const baseManifestObj = {
    adrVersion: 'UX-ADR-000',
    baselineDebt: {
      nativeDialogsAllowed: ['frontend/src/App.vue'],
      legacyToastImportsAllowed: [],
      materialIconsAllowed: [],
    },
  };
  const newManifestObj = {
    adrVersion: adrValid ? 'UX-ADR-999' : 'UX-ADR-000',
    baselineDebt: {
      nativeDialogsAllowed: debtIncreased
        ? ['frontend/src/App.vue', 'frontend/src/views/NuevoAlertView.vue']
        : ['frontend/src/App.vue'],
      legacyToastImportsAllowed: [],
      materialIconsAllowed: [],
    },
  };

  const result = evaluateChangeSet({
    entries,
    commitMessage,
    checkCommitMsg: true,
    adrAddedText: syntheticAdrText,
    adrLogContent: syntheticAdrText || '## UX-ADR-000: Base',
    baseManifestRaw: JSON.stringify(baseManifestObj),
    newManifestRaw: JSON.stringify(newManifestObj),
    manifestExistedInBase: true,
    fitnessContent: hasFitnessWeakening ? 'it.skip("x", () => {})' : 'it("x", () => {})',
    fitnessStatus: 'M',
  });

  for (const w of result.warnings) console.warn(`⚠️  ${w}`);

  if (result.errors.length > 0) {
    console.error('❌ [SIMULATE] Bloqueado por gobernanza UX:');
    for (const err of result.errors) console.error(`\n${err}`);
    process.exit(1);
  }

  console.log('✅ [SIMULATE] Cambio permitido por gobernanza UX.');
  process.exit(0);
}

const argv = process.argv.slice(2);
if (argv.includes('--pre-commit')) {
  handlePreCommit();
} else if (argv.includes('--commit-msg')) {
  const idx = argv.indexOf('--commit-msg');
  handleCommitMsg(argv[idx + 1]);
} else if (argv.includes('--ci')) {
  const idx = argv.indexOf('--base');
  const baseRef = idx !== -1 && argv[idx + 1] ? argv[idx + 1] : 'origin/master';
  handleCi(baseRef);
} else if (argv.includes('--simulate')) {
  handleSimulate(argv);
} else {
  console.error(
    'Uso: node scripts/verify-ux-governance.mjs [--pre-commit | --commit-msg <file> | --ci --base <ref> | --simulate ...]'
  );
  process.exit(1);
}
