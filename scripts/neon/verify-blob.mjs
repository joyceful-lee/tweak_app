import { put,get,del } from '@vercel/blob';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';

// Synthetic 1×1 PNG test fixture; no user photos are read or uploaded.
const bytes=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=','base64');
let blob;
try {
  blob=await put(`verification/${randomUUID()}.png`,bytes,{access:'private',contentType:'image/png',addRandomSuffix:false});
  const publicResponse=await fetch(blob.url);
  assert([401,403,404].includes(publicResponse.status));
  const authorized=await get(blob.url,{access:'private'});
  assert.equal(authorized?.statusCode,200);
  assert.deepEqual(Buffer.from(await new Response(authorized.stream).arrayBuffer()),bytes);
  console.log(JSON.stringify({private_upload:true,unauthenticated_download_denied:true,authorized_roundtrip:true,test_photo_removed:true},null,2));
}finally { if(blob)await del(blob.url); }
