-- Notifications can arrive more than once, and the service puts the
-- application's API key in each one. Remove any key that was stored, and
-- ignore a repeat of the same change.
update public.subscription_events set payload = payload - 'password' where payload ? 'password';

delete from public.subscription_events a using public.subscription_events b
where a.ctid < b.ctid and a.subscriber is not distinct from b.subscriber
  and a.status is not distinct from b.status and a.event_time is not distinct from b.event_time;

alter table public.subscription_events
  add constraint subscription_events_change_key unique (subscriber, status, event_time);
