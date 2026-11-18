import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import handler from '../api/index.mjs';

const root=resolve('build/web');
const types={'.html':'text/html','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm',
  '.png':'image/png','.jpg':'image/jpeg','.ttf':'font/ttf','.otf':'font/otf','.bin':'application/octet-stream'};
http.createServer(async(req,res)=>{
  try{
    const pathname=new URL(req.url,'http://localhost:8080').pathname;
    if(pathname.startsWith('/api/')){await handler(req,res);return;}
    const file=resolve(root,'.'+decodeURIComponent(pathname==='/'?'/index.html':pathname));
    if(!file.startsWith(root+sep)){res.statusCode=403;res.end();return;}
    await stat(file);res.setHeader('content-type',types[extname(file)]||'application/octet-stream');
    res.end(await readFile(file));
  }catch{res.statusCode=404;res.end('Not found');}
}).listen(8080,'127.0.0.1',()=>console.log('Tweak preview: http://127.0.0.1:8080'));
