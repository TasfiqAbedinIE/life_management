alter table public.user_settings
  add column if not exists weekend_days integer[] not null
  default array[6, 7];

alter table public.user_settings
  drop constraint if exists user_settings_weekend_days_valid;

alter table public.user_settings
  add constraint user_settings_weekend_days_valid check (
    cardinality(weekend_days) between 1 and 7
    and weekend_days <@ array[1, 2, 3, 4, 5, 6, 7]
  );
