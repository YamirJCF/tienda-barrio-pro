import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import ts from 'typescript';

interface ManifestRoute {
  name: string;
  path: string;
  aliases?: string[];
  view: string;
  context: string;
  archetype: string;
  guard: string;
  status: 'canonica' | 'consolidar' | 'duplicada' | 'blindada' | 'dev_only';
}

interface EmbeddedView {
  view: string;
  parentRoute: string;
  parentView: string;
  context: string;
  archetype: string;
  status: string;
}

interface UxManifest {
  schemaVersion: string;
  adrVersion: string;
  authorizedToastEngine: string;
  bottomNavRoutes: string[];
  globalOverlaysInAppVue: string[];
  routes: ManifestRoute[];
  embeddedViews: EmbeddedView[];
  baselineDebt: {
    nativeDialogsAllowed: string[];
    legacyToastImportsAllowed: string[];
    materialIconsAllowed: string[];
  };
}

interface ParsedRoute {
  name: string;
  path: string;
  aliases?: string[];
  view: string;
}

const REPO_ROOT = path.resolve(__dirname, '../../../..');
const FRONTEND_SRC = path.join(REPO_ROOT, 'frontend', 'src');
const ROUTER_FILE = path.join(FRONTEND_SRC, 'router', 'index.ts');
const APP_VUE_FILE = path.join(FRONTEND_SRC, 'App.vue');
const BOTTOM_NAV_FILE = path.join(FRONTEND_SRC, 'components', 'BottomNav.vue');
const VIEWS_DIR = path.join(FRONTEND_SRC, 'views');
const MANIFEST_FILE = path.join(REPO_ROOT, 'documentation', '03_ui_ux_design', 'ux-manifest.json');
const ADR_LOG_FILE = path.join(REPO_ROOT, 'documentation', '03_ui_ux_design', 'UX_ADR_LOG.md');

const PERMISSION_GUARD_FIELDS = new Set([
  'isAdmin',
  'canManageInventory',
  'canFiar',
  'canOpenCloseCash',
]);

function toRepoRelative(absPath: string): string {
  return path.relative(REPO_ROOT, absPath).replace(/\\/g, '/');
}

function walkFiles(dir: string, exts: string[]): string[] {
  if (!fs.existsSync(dir)) return [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const results: string[] = [];
  for (const entry of entries) {
    if (entry.name === 'node_modules' || entry.name === 'dist' || entry.name === '.git') continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkFiles(fullPath, exts));
    } else if (exts.some((ext) => entry.name.toLowerCase().endsWith(ext))) {
      results.push(fullPath);
    }
  }
  return results;
}

function isTestFile(relPath: string): boolean {
  return (
    relPath.startsWith('frontend/src/__tests__/') ||
    relPath.endsWith('.spec.ts') ||
    relPath.endsWith('.test.ts') ||
    relPath.endsWith('.spec.js') ||
    relPath.endsWith('.test.js')
  );
}

function stripTsComments(code: string): string {
  const scanner = ts.createScanner(ts.ScriptTarget.Latest, false, ts.LanguageVariant.Standard, code);
  const parts: string[] = [];
  let lastEnd = 0;
  let token = scanner.scan();
  while (token !== ts.SyntaxKind.EndOfFileToken) {
    if (
      token === ts.SyntaxKind.SingleLineCommentTrivia ||
      token === ts.SyntaxKind.MultiLineCommentTrivia
    ) {
      const start = scanner.getTokenStart();
      const end = scanner.getTokenEnd();
      parts.push(code.slice(lastEnd, start));
      parts.push(' ');
      lastEnd = end;
    }
    token = scanner.scan();
  }
  parts.push(code.slice(lastEnd));
  return parts.join('');
}

function extractCodeWithoutComments(filePath: string, content: string): { template: string; script: string } {
  if (!filePath.endsWith('.vue')) {
    return { template: '', script: stripTsComments(content) };
  }

  const templateMatch = content.match(/<template[^>]*>([\s\S]*?)<\/template>/i);
  const templateRaw = templateMatch ? templateMatch[1] : '';
  const templateClean = templateRaw.replace(/<!--[\s\S]*?-->/g, ' ');

  const scriptParts: string[] = [];
  const scriptRegex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
  let match: RegExpExecArray | null;
  while ((match = scriptRegex.exec(content)) !== null) {
    scriptParts.push(stripTsComments(match[1]));
  }

  return { template: templateClean, script: scriptParts.join('\n') };
}

function loadManifest(): UxManifest {
  return JSON.parse(fs.readFileSync(MANIFEST_FILE, 'utf8')) as UxManifest;
}

function resolveImportToRepoView(specifier: string): string {
  const resolved = path.resolve(path.dirname(ROUTER_FILE), specifier);
  return toRepoRelative(resolved);
}

function extractStringLiteral(node: ts.Expression | undefined): string | null {
  if (!node) return null;
  if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) {
    return node.text;
  }
  return null;
}

function extractStringArray(node: ts.Expression | undefined): string[] | undefined {
  if (!node || !ts.isArrayLiteralExpression(node)) return undefined;
  const values: string[] = [];
  for (const el of node.elements) {
    const val = extractStringLiteral(el);
    if (val !== null) values.push(val);
  }
  return values.length > 0 ? values : undefined;
}

function extractComponentView(
  node: ts.Expression | undefined,
  staticImports: Map<string, string>
): string | null {
  if (!node) return null;
  if (ts.isIdentifier(node)) {
    return staticImports.get(node.text) ?? null;
  }
  if (ts.isArrowFunction(node) || ts.isFunctionExpression(node)) {
    let foundView: string | null = null;
    const visit = (n: ts.Node) => {
      if (
        ts.isCallExpression(n) &&
        n.expression.kind === ts.SyntaxKind.ImportKeyword &&
        n.arguments.length === 1
      ) {
        const spec = extractStringLiteral(n.arguments[0]);
        if (spec) {
          foundView = resolveImportToRepoView(spec);
        }
      }
      if (!foundView) ts.forEachChild(n, visit);
    };
    visit(node.body);
    return foundView;
  }
  return null;
}

function parseRouterRoutes(): ParsedRoute[] {
  const sourceText = fs.readFileSync(ROUTER_FILE, 'utf8');
  const sourceFile = ts.createSourceFile(ROUTER_FILE, sourceText, ts.ScriptTarget.Latest, true);
  const staticImports = new Map<string, string>();
  const parsedRoutes: ParsedRoute[] = [];

  const parseRouteObject = (obj: ts.ObjectLiteralExpression) => {
    let routePath: string | null = null;
    let routeName: string | null = null;
    let routeView: string | null = null;
    let routeAliases: string[] | undefined;

    for (const prop of obj.properties) {
      if (!ts.isPropertyAssignment(prop) || !ts.isIdentifier(prop.name)) continue;
      const key = prop.name.text;
      if (key === 'path') {
        routePath = extractStringLiteral(prop.initializer);
      } else if (key === 'name') {
        routeName = extractStringLiteral(prop.initializer);
      } else if (key === 'alias') {
        const single = extractStringLiteral(prop.initializer);
        routeAliases = single ? [single] : extractStringArray(prop.initializer);
      } else if (key === 'component') {
        routeView = extractComponentView(prop.initializer, staticImports);
      }
    }

    if (!routePath || !routeName || !routeView) {
      throw new Error(
        `Ruta incompleta en router/index.ts: path=${routePath}, name=${routeName}, view=${routeView}`
      );
    }

    parsedRoutes.push({
      name: routeName,
      path: routePath,
      ...(routeAliases ? { aliases: routeAliases } : {}),
      view: routeView,
    });
  };

  for (const stmt of sourceFile.statements) {
    if (ts.isImportDeclaration(stmt) && stmt.importClause?.name && ts.isStringLiteral(stmt.moduleSpecifier)) {
      const spec = stmt.moduleSpecifier.text;
      if (spec.includes('/views/')) {
        staticImports.set(stmt.importClause.name.text, resolveImportToRepoView(spec));
      }
    }

    if (ts.isVariableStatement(stmt)) {
      for (const decl of stmt.declarationList.declarations) {
        if (
          ts.isIdentifier(decl.name) &&
          decl.name.text === 'routes' &&
          decl.initializer &&
          ts.isArrayLiteralExpression(decl.initializer)
        ) {
          for (const el of decl.initializer.elements) {
            if (ts.isObjectLiteralExpression(el)) {
              parseRouteObject(el);
            }
          }
        }
      }
    }
  }

  // Capturar también routes.push({...}) condicionales (ej. import.meta.env.DEV)
  const visitPush = (node: ts.Node) => {
    if (
      ts.isCallExpression(node) &&
      ts.isPropertyAccessExpression(node.expression) &&
      ts.isIdentifier(node.expression.expression) &&
      node.expression.expression.text === 'routes' &&
      node.expression.name.text === 'push'
    ) {
      for (const arg of node.arguments) {
        if (ts.isObjectLiteralExpression(arg)) {
          parseRouteObject(arg);
        }
      }
    }
    ts.forEachChild(node, visitPush);
  };
  visitPush(sourceFile);

  return parsedRoutes;
}

function unwrapParens(expr: ts.Expression): ts.Expression {
  let current = expr;
  while (ts.isParenthesizedExpression(current)) {
    current = current.expression;
  }
  return current;
}

function flattenLogicalAnd(expr: ts.Expression): ts.Expression[] {
  const unwrapped = unwrapParens(expr);
  if (
    ts.isBinaryExpression(unwrapped) &&
    unwrapped.operatorToken.kind === ts.SyntaxKind.AmpersandAmpersandToken
  ) {
    return [...flattenLogicalAnd(unwrapped.left), ...flattenLogicalAnd(unwrapped.right)];
  }
  return [unwrapped];
}

function extractRouteNamesFromEqualityOr(expr: ts.Expression): string[] | null {
  const unwrapped = unwrapParens(expr);
  if (
    ts.isBinaryExpression(unwrapped) &&
    unwrapped.operatorToken.kind === ts.SyntaxKind.BarBarToken
  ) {
    const left = extractRouteNamesFromEqualityOr(unwrapped.left);
    const right = extractRouteNamesFromEqualityOr(unwrapped.right);
    if (!left || !right) return null;
    return [...left, ...right];
  }

  if (
    ts.isBinaryExpression(unwrapped) &&
    unwrapped.operatorToken.kind === ts.SyntaxKind.EqualsEqualsEqualsToken
  ) {
    const isToNameProp = (node: ts.Expression) =>
      ts.isPropertyAccessExpression(node) &&
      ts.isIdentifier(node.expression) &&
      node.expression.text === 'to' &&
      node.name.text === 'name';

    if (isToNameProp(unwrapped.left)) {
      const val = extractStringLiteral(unwrapped.right);
      return val ? [val] : null;
    }
    if (isToNameProp(unwrapped.right)) {
      const val = extractStringLiteral(unwrapped.left);
      return val ? [val] : null;
    }
  }

  return null;
}

function extractNegatedAuthPerm(expr: ts.Expression): string | null {
  const unwrapped = unwrapParens(expr);
  if (
    ts.isPrefixUnaryExpression(unwrapped) &&
    unwrapped.operator === ts.SyntaxKind.ExclamationToken
  ) {
    const operand = unwrapParens(unwrapped.operand);
    if (
      ts.isPropertyAccessExpression(operand) &&
      ts.isIdentifier(operand.expression) &&
      operand.expression.text === 'authStore' &&
      PERMISSION_GUARD_FIELDS.has(operand.name.text)
    ) {
      return operand.name.text;
    }
  }
  return null;
}

function parseBeforeEachPermissionGuards(): Map<string, Set<string>> {
  const sourceText = fs.readFileSync(ROUTER_FILE, 'utf8');
  const sourceFile = ts.createSourceFile(ROUTER_FILE, sourceText, ts.ScriptTarget.Latest, true);
  const guardsByRoute = new Map<string, Set<string>>();

  const visit = (node: ts.Node) => {
    if (
      ts.isCallExpression(node) &&
      ts.isPropertyAccessExpression(node.expression) &&
      ts.isIdentifier(node.expression.expression) &&
      node.expression.expression.text === 'router' &&
      node.expression.name.text === 'beforeEach' &&
      node.arguments.length >= 1
    ) {
      const callback = node.arguments[0];
      const visitGuardStmt = (inner: ts.Node) => {
        if (ts.isIfStatement(inner)) {
          const conjuncts = flattenLogicalAnd(inner.expression);
          const routeNames: string[] = [];
          const perms: string[] = [];
          let hasNonMatchingConjunct = false;

          for (const part of conjuncts) {
            const names = extractRouteNamesFromEqualityOr(part);
            if (names) {
              routeNames.push(...names);
              continue;
            }
            const perm = extractNegatedAuthPerm(part);
            if (perm) {
              perms.push(perm);
              continue;
            }
            hasNonMatchingConjunct = true;
          }

          if (!hasNonMatchingConjunct && routeNames.length > 0 && perms.length > 0) {
            for (const routeName of routeNames) {
              if (!guardsByRoute.has(routeName)) {
                guardsByRoute.set(routeName, new Set());
              }
              for (const perm of perms) {
                guardsByRoute.get(routeName)!.add(perm);
              }
            }
          }
        }
        ts.forEachChild(inner, visitGuardStmt);
      };
      visitGuardStmt(callback);
    }
    ts.forEachChild(node, visit);
  };

  visit(sourceFile);
  return guardsByRoute;
}

function extractComponentImportsFromAppVue(appContent: string): Set<string> {
  const imported = new Set<string>();
  const scriptRegex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
  let match: RegExpExecArray | null;
  while ((match = scriptRegex.exec(appContent)) !== null) {
    const sf = ts.createSourceFile('App.vue.ts', match[1], ts.ScriptTarget.Latest, true);
    for (const stmt of sf.statements) {
      if (
        ts.isImportDeclaration(stmt) &&
        stmt.importClause?.name &&
        ts.isStringLiteral(stmt.moduleSpecifier)
      ) {
        const spec = stmt.moduleSpecifier.text;
        if (spec.startsWith('./components/') || spec.startsWith('@/components/')) {
          imported.add(stmt.importClause.name.text);
        }
      }
    }
  }
  return imported;
}

function extractRootDirectOverlayComponents(templateClean: string, allowedComponentImports: Set<string>): string[] {
  const VOID_HTML_TAGS = new Set([
    'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
    'link', 'meta', 'param', 'source', 'track', 'wbr',
  ]);
  const directOverlays: string[] = [];
  let depth = 0;
  let i = 0;

  while (i < templateClean.length) {
    const openIdx = templateClean.indexOf('<', i);
    if (openIdx === -1) break;

    // Buscar '>' de cierre respetando comillas en atributos
    let j = openIdx + 1;
    let quote: string | null = null;
    while (j < templateClean.length) {
      const ch = templateClean[j];
      if (quote) {
        if (ch === '\\') {
          j += 2;
          continue;
        }
        if (ch === quote) quote = null;
      } else {
        if (ch === '"' || ch === "'" || ch === '`') {
          quote = ch;
        } else if (ch === '>') {
          break;
        }
      }
      j++;
    }
    if (j >= templateClean.length) break;

    const tagContent = templateClean.slice(openIdx + 1, j).trim();
    i = j + 1;

    if (!tagContent || tagContent.startsWith('!')) continue;

    if (tagContent.startsWith('/')) {
      depth = Math.max(0, depth - 1);
      continue;
    }

    const nameMatch = tagContent.match(/^([A-Za-z][A-Za-z0-9_-]*)/);
    if (!nameMatch) continue;
    const tagName = nameMatch[1];
    const isSelfClosing = tagContent.endsWith('/') || VOID_HTML_TAGS.has(tagName.toLowerCase());

    if (depth === 1 && /^[A-Z]/.test(tagName) && tagName !== 'RouterView' && allowedComponentImports.has(tagName)) {
      directOverlays.push(tagName);
    }

    if (!isSelfClosing) {
      depth++;
    }
  }

  return directOverlays;
}

describe('Architectural Fitness Functions — Gobernanza UX (WO-UX-GOV-000)', () => {
  const manifest = loadManifest();
  const productionFiles = walkFiles(FRONTEND_SRC, ['.vue', '.ts', '.js']).filter(
    (absPath) => !isTestFile(toRepoRelative(absPath))
  );

  it('1. Paridad 1:1 entre frontend/src/router/index.ts y ux-manifest.json + UX-ADR + guards de permiso', () => {
    const routerRoutes = parseRouterRoutes();
    const manifestComparable = manifest.routes.map((r) => ({
      name: r.name,
      path: r.path,
      ...(r.aliases ? { aliases: r.aliases } : {}),
      view: r.view,
    }));

    const sortByName = (a: ParsedRoute, b: ParsedRoute) => a.name.localeCompare(b.name);
    expect([...routerRoutes].sort(sortByName)).toEqual([...manifestComparable].sort(sortByName));

    const adrLogContent = fs.readFileSync(ADR_LOG_FILE, 'utf8');
    const adrHeadingRegex = new RegExp(`^##\\s+${manifest.adrVersion}\\b`, 'm');
    expect(adrLogContent).toMatch(adrHeadingRegex);

    const routerPermissionGuards = parseBeforeEachPermissionGuards();
    for (const route of manifest.routes) {
      if (PERMISSION_GUARD_FIELDS.has(route.guard)) {
        const appliedGuards = routerPermissionGuards.get(route.name);
        expect(
          appliedGuards?.has(route.guard),
          `La ruta "${route.name}" declara guard "${route.guard}" en ux-manifest.json pero no está protegida con !authStore.${route.guard} en router.beforeEach`
        ).toBe(true);
      }
    }

    for (const [routeName, appliedGuards] of routerPermissionGuards.entries()) {
      const manifestRoute = manifest.routes.find((r) => r.name === routeName);
      expect(manifestRoute, `Guard en router.beforeEach para ruta desconocida "${routeName}"`).toBeDefined();
      expect(
        appliedGuards.has(manifestRoute!.guard),
        `Desincronización de guard para "${routeName}": router.beforeEach aplica [${Array.from(appliedGuards).join(', ')}] vs ux-manifest="${manifestRoute!.guard}"`
      ).toBe(true);
    }
  });

  it('2. Cero vistas huérfanas en frontend/src/views/ y contexto/arquetipo válidos en manifiesto', () => {
    const diskViews = walkFiles(VIEWS_DIR, ['.vue']).map(toRepoRelative).sort();
    const registeredRouteViews = manifest.routes.map((r) => r.view);
    const registeredEmbeddedViews = manifest.embeddedViews.map((e) => e.view);
    const allRegisteredViews = Array.from(new Set([...registeredRouteViews, ...registeredEmbeddedViews])).sort();

    const unregisteredOnDisk = diskViews.filter((v) => !allRegisteredViews.includes(v));
    const missingFromDisk = allRegisteredViews.filter((v) => !diskViews.includes(v));

    expect(unregisteredOnDisk, `Vistas huérfanas sin registrar en ux-manifest.json: ${unregisteredOnDisk.join(', ')}`).toEqual([]);
    expect(missingFromDisk, `Vistas registradas en ux-manifest.json que no existen en disco: ${missingFromDisk.join(', ')}`).toEqual([]);

    const validContexts = /^(C[1-9]\d*|Shell|Dev|N4)$/;
    const validArchetypes = /^(A|B|C|D|E|F|B\/D|Hub|none)$/;

    for (const route of manifest.routes) {
      expect(route.context, `Contexto inválido en ruta ${route.name}`).toMatch(validContexts);
      expect(route.archetype, `Arquetipo inválido en ruta ${route.name}`).toMatch(validArchetypes);
    }
    for (const embedded of manifest.embeddedViews) {
      expect(embedded.context, `Contexto inválido en subvista ${embedded.view}`).toMatch(validContexts);
      expect(embedded.archetype, `Arquetipo inválido en subvista ${embedded.view}`).toMatch(validArchetypes);
    }
  });

  it('3. Cero diálogos nativos nuevos (alert/confirm/prompt) fuera de baselineDebt.nativeDialogsAllowed', () => {
    const allowed = new Set(manifest.baselineDebt.nativeDialogsAllowed);
    const offenders: string[] = [];
    const nativeDialogRegex = /(?:^|[^.\w$])(?:window\.)?(alert|confirm|prompt)\s*\(/m;

    for (const absPath of productionFiles) {
      const rel = toRepoRelative(absPath);
      const raw = fs.readFileSync(absPath, 'utf8');
      const { template, script } = extractCodeWithoutComments(absPath, raw);
      if (nativeDialogRegex.test(template) || nativeDialogRegex.test(script)) {
        if (!allowed.has(rel)) {
          offenders.push(rel);
        }
      }
    }

    expect(
      offenders,
      `Archivos con alert()/confirm()/prompt() prohibido fuera de baselineDebt: ${offenders.join(', ')}`
    ).toEqual([]);

    for (const rel of allowed) {
      expect(fs.existsSync(path.join(REPO_ROOT, rel)), `Deuda fantasma inexistente: ${rel}`).toBe(true);
    }
  });

  it('4. Cero importaciones nuevas de vue-toastification fuera de baselineDebt.legacyToastImportsAllowed', () => {
    const allowed = new Set(manifest.baselineDebt.legacyToastImportsAllowed);
    const offenders: string[] = [];
    const toastImportRegex = /(?:from|import)\s+['"]vue-toastification(?:\/[^'"]*)?['"]/m;

    for (const absPath of productionFiles) {
      const rel = toRepoRelative(absPath);
      const raw = fs.readFileSync(absPath, 'utf8');
      const { script } = extractCodeWithoutComments(absPath, raw);
      if (toastImportRegex.test(script) && !allowed.has(rel)) {
        offenders.push(rel);
      }
    }

    expect(
      offenders,
      `Motor duplicado vue-toastification fuera de baselineDebt: ${offenders.join(', ')}`
    ).toEqual([]);

    for (const rel of allowed) {
      expect(fs.existsSync(path.join(REPO_ROOT, rel)), `Deuda fantasma inexistente: ${rel}`).toBe(true);
    }
  });

  it('5. Cero usos nuevos de material-icons fuera de baselineDebt.materialIconsAllowed', () => {
    const allowed = new Set(manifest.baselineDebt.materialIconsAllowed);
    const offenders: string[] = [];
    const materialIconsRegex = /\bmaterial-icons\b/;

    for (const absPath of productionFiles) {
      const rel = toRepoRelative(absPath);
      const raw = fs.readFileSync(absPath, 'utf8');
      const { template, script } = extractCodeWithoutComments(absPath, raw);
      if ((materialIconsRegex.test(template) || materialIconsRegex.test(script)) && !allowed.has(rel)) {
        offenders.push(rel);
      }
    }

    expect(
      offenders,
      `Uso prohibido de material-icons fuera de baselineDebt: ${offenders.join(', ')}`
    ).toEqual([]);

    for (const rel of allowed) {
      expect(fs.existsSync(path.join(REPO_ROOT, rel)), `Deuda fantasma inexistente: ${rel}`).toBe(true);
    }
  });

  it('6. Paridad exacta de overlays globales hijos directos en <template> de frontend/src/App.vue', () => {
    const appVue = fs.readFileSync(APP_VUE_FILE, 'utf8');
    const templateMatch = appVue.match(/<template[^>]*>([\s\S]*?)<\/template>/i);
    expect(templateMatch, 'App.vue debe contener bloque <template>').not.toBeNull();

    const templateClean = templateMatch![1].replace(/<!--[\s\S]*?-->/g, ' ');
    const allowedComponentImports = extractComponentImportsFromAppVue(appVue);
    const mountedOverlays = extractRootDirectOverlayComponents(templateClean, allowedComponentImports);

    expect(mountedOverlays).toEqual(manifest.globalOverlaysInAppVue);
  });

  it('7. Paridad 1:1 entre destinos router.push() de BottomNav.vue y manifest.bottomNavRoutes', () => {
    const bottomNav = fs.readFileSync(BOTTOM_NAV_FILE, 'utf8');
    const templateMatch = bottomNav.match(/<template[^>]*>([\s\S]*?)<\/template>/i);
    expect(templateMatch, 'BottomNav.vue debe contener bloque <template>').not.toBeNull();

    const templateClean = templateMatch![1].replace(/<!--[\s\S]*?-->/g, ' ');
    const navDestinations = Array.from(
      templateClean.matchAll(/router\.push\(\s*['"]([^'"]+)['"]\s*\)/g)
    ).map((m) => m[1]);

    expect(navDestinations).toEqual(manifest.bottomNavRoutes);

    const validPaths = new Set<string>();
    for (const r of manifest.routes) {
      validPaths.add(r.path);
      for (const alias of r.aliases ?? []) {
        validPaths.add(alias);
      }
    }

    for (const dest of navDestinations) {
      expect(
        validPaths.has(dest),
        `Destino "${dest}" en BottomNav.vue no está registrado como ruta canónica en ux-manifest.json`
      ).toBe(true);
    }
  });

  it('8. Economía Verbal (Estándar POS — Regla 12.3): cero narración de servidor/jerga prohibida y tope de 25 palabras por <p> operativo', () => {
    const excludedViews = new Set<string>([
      ...manifest.routes
        .filter(
          (r) =>
            r.status === 'blindada' ||
            r.status === 'dev_only' ||
            r.name === 'privacy-policy' ||
            r.name === 'platform-legal'
        )
        .map((r) => r.view),
      ...manifest.embeddedViews.filter((e) => e.status === 'blindada').map((e) => e.view),
      'frontend/src/components/legal/LegalComplianceGate.vue',
      'frontend/src/components/LegalComplianceGate.vue',
    ]);

    const bannedCopyRules: Array<{ label: string; regex: RegExp }> = [
      { label: 'Sigla OPEX visible', regex: /\bOPEX\b/ },
      { label: 'Sigla P&L visible', regex: /\bP&(?:amp;)?L\b/ },
      { label: 'Etiqueta (SQL) visible', regex: /\(SQL\)/i },
      { label: 'Etiqueta (FIFO) visible', regex: /\(FIFO\)/i },
      { label: 'Jerga "Kardex Inmutable"', regex: /\bKardex Inmutable\b/i },
      { label: 'Jerga "Entrada Atómica"', regex: /\b(?:Nueva )?Entrada Atómica\b/i },
      { label: 'Caja instructiva "Protocolo de..."', regex: /\bprotocolo de\b/i },
      {
        label: 'Narración interna "el servidor calculará/validará..."',
        regex: /\bel servidor (?:calculará|calcula|validará|valida|asumirá|liquidará|liquida)\b/i,
      },
      {
        label: 'Narración interna "calculado/validado por el servidor"',
        regex: /\b(?:calculad[oa]s?|validad[oa]s?) por (?:el )?servidor\b/i,
      },
      {
        label: 'Nota arquitectónica "independiente de Cuentas por Pagar"',
        regex: /\bindependiente de Cuentas por Pagar\b/i,
      },
      {
        label: 'Nota arquitectónica "impacto $0 en Caja"',
        regex: /\bimpacto \$0 en Caja\b/i,
      },
    ];

    const MAX_OPERATIONAL_PARAGRAPH_WORDS = 25;
    const jargonViolations: string[] = [];
    const densityViolations: string[] = [];

    const vueFiles = walkFiles(FRONTEND_SRC, ['.vue']).filter((absPath) => {
      const rel = toRepoRelative(absPath);
      if (isTestFile(rel)) return false;
      if (excludedViews.has(rel) || rel.includes('/views/auth/')) return false;
      return rel.startsWith('frontend/src/views/') || rel.startsWith('frontend/src/components/');
    });

    for (const absPath of vueFiles) {
      const rel = toRepoRelative(absPath);
      const raw = fs.readFileSync(absPath, 'utf8');
      const { template } = extractCodeWithoutComments(absPath, raw);
      if (!template) continue;

      const visibleText = template
        .replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1>/gi, ' ')
        .replace(/<[^>]+>/g, ' ')
        .replace(/\{\{[\s\S]*?\}\}/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

      for (const rule of bannedCopyRules) {
        if (rule.regex.test(visibleText)) {
          jargonViolations.push(`${rel}: ${rule.label}`);
        }
      }

      for (const pMatch of template.matchAll(/<p\b[^>]*>([\s\S]*?)<\/p>/gi)) {
        const pText = pMatch[1]
          .replace(/<[^>]+>/g, ' ')
          .replace(/\{\{[\s\S]*?\}\}/g, 'X')
          .replace(/\s+/g, ' ')
          .trim();
        if (!pText) continue;
        const wordCount = pText.split(' ').filter(Boolean).length;
        if (wordCount > MAX_OPERATIONAL_PARAGRAPH_WORDS) {
          densityViolations.push(
            `${rel} (${wordCount} palabras > máx ${MAX_OPERATIONAL_PARAGRAPH_WORDS}): "${pText.slice(0, 80)}..."`
          );
        }
      }
    }

    expect(
      jargonViolations,
      `Violaciones de Glosario/Arquitectura Invisible en plantillas operativas:\n${jargonViolations.join('\n')}`
    ).toEqual([]);

    expect(
      densityViolations,
      `Párrafos operativos (<p>) que exceden el presupuesto de ${MAX_OPERATIONAL_PARAGRAPH_WORDS} palabras (Regla 12.3 Estándar POS):\n${densityViolations.join('\n')}`
    ).toEqual([]);
  });
});
