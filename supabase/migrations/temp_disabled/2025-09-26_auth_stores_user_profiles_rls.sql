-- Migration: RLS + columns for stores & user_profiles (Plan A)
-- Admin user provided by user: phamg7800@gmail.com
-- Admin user_id:
--   0578be5b-c052-4783-a38f-018e598ebbab

begin;

-- =============================
-- STORES: add created_by column
-- =============================
-- 1) Add column (nullable first)
alter table if exists public.stores
  add column if not exists created_by uuid;

-- 2) Set default for new rows
alter table if exists public.stores
  alter column created_by set default auth.uid();

-- 3) Backfill existing rows with admin user id
update public.stores
set created_by = '0578be5b-c052-4783-a38f-018e598ebbab'
where created_by is null;

-- 4) Enforce NOT NULL after backfill
alter table if exists public.stores
  alter column created_by set not null;

-- 5) Enable RLS and create policies
alter table if exists public.stores enable row level security;

-- Insert policy: allow authenticated to insert own rows
drop policy if exists stores_insert_authenticated on public.stores;
create policy stores_insert_authenticated
on public.stores
for insert
to authenticated
with check (created_by = auth.uid());

-- Select policy: allow reading only own stores
drop policy if exists stores_select_own on public.stores;
create policy stores_select_own
on public.stores
for select
to authenticated
using (created_by = auth.uid());

-- Update policy: allow updating only own stores
drop policy if exists stores_update_own on public.stores;
create policy stores_update_own
on public.stores
for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

-- Optional: protect delete (comment out if not needed)
-- drop policy if exists stores_delete_own on public.stores;
-- create policy stores_delete_own
-- on public.stores
-- for delete
-- to authenticated
-- using (created_by = auth.uid());

-- Optional: unique constraint on store_code
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'stores_store_code_key'
  ) then
    alter table public.stores add constraint stores_store_code_key unique (store_code);
  end if;
end $$;


-- ==================================
-- USER_PROFILES: self RLS policies
-- ==================================
-- 1) Enable RLS
alter table if exists public.user_profiles enable row level security;

-- 2) Insert: only self id
drop policy if exists user_profiles_insert_self on public.user_profiles;
create policy user_profiles_insert_self
on public.user_profiles
for insert
to authenticated
with check (id = auth.uid());

-- 3) Select: only self
drop policy if exists user_profiles_select_self on public.user_profiles;
create policy user_profiles_select_self
on public.user_profiles
for select
to authenticated
using (id = auth.uid());

-- 4) Update: only self
drop policy if exists user_profiles_update_self on public.user_profiles;
create policy user_profiles_update_self
on public.user_profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

commit;
