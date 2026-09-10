-- TikTok numbers, one row per reading.
--
-- The dashboard does not talk to TikTok. Nobody has an API key for the account
-- and TikTok Studio is behind a login, so the numbers are read off Studio and
-- written here as a dated snapshot. That is why every figure carries the date
-- it was read and the length of the window it covers: "5 900 views" means
-- nothing without "over the seven days ending 9 September".
--
-- Rows are never edited to keep a running total. A second reading is a second
-- row, and the page shows the newest one and the movement since the row before
-- it. That way a mistaken reading can be dropped without taking the history
-- with it.
--
-- `note` is the written reading of the numbers that goes with that snapshot —
-- what changed and what it suggests doing next — kept beside the figures it
-- describes rather than in a separate document that drifts out of date.

create table if not exists public.dash_tiktok_stats (
  id text primary key,
  taken_on date not null unique,     -- the day the numbers were read
  window_days int not null default 7,-- the period the figures cover
  followers_total int not null default 0,
  followers_gained int not null default 0,
  views int not null default 0,
  likes int not null default 0,
  comments int not null default 0,
  shares int not null default 0,
  profile_views int not null default 0,
  posts_total int not null default 0,
  note text not null default '',
  author text not null default '',
  created_at timestamptz not null default now()
);

alter table public.dash_tiktok_stats enable row level security;

drop policy if exists "code holders dash_tiktok_stats" on public.dash_tiktok_stats;
create policy "code holders dash_tiktok_stats" on public.dash_tiktok_stats
  for all to anon, authenticated
  using (public.dash_code_ok())
  with check (public.dash_code_ok());

grant select, insert, update, delete on public.dash_tiktok_stats to anon, authenticated;

do $$
begin
  alter publication supabase_realtime add table public.dash_tiktok_stats;
exception when duplicate_object then null;
end
$$;
