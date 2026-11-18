create table public.recipe_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  blob_path text not null unique,
  content_type text not null,
  byte_size integer not null check (byte_size between 1 and 4194304),
  created_at timestamptz not null default now()
);
create index recipe_photos_owner_idx on public.recipe_photos(user_id);
alter table public.recipe_photos enable row level security;
revoke all on public.recipe_photos from public;

create table tweak_migrations.mobile_login (
  id uuid primary key default gen_random_uuid(),
  challenge text not null check (length(challenge) = 64),
  code_hash text,
  encrypted_session text,
  expires_at timestamptz not null default now() + interval '10 minutes'
);
