const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const fail = message => { throw new Error(`Invalid migration snapshot: ${message}`); };
const id = value => {
  if (typeof value !== 'string' || !uuid.test(value)) fail('expected a UUID');
  return value.toLowerCase();
};
const text = (value, fallback = '') => {
  if (value == null) return fallback;
  if (typeof value !== 'string') fail('expected a text field');
  return value;
};
const strings = value => {
  if (value == null) return [];
  if (!Array.isArray(value) || !value.every(item => typeof item === 'string')) {
    fail('expected an array of strings');
  }
  return [...value];
};
const date = value => {
  if (!value || !Number.isFinite(Date.parse(value))) fail('missing or invalid creation date');
  return new Date(value).toISOString();
};
const uniqueById = rows => {
  if (new Set(rows.map(row => row.id)).size !== rows.length) fail('duplicate record IDs');
};

export function prepareSnapshot(input) {
  if (input?.format !== 'tweak-supabase-snapshot' || input.version !== 1) {
    fail('unsupported format; use the PostgreSQL snapshot exporter, not the app JSON export');
  }
  for (const table of ['dishes', 'dish_versions', 'notes']) {
    if (!Array.isArray(input.tables?.[table])) fail(`missing ${table} table`);
  }
  if (!Array.isArray(input.owners)) fail('missing source owners');
  const owners = input.owners.map(row => ({
    id: id(row.id), email: row.email == null ? null : text(row.email),
    email_verified: row.email_verified === true,
  }));
  uniqueById(owners);
  const ownerIds = new Set(owners.map(owner => owner.id));
  const dishes = input.tables.dishes.map(row => ({
    id: id(row.id), user_id: id(row.user_id), name: text(row.name),
    description: text(row.description), status: text(row.status, 'in_testing'),
    best_version: row.best_version == null ? null : id(row.best_version),
    created_at: date(row.created_at), legacy_payload: row,
  }));
  const versions = input.tables.dish_versions.map(row => {
    if (!Number.isSafeInteger(row.version_number) || row.version_number < 1) fail('invalid version number');
    const photoPaths = strings(row.photo_paths);
    if (photoPaths.length > 10) fail('more than 10 photos on a version');
    return {
      id: id(row.id), dish_id: id(row.dish_id), version_number: row.version_number,
      ingredients: strings(row.ingredients), directions: strings(row.directions),
      notes: text(row.notes), tags: strings(row.tags), status: text(row.status, 'in_testing'),
      photo_paths: photoPaths, created_at: date(row.created_at), legacy_payload: row,
    };
  });
  const notes = input.tables.notes.map(row => ({
    id: id(row.id), user_id: id(row.user_id), title: text(row.title), content: text(row.content),
    tags: strings(row.tags), created_at: date(row.created_at), legacy_payload: row,
  }));
  for (const rows of [dishes, versions, notes]) uniqueById(rows);
  const dishIds = new Set(dishes.map(dish => dish.id));
  const byVersion = new Map(versions.map(version => [version.id, version]));
  const numbers = new Set();
  for (const row of [...dishes, ...notes]) {
    if (!ownerIds.has(row.user_id)) fail('a recipe or note has no exported owner');
  }
  for (const version of versions) {
    if (!dishIds.has(version.dish_id)) fail('a version has no parent recipe');
    const key = `${version.dish_id}:${version.version_number}`;
    if (numbers.has(key)) fail('duplicate version numbers within a recipe');
    numbers.add(key);
  }
  for (const dish of dishes) {
    if (dish.best_version && byVersion.get(dish.best_version)?.dish_id !== dish.id) {
      fail('best version is missing or belongs to another recipe');
    }
  }
  const photoPaths = [...new Set(versions.flatMap(version => version.photo_paths))];
  return {
    owners, dishes, versions, notes, photoPaths,
    counts: { dishes: dishes.length, dish_versions: versions.length, notes: notes.length,
      owners: owners.length, referenced_photos: photoPaths.length },
  };
}

function canonical(value) {
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])]));
  }
  return value;
}

export function verifyImportedRows(expected, actual) {
  const ordered = rows => rows.map(canonical).sort((a, b) => a.id.localeCompare(b.id));
  if (JSON.stringify(ordered(expected)) !== JSON.stringify(ordered(actual))) {
    throw new Error('Post-import record content verification failed. Rolling back.');
  }
}

export function requirePhotosTransferred(snapshot) {
  if (snapshot.photoPaths.length) {
    throw new Error('This snapshot references photos. Transfer and verify the private photo files before applying it.');
  }
}
