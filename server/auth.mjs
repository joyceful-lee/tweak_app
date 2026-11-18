import { createAuthServer, extractNeonAuthCookies, serializeSetCookie,
  handleAuthProxyRequest, processAuthMiddleware } from '@neon/auth/server';
import { createHash, randomBytes, createCipheriv, createDecipheriv, timingSafeEqual } from 'node:crypto';
import { ApiError } from './validation.mjs';

export const appOrigin = () => process.env.PUBLIC_APP_URL || 'https://tweak-recipes.vercel.app';
const appOrigins = () => [appOrigin(), 'https://tweak-recipes.vercel.app', 'https://tweak.joyceful-lee.com'];
export function requestOrigin(request) {
  const origin = new URL(request.url).origin;
  return appOrigins().includes(origin) ? origin : appOrigin();
}
export function oauthDestination(value) {
  let destination;
  try { destination = new URL(value); } catch { throw new ApiError(502, 'Unexpected sign-in destination.'); }
  const authBase = new URL(authConfig().baseUrl);
  const authPath = authBase.pathname.replace(/\/$/, '');
  const managedStart = destination.origin === authBase.origin &&
    destination.pathname === `${authPath}/sign-in/social/init`;
  const googleStart = ['accounts.google.com','oauth2.googleapis.com'].includes(destination.hostname);
  if (destination.protocol !== 'https:' || destination.username || destination.password ||
      (!managedStart && !googleStart)) throw new ApiError(502, 'Unexpected sign-in destination.');
  return destination.toString();
}
export function authConfig() {
  if (!process.env.NEON_AUTH_BASE_URL || !process.env.NEON_AUTH_COOKIE_SECRET) throw new ApiError(503, 'Sign-in configuration is missing.');
  return { baseUrl: process.env.NEON_AUTH_BASE_URL, cookieSecret: process.env.NEON_AUTH_COOKIE_SECRET,
    sessionDataTtl: 1, sameSite: 'lax' };
}
export function checkOrigin(request) {
  const origin = request.headers.get('origin');
  const allowed = [...appOrigins(), process.env.VERCEL_URL && `https://${process.env.VERCEL_URL}`];
  if (process.env.NODE_ENV !== 'production') allowed.push('http://localhost:8080','http://127.0.0.1:8080');
  if (origin && !allowed.includes(origin)) throw new ApiError(403, 'This request origin is not allowed.');
  if (!['GET','HEAD','OPTIONS'].includes(request.method) && !origin &&
      request.headers.has('cookie') && !request.headers.has('authorization')) throw new ApiError(403, 'An origin header is required.');
}
export function nativeRequest(request) {
  const headers = new Headers(request.headers);
  const bearer = headers.get('authorization');
  if (bearer?.startsWith('Bearer ')) {
    try {
      const cookies = Buffer.from(bearer.slice(7), 'base64url').toString('utf8');
      if (cookies.length > 16000 || /[\r\n]/.test(cookies) || !extractNeonAuthCookies(cookies)) throw new Error();
      headers.set('cookie', extractNeonAuthCookies(cookies));
      headers.delete('authorization');
    } catch { throw new ApiError(401, 'Please sign in again.'); }
  }
  // Native requests have no browser Origin; use this app's fixed, trusted origin.
  if (!headers.has('origin')) headers.set('origin', requestOrigin(request));
  return new Request(request, { headers });
}
export function authServer(request, cookies) {
  return createAuthServer({ ...authConfig(), context: () => ({
    getCookies: () => extractNeonAuthCookies(request.headers.get('cookie') || ''),
    setCookie: (name, value, options) => cookies.push(serializeSetCookie({ name, value, ...options })),
    getHeader: name => request.headers.get(name), getOrigin: () => request.headers.get('origin') || appOrigin(),
    getFramework: () => 'tweak-vercel',
  }) });
}
export async function identity(request, cookies) {
  const response = await authServer(request, cookies).getSession();
  if (response.error || !response.data?.user) throw new ApiError(401, 'Please sign in.');
  return response.data.user;
}
export async function proveRestoration(request, cookies, user, otp) {
  if (typeof otp !== 'string' || !/^[0-9]{4,10}$/.test(otp)) throw new ApiError(400,'Enter the fresh code sent to your email to restore recipes.');
  const signedIn=await authServer(request,cookies).signIn.emailOtp({email:user.email,otp});
  if (signedIn.error || signedIn.data?.user?.id !== user.id || signedIn.data.user.emailVerified !== true) {
    throw new ApiError(403,'That code could not verify this account. Request a new code and try again.');
  }
  const headers=new Headers(request.headers);
  headers.set('cookie',mergedSession(request.headers.get('cookie'),cookies));
  const fresh=new Request(request.url,{headers});
  // Drop sessions created before fresh proof of email ownership. This prevents
  // a pre-existing, unverified signup session gaining access after restoration.
  const revoked=await authServer(fresh,cookies).revokeOtherSessions();
  if (revoked.error) throw new ApiError(503,'Could not secure the restored account. Please try again.');
  return signedIn.data.user;
}
export function mergedSession(existing, setCookies) {
  const jar = new Map(extractNeonAuthCookies(existing || '').split(';').map(s => s.trim()).filter(Boolean).map(s => {
    const i = s.indexOf('='); return [s.slice(0,i), s.slice(i+1)];
  }));
  for (const cookie of setCookies) {
    const pair = cookie.split(';')[0], index = pair.indexOf('=');
    if (index > 0) jar.set(pair.slice(0,index), pair.slice(index+1));
  }
  return extractNeonAuthCookies([...jar].map(([k,v]) => `${k}=${v}`).join('; '));
}
export async function proxyAuth(request, path) {
  const allowed = new Set(['get-session','sign-in/email','sign-up/email','sign-out','change-password','change-email',
    'request-password-reset','reset-password','send-verification-email','email-otp/send-verification-otp',
    'email-otp/verify-email','email-otp/request-password-reset','email-otp/reset-password','sign-in/email-otp']);
  if (!allowed.has(path)) throw new ApiError(404, 'Unknown sign-in operation.');
  if ((path === 'get-session') !== (request.method === 'GET')) throw new ApiError(405, 'Method not allowed.');
  return handleAuthProxyRequest({ request, path, ...authConfig() });
}
export const oauthProxy = request => handleAuthProxyRequest({ request, path: 'sign-in/social', ...authConfig() });
export const oauthComplete = request => processAuthMiddleware({ request, pathname: '/api/auth/complete',
  skipRoutes: [], loginUrl: '/', ...authConfig() });
export const digest = value => createHash('sha256').update(value).digest('hex');
export function sameDigest(a,b) { return typeof a === 'string' && typeof b === 'string' && a.length === b.length && timingSafeEqual(Buffer.from(a),Buffer.from(b)); }
export function seal(value) {
  const iv = randomBytes(12), key = createHash('sha256').update(authConfig().cookieSecret).digest();
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(value,'utf8'),cipher.final()]);
  return Buffer.concat([iv,cipher.getAuthTag(),encrypted]).toString('base64url');
}
export function unseal(value) {
  const bytes = Buffer.from(value,'base64url'), key = createHash('sha256').update(authConfig().cookieSecret).digest();
  const decipher = createDecipheriv('aes-256-gcm',key,bytes.subarray(0,12));
  decipher.setAuthTag(bytes.subarray(12,28));
  return Buffer.concat([decipher.update(bytes.subarray(28)),decipher.final()]).toString('utf8');
}
