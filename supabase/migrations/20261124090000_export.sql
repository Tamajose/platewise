-- Stats export: the same shape as pw_overview, over a longer window that the
-- person chooses. The window is 7 to 365 days and never reaches back past the
-- first day that has any meal or water record, but it is never shorter than
-- 7 days.
create function public.pw_export(p_days integer)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare uid uuid := auth.uid(); p public.profiles; local_day date; first_day date;
  available integer; chosen integer; since_time timestamptz; until_time timestamptz; start_day date;
begin
  if p_days is null or p_days < 7 or p_days > 365 then
    raise exception 'Export length must be 7 to 365 days.' using errcode='22023';
  end if;
  select * into p from public.profiles where user_id=uid;
  if p.user_id is null then
    return jsonb_build_object('profile',null);
  end if;
  local_day := (now() at time zone p.timezone)::date;
  first_day := least(
    (select (min(consumed_at) at time zone p.timezone)::date from public.meals where user_id=uid),
    (select (min(logged_at) at time zone p.timezone)::date from public.water_logs where user_id=uid));
  available := case when first_day is null then 0 else local_day-first_day+1 end;
  chosen := least(p_days, greatest(7, available));
  start_day := local_day-(chosen-1);
  since_time := start_day::timestamp at time zone p.timezone;
  until_time := (local_day+1)::timestamp at time zone p.timezone;
  return jsonb_build_object('profile',to_jsonb(p),'local_day',local_day,
    'requested_days',p_days,'days',chosen,'available_days',available,
    'meals',coalesce((select jsonb_agg(public.pw_meal_json(m.id) order by consumed_at)
      from public.meals m where user_id=uid and consumed_at>=since_time and consumed_at<until_time),'[]'::jsonb),
    'targets',coalesce((select jsonb_agg(jsonb_build_object('effective_on',effective_on,'target_kcal',target_kcal) order by effective_on)
      from public.target_history where user_id=uid and effective_on<=local_day and effective_on>=coalesce(
        (select max(effective_on) from public.target_history where user_id=uid and effective_on<=start_day),start_day
      )),'[]'::jsonb),
    'water',coalesce((select jsonb_agg(to_jsonb(w) order by logged_at)
      from public.water_logs w where user_id=uid and logged_at>=since_time and logged_at<until_time),'[]'::jsonb));
end;
$$;

revoke all on function public.pw_export(integer) from public,anon;
grant execute on function public.pw_export(integer) to authenticated;
