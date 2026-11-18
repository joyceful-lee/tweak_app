-- Apply to the same Supabase project used by the phone app and website.
begin;

alter table public.dish_versions
  add column if not exists photo_paths text[] not null default '{}';

alter table public.dish_versions
  add constraint dish_version_photo_limit check (cardinality(photo_paths) <= 10);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('recipe-photos', 'recipe-photos', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "recipe_photos_insert_own" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'recipe-photos' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "recipe_photos_read_own" on storage.objects
  for select to authenticated using (
    bucket_id = 'recipe-photos' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "recipe_photos_delete_own" on storage.objects
  for delete to authenticated using (
    bucket_id = 'recipe-photos' and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Validate paths on every write, including direct updates from another client.
create function public.validate_recipe_photo_paths() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if cardinality(new.photo_paths) > 0 and (
    auth.uid() is null or exists (
      select 1 from unnest(new.photo_paths) as p(path)
      where path is null or split_part(path, '/', 1) <> auth.uid()::text
        or path like '%..%'
    )
  ) then
    raise exception 'Recipe photos must belong to the signed-in user';
  end if;
  return new;
end;
$$;

create trigger validate_recipe_photo_paths
  before insert or update of photo_paths on public.dish_versions
  for each row execute function public.validate_recipe_photo_paths();

-- A separate RPC preserves compatibility with previously released mobile apps.
-- SECURITY INVOKER preserves existing dishes/dish_versions RLS ownership rules.
create function public.create_dish_with_photos(
  p_user_id uuid,
  p_name text,
  p_description text,
  p_status text,
  p_ingredients text[],
  p_directions text[],
  p_notes text,
  p_tags text[],
  p_photo_paths text[]
) returns uuid language plpgsql security invoker set search_path = '' as $$
declare
  new_dish_id uuid;
  dish_values public.dishes;
  version_values public.dish_versions;
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    raise exception 'Not authorized';
  end if;
  -- Let PostgreSQL coerce arrays/JSON and enum statuses to the existing column
  -- types, rather than assuming ingredients and tags are SQL text[] columns.
  select * into dish_values from jsonb_populate_record(null::public.dishes,
    jsonb_build_object('user_id', auth.uid(), 'name', p_name,
      'description', p_description, 'status', p_status));
  select * into version_values from jsonb_populate_record(null::public.dish_versions,
    jsonb_build_object('ingredients', p_ingredients, 'directions', p_directions,
      'notes', p_notes, 'tags', p_tags, 'status', p_status));

  insert into public.dishes (user_id, name, description, status)
    values (dish_values.user_id, dish_values.name, dish_values.description, dish_values.status)
    returning id into new_dish_id;
  insert into public.dish_versions
    (dish_id, version_number, ingredients, directions, notes, tags, status, photo_paths)
    values (new_dish_id, 1, version_values.ingredients, version_values.directions,
      version_values.notes, version_values.tags, version_values.status, p_photo_paths);
  return new_dish_id;
end;
$$;

revoke all on function public.create_dish_with_photos(uuid, text, text, text, text[], text[], text, text[], text[]) from public, anon;
grant execute on function public.create_dish_with_photos(uuid, text, text, text, text[], text[], text, text[], text[]) to authenticated;

commit;
