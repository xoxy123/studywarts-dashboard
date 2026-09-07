-- The video tab becomes a hand-off, not a list.
--
-- One person drops an unedited clip and writes what should be done to it; the
-- other edits it and marks it done; the finished cut goes below. Ideas of any
-- kind — a slideshow, a thumbnail, anything not yet a clip — sit in their own
-- lane so they never look like work that is waiting on somebody.
--
-- WITHOUT THIS MIGRATION THE VIDEO TAB CANNOT SAVE ANYTHING. The page inserts
-- `lane`, `raw_url` and `edit_notes`, and PostgREST answers a column it does
-- not know with `PGRST204` and a 400 — which looks from the outside like a
-- button that does nothing. Measured against the live project on 2026-09-07:
--
--   Could not find the 'edit_notes' column of 'dash_videos' in the schema cache
--
-- `lane` is what the three sections read. The existing `status` stays for the
-- production stage inside the manuscript editor; the two answer different
-- questions and collapsing them would lose one of them.

alter table public.dash_videos
  add column if not exists lane text not null default 'idea',
  add column if not exists raw_url text not null default '',
  add column if not exists final_url text not null default '',
  add column if not exists edit_notes text not null default '',
  add column if not exists done_at timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'dash_videos_lane_check') then
    alter table public.dash_videos
      add constraint dash_videos_lane_check check (lane in ('idea', 'edit', 'done'));
  end if;
end
$$;

-- Anything already in the table predates the lanes and is an idea until
-- somebody says otherwise.
update public.dash_videos set lane = 'idea' where lane is null or lane = '';

create index if not exists dash_videos_lane_idx on public.dash_videos(lane, updated_at desc);
