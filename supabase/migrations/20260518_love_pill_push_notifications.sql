create extension if not exists pg_net with schema extensions;

create schema if not exists private;

create table if not exists private.love_pill_push_config (
  key text primary key,
  value text not null
);

insert into private.love_pill_push_config (key, value)
values
  ('edge_function_url', 'https://zgurszkayljitkfolysj.supabase.co/functions/v1/send-love-pill-push'),
  ('webhook_secret', 'replace-with-a-long-random-secret')
on conflict (key) do nothing;

create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_user_push_tokens_user_id
  on public.user_push_tokens (user_id);

alter table public.user_push_tokens enable row level security;

drop policy if exists "user_push_tokens_select_own" on public.user_push_tokens;
drop policy if exists "user_push_tokens_insert_own" on public.user_push_tokens;
drop policy if exists "user_push_tokens_update_own" on public.user_push_tokens;
drop policy if exists "user_push_tokens_delete_own" on public.user_push_tokens;

create policy "user_push_tokens_select_own"
on public.user_push_tokens
for select
using (user_id = auth.uid());

create policy "user_push_tokens_insert_own"
on public.user_push_tokens
for insert
with check (user_id = auth.uid());

create policy "user_push_tokens_update_own"
on public.user_push_tokens
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "user_push_tokens_delete_own"
on public.user_push_tokens
for delete
using (user_id = auth.uid());

create or replace function public.set_user_push_token_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_user_push_token_updated_at on public.user_push_tokens;
create trigger set_user_push_token_updated_at
before update on public.user_push_tokens
for each row execute function public.set_user_push_token_updated_at();

create or replace function public.enqueue_love_pill_push()
returns trigger
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  function_url text;
  webhook_secret text;
begin
  select value into function_url
  from private.love_pill_push_config
  where key = 'edge_function_url';

  select value into webhook_secret
  from private.love_pill_push_config
  where key = 'webhook_secret';

  if function_url is null
    or webhook_secret is null
    or webhook_secret = 'replace-with-a-long-random-secret'
  then
    return new;
  end if;

  perform net.http_post(
    url := function_url,
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-love-pill-webhook-secret', webhook_secret
    ),
    body := jsonb_build_object('pill_id', new.id)
  );

  return new;
end;
$$;

drop trigger if exists enqueue_love_pill_push on public.couple_love_pills;
create trigger enqueue_love_pill_push
after insert on public.couple_love_pills
for each row execute function public.enqueue_love_pill_push();
