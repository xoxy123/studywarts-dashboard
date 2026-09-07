-- Quote of the week, with a queue.
--
-- A quote is bound to an ISO week rather than to a position in a list, which
-- is what makes the queue advance on its own: the page shows the row whose
-- week is the current one, and next Monday a different row becomes current
-- without anybody moving anything.
--
-- `week` is unique, so two people cannot both claim the same week — the
-- second insert is rejected and the page retries on the following free week
-- instead of quietly overwriting the first person's quote.

create table if not exists public.dash_quotes (
  id text primary key,
  text text not null,
  author text not null default '',
  week text not null unique,          -- ISO week, e.g. 2026-W37
  created_at timestamptz not null default now()
);

alter table public.dash_quotes enable row level security;

drop policy if exists "code holders dash_quotes" on public.dash_quotes;
create policy "code holders dash_quotes" on public.dash_quotes
  for all to anon, authenticated
  using (public.dash_code_ok())
  with check (public.dash_code_ok());

grant select, insert, update, delete on public.dash_quotes to anon, authenticated;

do $$
begin
  alter publication supabase_realtime add table public.dash_quotes;
exception when duplicate_object then null;
end
$$;
