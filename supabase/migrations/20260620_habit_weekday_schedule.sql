alter table public.habits
  add column if not exists scheduled_weekdays integer[] not null
  default array[1, 2, 3, 4, 5, 6, 7];

alter table public.habits
  drop constraint if exists habits_scheduled_weekdays_valid;

alter table public.habits
  add constraint habits_scheduled_weekdays_valid check (
    cardinality(scheduled_weekdays) between 1 and 7
    and scheduled_weekdays <@ array[1, 2, 3, 4, 5, 6, 7]
  );
