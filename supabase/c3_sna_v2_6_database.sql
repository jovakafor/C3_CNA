-- C3 SNA v2.6 database notes. Already applied to your Supabase project by Claude.
-- Kept here so the repo has a record. Safe to run again.
-- Earlier today (already in place): only jovakafor@gmail.com can be administrator,
-- churches.photo and churches.verified_at columns, and mark_church_verified().
-- Added now: a church is marked verified only right after a fresh emailed code.
create or replace function public.mark_church_verified()
returns boolean language plpgsql security definer set search_path to 'public' as $$
declare ok boolean; fresh boolean; sid uuid;
begin
  select (u.email is not null and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false)),
         (u.email_confirmed_at > now() - interval '15 minutes')
    into ok, fresh from auth.users u where u.id = auth.uid();
  if not coalesce(ok,false) then return false; end if;
  begin sid := (auth.jwt()->>'session_id')::uuid; exception when others then sid := null; end;
  if not coalesce(fresh,false) and not exists (
       select 1 from auth.mfa_amr_claims m
        where m.session_id = sid
          and m.authentication_method in ('otp','magiclink','email/signup','email_change','recovery')
          and m.updated_at > now() - interval '15 minutes') then
    return false;
  end if;
  perform set_config('c3.allow_verify','1',true);
  update public.churches set verified_at = now() where owner = auth.uid() and verified_at is null;
  return true;
end $$;
revoke all on function public.mark_church_verified() from public, anon;
grant execute on function public.mark_church_verified() to authenticated;
