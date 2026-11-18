import { Readable } from 'node:stream';
import { handle } from '../server/app.mjs';
export default async function handler(req,res) {
  const headers=new Headers();
  for(const [key,value] of Object.entries(req.headers)) if(value) headers.set(key,Array.isArray(value)?value.join(','):value);
  const host=req.headers.host || process.env.VERCEL_URL;
  const url=new URL(req.url,`${process.env.VERCEL?'https':'http'}://${host}`);
  let body;
  if(!['GET','HEAD'].includes(req.method)) {
    if(req.body !== undefined) body=Buffer.isBuffer(req.body)?req.body:Buffer.from(typeof req.body === 'string'?req.body:JSON.stringify(req.body));
    else { const chunks=[];let size=0;for await(const chunk of req){size+=chunk.length;if(size>4194304){res.statusCode=413;res.end();return;}chunks.push(chunk);}body=Buffer.concat(chunks); }
  }
  const response=await handle(new Request(url,{method:req.method,headers,...(body?.length?{body,duplex:'half'}:{})}));
  res.statusCode=response.status;
  for(const [key,value] of response.headers) if(key !== 'set-cookie') res.setHeader(key,value);
  const cookies=response.headers.getSetCookie();if(cookies.length)res.setHeader('set-cookie',cookies);
  if(response.body) Readable.fromWeb(response.body).pipe(res);else res.end();
}
