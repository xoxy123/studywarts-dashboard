-- Somewhere to put the actual video files.
--
-- Links were the wrong answer: "infoga oeditad video här" means dropping the
-- clip in, not fetching a share URL from another app first. So the page
-- uploads to this bucket and stores the resulting URL.
--
-- PUBLIC READ, CODE-GATED WRITE. Two reasons the read side is open:
-- a <video> element cannot carry a request header, so a private bucket would
-- need every card to sign a URL and re-sign it before it expired; and the
-- paths are random ids nobody can guess. The clips are unedited marketing
-- footage — an unlisted URL is the same protection an unlisted upload gets
-- anywhere else. Writing is gated on the same code as every table.
--
-- 50 MB per file is the free plan's own ceiling, not a number chosen here;
-- setting the bucket higher would not raise it. Total storage on that plan is
-- about 1 GB, which is a handful of phone clips — delete a finished video once
-- it is published.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'dash-videos',
  'dash-videos',
  true,
  52428800,
  array[
    'video/mp4', 'video/quicktime', 'video/webm', 'video/x-m4v',
    'video/mpeg', 'video/3gpp', 'video/x-matroska'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Reading is what a <video> tag does, and it cannot present the code.
drop policy if exists "anyone reads dash videos" on storage.objects;
create policy "anyone reads dash videos" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'dash-videos');

-- Writing is gated. If the storage service turns out not to forward the
-- header the way PostgREST does, these three policies deny every upload
-- rather than allowing one — a locked door, never an open one.
drop policy if exists "code holders upload dash videos" on storage.objects;
create policy "code holders upload dash videos" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'dash-videos' and public.dash_code_ok());

drop policy if exists "code holders replace dash videos" on storage.objects;
create policy "code holders replace dash videos" on storage.objects
  for update to anon, authenticated
  using (bucket_id = 'dash-videos' and public.dash_code_ok())
  with check (bucket_id = 'dash-videos' and public.dash_code_ok());

drop policy if exists "code holders delete dash videos" on storage.objects;
create policy "code holders delete dash videos" on storage.objects
  for delete to anon, authenticated
  using (bucket_id = 'dash-videos' and public.dash_code_ok());
