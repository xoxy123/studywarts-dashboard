-- The Instruktioner tab: the "Del" instructions handed to Codex, and the
-- decisions taken along the way.
--
-- NOT YET RUN. William asked to see this SQL and its permissions before it is
-- run against the dashboard project (natlrlvtbgbyypzworge). Until it is, the
-- tab says the tables are missing instead of saving anything.
--
-- It only CREATES: two new tables, one new function, their policies, their
-- grants, and two new entries in the realtime publication. It does not alter,
-- drop or write to anything that already exists.
--
-- Permissions are the same as every other dash_ table
-- (20260906210000_dashboard_shared_code.sql): one policy per table that lets
-- a request through only when its x-dash-code header matches, checked by the
-- existing public.dash_code_ok(). Without the code a read returns no rows and
-- a write is refused.

create table if not exists public.dash_instruktioner (
  id uuid primary key default gen_random_uuid(),
  nummer text not null,                                  -- "150", "142b"
  titel text not null default '',
  text text not null default '',                         -- the whole block, exactly as pasted
  status text not null default 'ny'
    check (status in ('ny', 'skickad', 'klar', 'kontrollerad')),
  kontrollpunkter jsonb not null default '[]'::jsonb,    -- [{ "text": "...", "klar": false }]
  rapport text not null default '',                      -- Codex's answer
  skapad_av text not null default '',
  skapad timestamptz not null default now(),
  uppdaterad timestamptz not null default now()
);

create table if not exists public.dash_beslut (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  datum date not null default current_date,
  kopplad_del text,                                      -- optional, e.g. "150"
  skapad_av text not null default '',
  skapad timestamptz not null default now()
);

alter table public.dash_instruktioner enable row level security;
alter table public.dash_beslut enable row level security;

drop policy if exists "code holders dash_instruktioner" on public.dash_instruktioner;
create policy "code holders dash_instruktioner" on public.dash_instruktioner
  for all to anon, authenticated
  using (public.dash_code_ok())
  with check (public.dash_code_ok());

drop policy if exists "code holders dash_beslut" on public.dash_beslut;
create policy "code holders dash_beslut" on public.dash_beslut
  for all to anon, authenticated
  using (public.dash_code_ok())
  with check (public.dash_code_ok());

grant select, insert, update, delete on public.dash_instruktioner to anon, authenticated;
grant select, insert, update, delete on public.dash_beslut to anon, authenticated;

-- Ticking one checkpoint. Done in the database, one element at a time, so two
-- people ticking two different boxes at the same moment both keep their tick
-- instead of the second write replacing the whole list with a stale copy.
-- SECURITY INVOKER (the default): the update runs as the caller and goes
-- through the same code-holder policy as everything else.
create or replace function public.dash_instr_kryssa(p_id uuid, p_index int, p_klar boolean)
returns void
language sql
set search_path = ''
as $$
  update public.dash_instruktioner
     set kontrollpunkter = jsonb_set(kontrollpunkter, array[p_index::text, 'klar'], to_jsonb(p_klar)),
         uppdaterad = now()
   where id = p_id
     and p_index >= 0
     and p_index < jsonb_array_length(kontrollpunkter);
$$;

grant execute on function public.dash_instr_kryssa(uuid, int, boolean) to anon, authenticated;

-- Live updates, same publication as the other tabs.
do $$
begin
  alter publication supabase_realtime add table public.dash_instruktioner;
exception when duplicate_object then null;
end
$$;

do $$
begin
  alter publication supabase_realtime add table public.dash_beslut;
exception when duplicate_object then null;
end
$$;

-- Should print 2 tables, 2 policies and 2 realtime entries.
select
  (select count(*) from information_schema.tables
     where table_schema = 'public' and table_name in ('dash_instruktioner', 'dash_beslut')) as tables,
  (select count(*) from pg_policies
     where schemaname = 'public' and tablename in ('dash_instruktioner', 'dash_beslut')) as policies,
  (select count(*) from pg_publication_tables
     where pubname = 'supabase_realtime' and tablename in ('dash_instruktioner', 'dash_beslut')) as realtime;
