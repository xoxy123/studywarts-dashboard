-- Swap the two-seat account model for one shared code.
--
-- The page no longer signs anybody in. Instead it sends the code as a request
-- header on every call, and every policy below asks Postgres whether that
-- header matches. That matters: a code checked in JavaScript is decoration,
-- because the publishable key is in the page and anyone can call the API
-- directly with it. Checked here, a request without the header gets nothing —
-- the table returns zero rows and a write is refused.
--
-- What this model does NOT give you: anyone who learns the code has
-- everything, and the only way to take access away from one person is to
-- change the code for both. Change it by editing dash_code_ok below and the
-- one constant in the page.

create or replace function public.dash_code_ok()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    current_setting('request.headers', true)::json ->> 'x-dash-code',
    ''
  ) = 'Morot123';
$$;

-- The gate calls this once so a wrong code says so immediately, instead of
-- looking like an empty dashboard.
create or replace function public.dash_check_code()
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.dash_code_ok();
$$;

grant execute on function public.dash_code_ok() to anon, authenticated;
grant execute on function public.dash_check_code() to anon, authenticated;

-- The seat trigger belongs to the account model and would otherwise keep
-- handing seats to accounts nothing reads any more.
drop trigger if exists dash_claim_seat_trigger on auth.users;
drop function if exists public.dash_claim_seat();

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
    execute format('drop policy if exists "code holders %1$s" on public.%1$I', t);
    execute format(
      'create policy "code holders %1$s" on public.%1$I for all to anon, authenticated '
      'using (public.dash_code_ok()) with check (public.dash_code_ok())', t);

    -- Row-level security decides WHICH rows; the table grant decides whether
    -- the role may ask at all. Without this, every call fails as permission
    -- denied before a single policy is evaluated.
    execute format('grant select, insert, update, delete on public.%I to anon, authenticated', t);
  end loop;
end
$$;

-- dash_members is left in place but is no longer consulted by anything; its
-- own policy is dropped so it stops referring to the account model.
drop policy if exists "seat holders read members" on public.dash_members;

-- Should print six policies, one per table.
select
  (select count(*) from pg_policies
     where schemaname = 'public' and policyname like 'code holders%') as code_policies;
