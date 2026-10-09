import assert from 'node:assert/strict';
import test from 'node:test';
import { validateTap, validateDevelopmentProject } from './supabase-development.mjs';

test('allows only the configured development project', () => {
  const config = { environment: 'development', projectRef: 'abcdefghijklmnopqrst' };
  assert.doesNotThrow(() => validateDevelopmentProject(config, config.projectRef));
  assert.throws(() => validateDevelopmentProject(config, 'another-project'));
});
test('rejects production, missing configuration and invalid references', () => {
  assert.throws(() =>
    validateDevelopmentProject(
      { environment: 'production', projectRef: 'abcdefghijklmnopqrst' },
      'abcdefghijklmnopqrst',
    ),
  );
  assert.throws(() => validateDevelopmentProject(null, ''));
  assert.throws(() =>
    validateDevelopmentProject({ environment: 'development', projectRef: '' }, ''),
  );
});

const passing = [{ plan: '1..2' }, { is: 'ok 1 - table exists' }, { is: 'ok 2 - RLS enabled' }];

test('accepts a complete successful TAP plan', () => {
  assert.equal(validateTap(passing).length, 2);
});
test('rejects not ok even when the SQL command succeeds', () => {
  assert.throws(() => validateTap([passing[0], passing[1], { is: 'not ok 2 - RLS enabled' }]));
});
test('rejects an incomplete plan', () => {
  assert.throws(() => validateTap(passing.slice(0, 2)));
});
test('rejects missing or duplicate plans', () => {
  assert.throws(() => validateTap(passing.slice(1)));
  assert.throws(() => validateTap([...passing, passing[0]]));
});
test('rejects skipped or TODO tests', () => {
  assert.throws(() => validateTap([passing[0], passing[1], { is: 'ok 2 # SKIP unavailable' }]));
  assert.throws(() => validateTap([passing[0], passing[1], { is: 'ok 2 # TODO later' }]));
});
test('rejects a bailout or finish diagnostic reporting failures', () => {
  assert.throws(() => validateTap([...passing, { finish: 'Bail out! cannot continue' }]));
  assert.throws(() => validateTap([...passing, { finish: '# Looks like you failed 1 test' }]));
});
test('rejects malformed, empty or out-of-order results', () => {
  assert.throws(() => validateTap(null));
  assert.throws(() => validateTap([]));
  assert.throws(() => validateTap([passing[0], passing[2], passing[1]]));
});
