import { spawnSync } from 'node:child_process';
import { readFileSync, readdirSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const cli = join(root, 'node_modules/supabase/dist/supabase.js');

/** A successful SQL query is not necessarily a successful pgTAP suite. */
export function validateTap(rows) {
  if (!Array.isArray(rows)) throw new Error('Respuesta SQL sin filas de resultados.');
  const lines = rows
    .flatMap((row) => Object.values(row))
    .filter((value) => typeof value === 'string')
    .flatMap((value) => value.split(/\r?\n/));
  const plans = lines.filter((line) => /^1\.\.\d+$/.test(line));
  if (plans.length !== 1) throw new Error('Se esperaba exactamente un plan pgTAP.');
  const expected = Number(plans[0].slice(3));
  const results = lines.filter((line) => /^(?:not )?ok\b/.test(line));
  if (!expected || results.length !== expected) {
    throw new Error(`Plan pgTAP incompleto: ${results.length}/${expected} resultados.`);
  }
  for (const [index, result] of results.entries()) {
    if (
      !new RegExp(`^ok ${index + 1}(?:\\s|$)`).test(result) ||
      /#\s*(?:SKIP|TODO)\b/i.test(result)
    ) {
      throw new Error(`Prueba fallida, omitida o fuera de orden: ${result}`);
    }
  }
  if (lines.some((line) => /^Bail out!|^# Looks like/.test(line))) {
    throw new Error('pgTAP ha abortado o ha comunicado fallos.');
  }
  return results;
}

function runCli(args, capture = false) {
  const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: root,
    encoding: 'utf8',
    stdio: capture ? 'pipe' : 'inherit',
    timeout: 120_000,
    maxBuffer: 4 * 1024 * 1024,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    let detail = '';
    if (capture) {
      process.stderr.write(result.stderr ?? '');
      try {
        const failure = JSON.parse(result.stdout);
        if (typeof failure.error?.message === 'string') detail = ` ${failure.error.message}`;
      } catch {
        // Do not dump raw stdout: retain only structured CLI error messages.
      }
    }
    throw new Error(`Supabase CLI terminó con código ${result.status}.${detail}`);
  }
  if (!capture) return;
  const response = JSON.parse(result.stdout);
  if (response.error || !Array.isArray(response.rows)) {
    throw new Error('Supabase no devolvió resultados SQL válidos.');
  }
  return response.rows;
}

function queryFile(file) {
  return runCli(['db', 'query', '--linked', '--file', file, '--output-format', 'json'], true);
}

export function validateDevelopmentProject(config, linked) {
  if (
    !config ||
    config.environment !== 'development' ||
    !/^[a-z]{20}$/.test(config.projectRef) ||
    linked !== config.projectRef
  ) {
    throw new Error(
      'El proyecto enlazado no coincide con el desarrollo autorizado. No se ejecutará SQL.',
    );
  }
}

function assertDevelopmentProject() {
  const config = JSON.parse(readFileSync(join(root, 'supabase/development.json'), 'utf8'));
  const linked = readFileSync(join(root, 'supabase/.temp/project-ref'), 'utf8').trim();
  validateDevelopmentProject(config, linked);
  console.log(`Proyecto de DESARROLLO autorizado: ${linked}`);
}

function testDatabase() {
  const temporary = mkdtempSync(join(tmpdir(), 'quini-db-test-'));
  try {
    const seed = readFileSync(join(root, 'supabase/seed.sql'), 'utf8');
    const directory = join(root, 'supabase/tests');
    const suites = readdirSync(directory)
      .filter((name) => name.endsWith('.test.sql'))
      .sort();
    if (!suites.length) throw new Error('No hay suites SQL para ejecutar.');
    let total = 0;
    for (const suite of suites) {
      const test = readFileSync(join(directory, suite), 'utf8');
      const marker = '-- @fixtures';
      if (
        test.split(marker).length !== 2 ||
        !/^begin;/m.test(test) ||
        !/rollback;\s*$/.test(test)
      ) {
        throw new Error(
          `${suite}: se requiere una transacción con rollback y un marcador de fixtures.`,
        );
      }
      const sqlPath = join(temporary, suite);
      // Seed twice inside each rollback-only transaction to test its idempotency.
      writeFileSync(sqlPath, test.replace(marker, `${seed}\n${seed}`));
      const before = queryFile(join(root, 'supabase/test-support/baseline-state.sql'));
      const rows = queryFile(sqlPath);
      const after = queryFile(join(root, 'supabase/test-support/baseline-state.sql'));
      if (JSON.stringify(before) !== JSON.stringify(after)) {
        throw new Error(`${suite}: cambió el estado; revisar rollback o actividad concurrente.`);
      }
      const results = validateTap(rows);
      console.log(`\n${suite}\n${results.join('\n')}`);
      total += results.length;
    }
    console.log(
      `${total} comprobaciones correctas en ${suites.length} suites; datos/permisos/pgTAP sin cambios persistentes.`,
    );
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}

export function main(action) {
  assertDevelopmentProject();
  if (action === 'test') return testDatabase();
  if (action === 'deploy') {
    // No seeds, roles, Vault secrets or remote resets. Deployment remains an explicit command.
    return runCli(['db', 'push', '--linked', '--skip-vault', '--yes']);
  }
  if (action === 'lint') {
    return runCli(['db', 'lint', '--linked', '--schema', 'public', '--fail-on', 'error']);
  }
  throw new Error('Acción válida requerida: test, deploy o lint.');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main(process.argv[2]);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
