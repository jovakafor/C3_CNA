-- C3 SNA: Supabase migration for Sunday reports
-- Safe to run more than once. Does NOT delete any column or any data.
-- Run in: Supabase dashboard > SQL Editor > New query > paste > Run.

-- 1. Add the columns the app needs (only if they are missing).
alter table public.reports add column if not exists visitors integer not null default 0;
alter table public.reports add column if not exists membership integer not null default 0;
alter table public.reports add column if not exists those_who_received_christ integer not null default 0;

-- 2. Make sure old rows and any NULLs become 0 (no data is removed).
update public.reports set visitors = 0 where visitors is null;
update public.reports set membership = 0 where membership is null;
update public.reports set those_who_received_christ = 0 where those_who_received_christ is null;

-- 3. If an old text column "decisions" exists, copy plain whole numbers from it
--    into the new column. The old column is kept untouched.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'reports' and column_name = 'decisions'
  ) then
    execute $q$
      update public.reports
         set those_who_received_christ = trim(decisions::text)::integer
       where those_who_received_christ = 0
         and decisions is not null
         and trim(decisions::text) ~ '^[0-9]{1,9}$'
    $q$;
  end if;
end $$;

-- 4. Refresh the PostgREST schema cache so the API sees the new columns now.
notify pgrst, 'reload schema';

-- 5. Quick check: should list the three columns.
select column_name, data_type, column_default
  from information_schema.columns
 where table_schema = 'public' and table_name = 'reports'
   and column_name in ('visitors','membership','those_who_received_christ');
