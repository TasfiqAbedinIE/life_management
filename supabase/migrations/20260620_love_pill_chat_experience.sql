alter table public.couple_love_pills
  add column if not exists read_at timestamptz;

-- Pills created before read receipts existed should not appear as new alerts.
update public.couple_love_pills
set read_at = created_at
where read_at is null;

create index if not exists couple_love_pills_unread_lookup_idx
  on public.couple_love_pills (couple_id, sender_id, created_at desc)
  where read_at is null;

drop policy if exists couple_love_pills_mark_received_read
  on public.couple_love_pills;

create policy couple_love_pills_mark_received_read
on public.couple_love_pills
for update
to authenticated
using (
  sender_id <> (select auth.uid())
  and public.is_active_couple_member(couple_id)
)
with check (
  sender_id <> (select auth.uid())
  and read_at is not null
  and public.is_active_couple_member(couple_id)
);

-- Only the read receipt column may be changed through the client API.
revoke update on public.couple_love_pills from authenticated;
grant update (read_at) on public.couple_love_pills to authenticated;

create table if not exists public.couple_love_pill_preferences (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  background_key text not null default 'blush',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (couple_id, user_id),
  constraint couple_love_pill_background_key_length
    check (char_length(background_key) between 1 and 120)
);

alter table public.couple_love_pill_preferences enable row level security;

drop policy if exists couple_love_pill_preferences_select_own
  on public.couple_love_pill_preferences;
create policy couple_love_pill_preferences_select_own
on public.couple_love_pill_preferences
for select
to authenticated
using (
  user_id = (select auth.uid())
  and public.is_active_couple_member(couple_id)
);

drop policy if exists couple_love_pill_preferences_insert_own
  on public.couple_love_pill_preferences;
create policy couple_love_pill_preferences_insert_own
on public.couple_love_pill_preferences
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and public.is_active_couple_member(couple_id)
);

drop policy if exists couple_love_pill_preferences_update_own
  on public.couple_love_pill_preferences;
create policy couple_love_pill_preferences_update_own
on public.couple_love_pill_preferences
for update
to authenticated
using (
  user_id = (select auth.uid())
  and public.is_active_couple_member(couple_id)
)
with check (
  user_id = (select auth.uid())
  and public.is_active_couple_member(couple_id)
);

grant select, insert, update on public.couple_love_pill_preferences
  to authenticated;
