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
const VIEWS_DIR = path.join(FRONTEND_SRC, 'views');
const MANIFEST_FILE = path.join(REPO_ROOT, 'documentation', '03_ui_ux_design', 'ux-manifest.json');
const ADR_LOG_FILE = path.join(REPO_ROOT, 'documentation', '03_ui_ux_design', 'UX_ADR_LOG.md');

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

describe('Architectural Fitness Functions — Gobernanza UX (WO-UX-GOV-000)', () => {
  const manifest = loadManifest();
  const productionFiles = walkFiles(FRONTEND_SRC, ['.vue', '.ts', '.js']).filter(
    (absPath) => !isTestFile(toRepoRelative(absPath))
  );

  it('1. Paridad 1:1 entre frontend/src/router/index.ts y ux-manifest.json + UX-ADR registrado', () => {
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

  it('6. Paridad exacta de overlays globales en <template> de frontend/src/App.vue', () => {
    const appVue = fs.readFileSync(APP_VUE_FILE, 'utf8');
    const templateMatch = appVue.match(/<template[^>]*>([\s\S]*?)<\/template>/i);
    expect(templateMatch, 'App.vue debe contener bloque <template>').not.toBeNull();

    const templateClean = templateMatch![1].replace(/<!--[\s\S]*?-->/g, ' ');
    const componentMatches = Array.from(templateClean.matchAll(/<([A-Z][A-Za-z0-9]*)\b/g)).map(
      (m) => m[1]
    );
    const mountedOverlays = componentMatches.filter((name) => name !== 'RouterView');

    expect(mountedOverlays).toEqual(manifest.globalOverlaysInAppVue);
  });
});
