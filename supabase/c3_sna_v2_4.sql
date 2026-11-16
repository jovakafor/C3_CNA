-- C3 SNA v2.4 database update
-- Deleting a church now also deletes ALL data it entered. Safe to run many times.
-- Run in: Supabase > SQL Editor > New query > paste > Run.

-- 1. When a church is deleted, delete its reports and edit requests first.
create or replace function public.c3_delete_church_data()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.reports where church_id::text = old.id::text;
  if to_regclass('public.edit_requests') is not null then
    execute 'delete from public.edit_requests where church_id::text = $1' using old.id::text;
  end if;
  return old;
end;
$$;

drop trigger if exists c3_delete_church_data on public.churches;
create trigger c3_delete_church_data
  before delete on public.churches
  for each row execute function public.c3_delete_church_data();

-- 2. Remove leftover data from churches that were already deleted.
delete from public.reports r
 where not exists (select 1 from public.churches c where c.id::text = r.church_id::text);

do $$
begin
  if to_regclass('public.edit_requests') is not null then
    execute 'delete from public.edit_requests e
              where not exists (select 1 from public.churches c where c.id::text = e.church_id::text)';
  end if;
end $$;

-- 3. Refresh the API cache.
notify pgrst, 'reload schema';

-- 4. Check: leftover_reports should be 0.
select
  (select count(*) from public.reports r
    where not exists (select 1 from public.churches c where c.id::text = r.church_id::text)) as leftover_reports;
