# Studywarts Dashboard

A two-person dashboard for the Studywarts team: feedback filed against a part
of the app, purchases against a monthly budget, video manuscripts, and goals —
with images on any of them.

One page, no build step. It talks to a Supabase project over the publishable
key, which is meant to sit in client code and grants nothing on its own: every
table is behind row-level security that asks whether the caller holds one of
the two seats. The first two accounts to sign up claim those seats; anyone else
who signs up sees an empty dashboard and cannot write to it.

Schema and policies: `dashboard-tables.sql`.

## The Analys tab

The dashboard does not talk to TikTok. Nobody has an API key for the account and
TikTok Studio sits behind a login, so the figures are read by hand from
`tiktok.com/tiktokstudio` for `@studywartsofficial` and written into
`dash_tiktok_stats` as a dated snapshot — one row per reading, each carrying the
length of the window it covers, because "5 900 visningar" means nothing without
"over the seven days ending 9 September".

A second reading is a second row, never an edit, so a mistaken one can be
dropped without taking the history with it. Each row's `note` holds the written
reading of those numbers, and the panel renders it under the figures.

Goal progress comes from whatever rows stand in `dash_goals`: a number goal
counts towards its own target, a milestone counts all or nothing. With no goals
set the panel says so rather than showing a confident 0 %.

Schema: `20260909210000_dashboard_tiktok_stats.sql`. The Supabase project is
`natlrlvtbgbyypzworge`.

### Why the numbers went wrong, and the Sunday schedule that reads them now

The panel always renders the newest row correctly — the bug William reported
("vissa siffror stämmer ej som likes osv") was that nothing added a newer row
after the first one on 9 September, so "the latest reading" sat eleven days
stale while the real account kept moving (likes alone went from 180 to 2 400
over that stretch). The panel now shows a warning banner when the newest
reading is older than its own window plus four days, so a missed week is
visible on the dashboard itself instead of only in a support ticket.

A local Claude Code scheduled task, `studywarts-tiktok-weekly-analysis`
(`~/.claude/scheduled-tasks/studywarts-tiktok-weekly-analysis/SKILL.md`), fires
every Sunday and re-reads `tiktok.com/tiktokstudio` for `@studywartsofficial`
through Claude-in-Chrome — the same manual steps this file already described —
then inserts a new dated row with a fresh written analysis. It needs:

- the Claude Code desktop app running on William's Mac at the scheduled time
  (a task due while the app is closed runs on next launch instead), and
- Chrome signed in to TikTok Studio for `@studywartsofficial` when it fires.

Both are outside what an agent can set up by itself. If a Sunday is missed for
either reason, the stale-reading banner above says so on the dashboard, and
either the next scheduled Sunday run or asking Claude Code to run the
`studywarts-tiktok-weekly-analysis` scheduled task by hand catches it up.
