import test from 'node:test';
import assert from 'node:assert/strict';
import { prepareSnapshot, requirePhotosTransferred, verifyImportedRows } from '../../scripts/neon/snapshot.mjs';

const owner = '00000000-0000-0000-0000-000000000001';
const dish = '00000000-0000-0000-0000-000000000002';
const version = '00000000-0000-0000-0000-000000000003';
const note = '00000000-0000-0000-0000-000000000004';
const timestamp = '2026-11-18T12:00:00.000Z';
function fixture() {
  return {
    format: 'tweak-supabase-snapshot', version: 1,
    owners: [{ id: owner, email: 'migration-test@example.invalid', email_verified: true }],
    tables: {
      dishes: [{ id: dish, user_id: owner, name: 'Test recipe', status: 'finalized', best_version: version, created_at: timestamp }],
      dish_versions: [{ id: version, dish_id: dish, version_number: 3, ingredients: ['1 tsp salt'],
        directions: ['Mix'], notes: 'Keep this text', tags: ['test'], created_at: timestamp }],
      notes: [{ id: note, user_id: owner, title: 'Test note', content: 'Keep this too', created_at: timestamp }],
    },
  };
}

test('preserves IDs, version numbers, owners and unknown source fields without mutation', () => {
  const input = fixture();
  input.tables.dishes[0].custom_field = { preserve: 'source data' };
  const original = structuredClone(input);
  const result = prepareSnapshot(input);
  assert.deepEqual(result.counts, { dishes: 1, dish_versions: 1, notes: 1, owners: 1, referenced_photos: 0 });
  assert.equal(result.versions[0].version_number, 3);
  assert.equal(result.dishes[0].best_version, version);
  assert.equal(result.dishes[0].user_id, owner);
  assert.deepEqual(result.dishes[0].legacy_payload.custom_field, { preserve: 'source data' });
  assert.deepEqual(input, original);
});

test('rejects app JSON exports that omit complete IDs and ownership information', () => {
  assert.throws(() => prepareSnapshot({ recipes: [], notes: [] }), /unsupported format/);
});

test('rejects a missing source table instead of silently losing its records', () => {
  const input = fixture();
  delete input.tables.notes;
  assert.throws(() => prepareSnapshot(input), /missing notes/);
});

test('rejects orphaned owners and versions', () => {
  const input = fixture();
  input.owners = [];
  assert.throws(() => prepareSnapshot(input), /no exported owner/);
  input.owners = fixture().owners;
  input.tables.dish_versions[0].dish_id = note;
  assert.throws(() => prepareSnapshot(input), /no parent recipe/);
});

test('rejects a best-version link pointing into a different recipe', () => {
  const input = fixture();
  input.tables.dishes.push({ ...input.tables.dishes[0], id: note });
  assert.throws(() => prepareSnapshot(input), /belongs to another recipe/);
});

test('rejects duplicate version numbers within a dish', () => {
  const input = fixture();
  input.tables.dish_versions.push({ ...input.tables.dish_versions[0], id: note });
  assert.throws(() => prepareSnapshot(input), /duplicate version numbers/);
});

test('rejects malformed arrays and creation dates rather than inventing values', () => {
  const input = fixture();
  input.tables.dish_versions[0].ingredients = 'not an array';
  assert.throws(() => prepareSnapshot(input), /array of strings/);
  input.tables.dish_versions[0].ingredients = [];
  input.tables.notes[0].created_at = 'invalid';
  assert.throws(() => prepareSnapshot(input), /creation date/);
});

test('detects photo references and blocks copying references without their files', () => {
  const input = fixture();
  input.tables.dish_versions[0].photo_paths = [`${owner}/photo.jpg`];
  const result = prepareSnapshot(input);
  assert.equal(result.counts.referenced_photos, 1);
  assert.throws(() => requirePhotosTransferred(result), /Transfer and verify/);
  assert.doesNotThrow(() => requirePhotosTransferred(prepareSnapshot(fixture())));
});

test('does not carry authentication secrets into the owner mapping', () => {
  const input = fixture();
  input.owners[0].encrypted_password = 'not-a-real-hash';
  input.owners[0].refresh_token = 'not-a-real-token';
  assert.deepEqual(Object.keys(prepareSnapshot(input).owners[0]).sort(), ['email', 'email_verified', 'id']);
});

test('verifies field contents across PostgreSQL date and JSON key normalization', () => {
  const expected = [{ id: dish, created_at: timestamp, legacy_payload: { a: 1, b: 2 }, tags: ['a', 'b'] }];
  const actual = [{ id: dish, tags: ['a', 'b'], legacy_payload: { b: 2, a: 1 }, created_at: new Date(timestamp) }];
  assert.doesNotThrow(() => verifyImportedRows(expected, actual));
  actual[0].tags = ['b', 'a'];
  assert.throws(() => verifyImportedRows(expected, actual), /content verification failed/);
});
