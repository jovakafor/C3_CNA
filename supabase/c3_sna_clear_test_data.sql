-- C3 SNA: remove test data from before November 2026.
-- The app started in November 2026, so older reports are test data.
-- THIS CANNOT BE UNDONE. Run it once.

-- STEP 1 (look first): how many old reports exist, per church.
-- select church_id, count(*) as old_reports, min(d) as first, max(d) as last
--   from public.reports where d::text < '2026-11-01' group by church_id;

-- STEP 2: delete them.
with gone as (
  delete from public.reports where d::text < '2026-11-01' returning 1
)
select count(*) as deleted_reports from gone;

do $$
begin
  if to_regclass('public.edit_requests') is not null then
    execute 'delete from public.edit_requests where d::text < ''2026-11-01''';
  end if;
end $$;

notify pgrst, 'reload schema';
