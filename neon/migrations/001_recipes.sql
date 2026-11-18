-- Staging schema: deliberately closed to application clients until cutover.
-- Existing Supabase owner IDs are preserved; account linking is a later,
-- explicit operation after the replacement login has been verified.
create table public.dishes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  description text not null default '',
  status text not null default 'in_testing',
  best_version uuid,
  created_at timestamptz not null default now(),
  legacy_payload jsonb
);

create table public.dish_versions (
  id uuid primary key default gen_random_uuid(),
  dish_id uuid not null references public.dishes(id) on delete cascade,
  version_number integer not null check (version_number > 0),
  ingredients text[] not null default '{}',
  directions text[] not null default '{}',
  notes text not null default '',
  tags text[] not null default '{}',
  status text not null default 'in_testing',
  photo_paths text[] not null default '{}' check (cardinality(photo_paths) <= 10),
  created_at timestamptz not null default now(),
  legacy_payload jsonb,
  unique (dish_id, version_number),
  unique (dish_id, id)
);

alter table public.dishes add constraint dishes_best_version_fkey
  foreign key (id, best_version) references public.dish_versions(dish_id, id)
  deferrable initially deferred;

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  title text not null default '',
  content text not null default '',
  tags text[] not null default '{}',
  created_at timestamptz not null default now(),
  legacy_payload jsonb
);

create index dishes_user_created_idx on public.dishes (user_id, created_at desc);
create index notes_user_created_idx on public.notes (user_id, created_at desc);

alter table public.dishes enable row level security;
alter table public.dish_versions enable row level security;
alter table public.notes enable row level security;
revoke all on public.dishes, public.dish_versions, public.notes from public;

-- No client policies or grants are created by this staging migration.
-- The migration connection owns these tables and is never shipped to Flutter.
create table tweak_migrations.owners (
  legacy_user_id uuid primary key,
  source_email text,
  source_email_verified boolean not null default false,
  neon_user_id uuid unique,
  linked_at timestamptz,
  check ((neon_user_id is null) = (linked_at is null))
);
create table tweak_migrations.imports (
  snapshot_sha256 text primary key,
  imported_at timestamptz not null default now(),
  counts jsonb not null
);
