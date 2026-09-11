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
