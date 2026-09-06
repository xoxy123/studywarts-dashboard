-- Tables for the two-person Studywarts dashboard, in the Supabase project
-- William owns (natlrlvtbgbyypzworge). Run once, in the SQL editor.
--
-- WHO CAN SEE IT. Anyone can sign up to a Supabase project by default, so
-- "any logged-in user" would put the budget in front of anyone who found the
-- page. Instead there is a seat table: the FIRST TWO accounts that ever sign
-- up claim the two seats, and every policy below asks whether the caller
-- holds one. A third person can still create an account — they just see an
-- empty dashboard and cannot write to it.
--
-- So: both of you sign up first, before you send the link anywhere.

create table if not exists public.dash_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now()
);

create or replace function public.dash_claim_seat()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.dash_members) < 2 then
    insert into public.dash_members (user_id) values (new.id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists dash_claim_seat_trigger on auth.users;
create trigger dash_claim_seat_trigger
after insert on auth.users
for each row execute function public.dash_claim_seat();

-- A seat holder, asked once per policy.
create or replace function public.dash_is_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.dash_members where user_id = auth.uid());
$$;

grant execute on function public.dash_is_member() to authenticated;

-- ---------------------------------------------------------------------------
-- The data
-- ---------------------------------------------------------------------------

create table if not exists public.dash_feedback (
  id text primary key,
  title text not null,
  detail text not null default '',
  section text not null default '',
  status text not null default 'open' check (status in ('open', 'fixed')),
  author text not null default '',
  fixed_by text,
  fixed_at timestamptz,
  images jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.dash_purchases (
  id text primary key,
  label text not null,
  amount numeric(12, 2) not null default 0,
  category text not null default 'Övrigt',
  kind text not null default 'expense' check (kind in ('expense', 'income')),
  on_date date not null default current_date,
  author text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.dash_videos (
  id text primary key,
  title text not null,
  platform text not null default 'TikTok',
  status text not null default 'Idé',
  hook text not null default '',
  script text not null default '',
  images jsonb not null default '[]'::jsonb,
  author text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.dash_goals (
  id text primary key,
  title text not null,
  kind text not null default 'number' check (kind in ('number', 'milestone')),
  target numeric(12, 2) not null default 0,
  current numeric(12, 2) not null default 0,
  unit text not null default '',
  done boolean not null default false,
  due date,
  images jsonb not null default '[]'::jsonb,
  author text not null default '',
  created_at timestamptz not null default now()
);

-- One picture per row, compressed in the browser to well under a megabyte.
-- Separate from the item it belongs to so a list renders before any picture
-- has been fetched.
create table if not exists public.dash_images (
  id text primary key,
  url text not null,
  name text not null default 'bild',
  created_at timestamptz not null default now()
);

create table if not exists public.dash_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb
);

-- ---------------------------------------------------------------------------
-- Row-level security: seat holders only, on every table
-- ---------------------------------------------------------------------------

alter table public.dash_members enable row level security;
alter table public.dash_feedback enable row level security;
alter table public.dash_purchases enable row level security;
alter table public.dash_videos enable row level security;
alter table public.dash_goals enable row level security;
alter table public.dash_images enable row level security;
alter table public.dash_settings enable row level security;

create policy "seat holders read members" on public.dash_members
  for select to authenticated using (public.dash_is_member());

do $$
declare
  t text;
begin
  foreach t in array array[
    'dash_feedback', 'dash_purchases', 'dash_videos',
    'dash_goals', 'dash_images', 'dash_settings'
  ]
  loop
    execute format('drop policy if exists "seat holders read %1$s" on public.%1$I', t);
    execute format('drop policy if exists "seat holders write %1$s" on public.%1$I', t);
    execute format(
      'create policy "seat holders read %1$s" on public.%1$I for select to authenticated using (public.dash_is_member())', t);
    execute format(
      'create policy "seat holders write %1$s" on public.%1$I for all to authenticated using (public.dash_is_member()) with check (public.dash_is_member())', t);
  end loop;
end
$$;

-- Live updates between the two of you.
do $$
declare
  t text;
begin
  foreach t in array array[
    'dash_feedback', 'dash_purchases', 'dash_videos', 'dash_goals', 'dash_settings'
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end
$$;

-- Should print six tables and, once you have both signed up, two seats.
select
  (select count(*) from information_schema.tables
     where table_schema = 'public' and table_name like 'dash\_%') as dash_tables,
  (select count(*) from public.dash_members) as seats_taken;
