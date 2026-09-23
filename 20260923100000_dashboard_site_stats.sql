-- Site numbers (studywarts.com), one row per weekly reading — same shape as
-- 20260909210000_dashboard_tiktok_stats.sql: a dated snapshot rather than a
-- running total, because a number means nothing without the window it covers
-- and the day it was read.
--
-- Unlike the TikTok reading, this one has FOUR separate logged-in sources —
-- Lovable's project analytics, Lovable Cloud (Users), Stripe (subscriptions,
-- MRR) and PostHog (unique visitors) — and any one of them can be unreachable
-- on a given Sunday without the others being blocked. So every figure column
-- is nullable: a missing number is stored as null, never guessed, never
-- estimated, and never defaulted to 0. `sources` records, per field, where a
-- populated number came from (or why it is null that week).
--
-- Rows are never edited. A second reading is a second row, and the page shows
-- the newest one and the movement since the row before it, so a mistaken
-- reading can be dropped without taking the history with it.

create table if not exists public.dash_site_stats (
  id text primary key,                 -- 'site-YYYY-MM-DD'
  taken_on date not null unique,       -- the day the numbers were read
  window_days int not null default 7,  -- the period the figures cover
  visitors int,                        -- unique visitors, window_days (Lovable analytics / PostHog)
  pageviews int,                       -- Lovable analytics
  users_total int,                     -- Lovable Cloud -> Users, total accounts
  users_new int,                       -- Lovable Cloud -> Users, new in window_days
  subs_total int,                      -- Stripe, active subscriptions, all plans
  subs_plus_monthly int,               -- Stripe, StudyWarts Plus, monthly billing
  subs_plus_annual int,                -- Stripe, StudyWarts Plus, annual billing
  subs_premium_monthly int,            -- Stripe, StudyWarts Premium, monthly billing
  subs_premium_annual int,             -- Stripe, StudyWarts Premium, annual billing
  mrr_sek numeric,                     -- Stripe Billing overview, MRR in SEK
  sources jsonb not null default '{}'::jsonb,  -- {field: "where it came from, or why it's null"}
  note text not null default '',
  author text not null default '',
  created_at timestamptz not null default now()
);

alter table public.dash_site_stats enable row level security;

drop policy if exists "code holders dash_site_stats" on public.dash_site_stats;
create policy "code holders dash_site_stats" on public.dash_site_stats
  for all to anon, authenticated
  using (public.dash_code_ok())
  with check (public.dash_code_ok());

grant select, insert, update, delete on public.dash_site_stats to anon, authenticated;

do $$
begin
  alter publication supabase_realtime add table public.dash_site_stats;
exception when duplicate_object then null;
end
$$;
