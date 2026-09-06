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
