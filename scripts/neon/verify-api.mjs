import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { connectDatabase, reportError } from './db.mjs';
import { recipeOperation } from '../../server/recipes.mjs';

let db;
try {
  db=await connectDatabase();await db.query('begin');
  await db.query("select pg_advisory_xact_lock(hashtext('tweak:data-import'))");
  const {rows:sourceOwners}=await db.query('select * from tweak_migrations.owners');
  const fake={id:randomUUID(),email:'unused@example.invalid',emailVerified:true};
  assert.deepEqual(await recipeOperation(db,fake,'GET','dishes'),[]);
  const {rows:sourceDishes}=await db.query('select id,user_id from public.dishes');
  await assert.rejects(()=>recipeOperation(db,fake,'DELETE',`dishes/${sourceDishes[0].id}`),{status:404});
  const eligible=sourceOwners.find(row=>row.source_email_verified);
  if(!eligible)throw new Error('A source owner with verified email is needed to test restoration.');
  const user={id:randomUUID(),email:eligible.source_email,emailVerified:true};
  await assert.rejects(()=>recipeOperation(db,{...user,emailVerified:false},'POST','account/claim'),{status:403});
  await recipeOperation(db,user,'POST','account/claim');
  const dishes=await recipeOperation(db,user,'GET','dishes');
  assert.equal(dishes.length,sourceDishes.filter(row=>row.user_id===eligible.legacy_user_id).length);
  assert(dishes.every(row=>sourceDishes.find(source=>source.id===row.id).user_id===eligible.legacy_user_id));
  const other=sourceDishes.find(row=>row.user_id!==eligible.legacy_user_id);
  if(other)await assert.rejects(()=>recipeOperation(db,user,'GET',`dishes/${other.id}`),{status:404});
  const body={name:'Temporary migration API verification',description:'Temporary',status:'in_testing',
    ingredients:['1 tsp salt'],directions:['Mix'],notes:'Preserve',tags:['test'],photo_paths:[]};
  const created=await recipeOperation(db,user,'POST','dishes',body);
  const versions=await recipeOperation(db,user,'GET',`dishes/${created.id}/versions`);
  assert.equal(versions.length,1);
  const next=await recipeOperation(db,user,'POST',`dishes/${created.id}/versions`,{...body,base_version_id:versions[0].id});
  assert.equal(next.version_number,2);
  await recipeOperation(db,user,'PATCH',`dishes/${created.id}/best`,{version_id:next.id});
  await recipeOperation(db,user,'PATCH',`versions/${next.id}`,{...body,notes:'Updated'});
  await recipeOperation(db,user,'DELETE',`versions/${next.id}`);
  assert.equal((await recipeOperation(db,user,'GET',`dishes/${created.id}`)).best_version,null);
  await recipeOperation(db,user,'DELETE',`dishes/${created.id}`);
  const note=await recipeOperation(db,user,'POST','notes',{title:'Temporary',content:'Notebook',tags:[]});
  await assert.rejects(()=>recipeOperation(db,fake,'DELETE',`notes/${note.id}`),{status:404});
  await recipeOperation(db,user,'PATCH',`notes/${note.id}`,{title:'Changed',content:'Notebook',tags:['x']});
  await recipeOperation(db,user,'DELETE',`notes/${note.id}`);
  await db.query('rollback');
  console.log(JSON.stringify({cross_account_access_denied:true,verified_restoration:true,
    recipe_crud:true,version_crud:true,note_crud:true,all_test_changes_rolled_back:true},null,2));
}catch(error){if(db)await db.query('rollback').catch(()=>{});reportError(error);}
finally{await db?.end();}
