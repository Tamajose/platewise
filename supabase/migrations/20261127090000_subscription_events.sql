-- Messages that Banglalink's subscription service sends to the
-- subscription-notify function. They hold phone numbers, so nothing but the
-- server may read or write them: row level security is on and no policy or
-- grant lets the public or signed-in roles near the table.
create table public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  received_at timestamptz not null default now(),
  subscriber text,
  status text,
  event_time text,
  payload jsonb not null
);

create index subscription_events_received_idx on public.subscription_events (received_at desc);

alter table public.subscription_events enable row level security;
revoke all on public.subscription_events from public, anon, authenticated;
grant select, insert, delete on public.subscription_events to service_role;
