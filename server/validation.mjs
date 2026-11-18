export class ApiError extends Error { constructor(status, message) { super(message); this.status = status; } }
export function uuid(value) {
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) throw new ApiError(400, 'Invalid record ID.');
  return value.toLowerCase();
}
export function text(value, max = 10000) {
  if (typeof value !== 'string' || value.length > max) throw new ApiError(400, 'Invalid text field.');
  return value.trim();
}
export function strings(value, max = 200) {
  if (!Array.isArray(value) || value.length > max) throw new ApiError(400, 'Invalid list.');
  return value.map(item => text(item));
}
export function versionBody(body) {
  const ingredients = strings(body.ingredients).filter(Boolean), directions = strings(body.directions).filter(Boolean);
  if (!ingredients.length || !directions.length) throw new ApiError(400, 'Ingredients and directions cannot be empty.');
  return { ingredients, directions, notes: text(body.notes ?? ''), tags: strings(body.tags ?? []),
    photo_paths: strings(body.photo_paths ?? [], 10).map(uuid) };
}
export function status(value) {
  if (!['finalized','in_testing','abandoned','finished','in_progress'].includes(value)) throw new ApiError(400, 'Invalid recipe status.');
  return value;
}
export function imageType(bytes) {
  if (bytes.length > 4194304 || !bytes.length) throw new ApiError(400, 'Photos must be 4 MB or smaller.');
  if (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) return 'image/jpeg';
  if (bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) return 'image/png';
  if (bytes.toString('ascii',0,4) === 'RIFF' && bytes.toString('ascii',8,12) === 'WEBP') return 'image/webp';
  throw new ApiError(400, 'Choose a JPEG, PNG, or WebP image.');
}
