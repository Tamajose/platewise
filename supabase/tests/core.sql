\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values ('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222');
select public.pw_profile_write('11111111-1111-4111-8111-111111111111',
  '{"height_cm":172,"weight_kg":67,"daily_calorie_target":1200,"water_goal_ml":2000,"preferred_units":"metric","timezone":"Asia/Dhaka","preferred_language":"en"}');
do $$
begin
  begin
    perform public.pw_profile_write('11111111-1111-4111-8111-111111111111',
      '{"height_cm":172,"weight_kg":67,"daily_calorie_target":1199,"water_goal_ml":2000,"preferred_units":"metric","timezone":"Asia/Dhaka","preferred_language":"en"}');
    raise exception 'Below-floor target was accepted';
  exception when check_violation then null;
  end;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111', true);
insert into storage.objects(bucket_id,name,owner_id)
values ('meal-media','11111111-1111-4111-8111-111111111111/33333333-3333-4333-8333-333333333333.jpg','11111111-1111-4111-8111-111111111111');
reset role;

do $$
declare p jsonb := '{
  "id":"44444444-4444-4444-8444-444444444444", "source":"photo", "confidence":"medium", "assumptions":[],
  "image_storage_path":"11111111-1111-4111-8111-111111111111/33333333-3333-4333-8333-333333333333.jpg",
  "items":[{"name":"Rice","quantity":1,"unit":"cup","calorie_low":201,"calorie_high":220,"nutrient_source":"unavailable","provenance":"manual"}]
}'; r jsonb;
begin
  r := public.pw_meal_write('11111111-1111-4111-8111-111111111111','confirm_meal',p);
  if (r->>'representative_calories')::integer <> 211 then raise exception 'Wrong midpoint'; end if;
  perform public.pw_meal_write('11111111-1111-4111-8111-111111111111','confirm_meal',p);
  if (select count(*) from public.meals) <> 1 then raise exception 'Duplicate confirmation'; end if;
  p := p || jsonb_build_object('expected_updated_at',r->>'updated_at');
  p := jsonb_set(p,'{items,0,calorie_high}','300');
  r := public.pw_meal_write('11111111-1111-4111-8111-111111111111','edit_meal',p);
  if (r->>'representative_calories')::integer <> 251 then raise exception 'Wrong edited midpoint'; end if;
  begin
    perform public.pw_meal_write('11111111-1111-4111-8111-111111111111','edit_meal',p);
    raise exception 'Stale edit was accepted';
  exception when raise_exception then
    if sqlerrm <> 'STALE_MEAL' then raise; end if;
  end;
  if not public.pw_claim_ai('11111111-1111-4111-8111-111111111111',2,2)
    then raise exception 'AI reservation failed'; end if;
  if public.pw_claim_ai('11111111-1111-4111-8111-111111111111',2,2)
    then raise exception 'Quota overrun'; end if;
end;
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$
begin
  if (select count(*) from public.meals) <> 0 or (select count(*) from public.meal_items) <> 0
    or (select count(*) from public.profiles) <> 0 or (select count(*) from storage.objects where bucket_id='meal-media') <> 0
    then raise exception 'Cross-user data access'; end if;
  begin
    insert into storage.objects(bucket_id,name,owner_id) values
      ('meal-media','11111111-1111-4111-8111-111111111111/55555555-5555-4555-8555-555555555555.jpg','22222222-2222-4222-8222-222222222222');
    raise exception 'Cross-user storage write';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.ai_cache;
    raise exception 'Cache is client-readable';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
do $$
declare r jsonb;
begin
  r := public.pw_meal_write('11111111-1111-4111-8111-111111111111','delete_meal','{"id":"44444444-4444-4444-8444-444444444444"}');
  if jsonb_array_length(r->'paths') <> 1 then raise exception 'Photo cleanup omitted'; end if;
  if exists(select 1 from public.meals) or exists(select 1 from public.meal_items) then raise exception 'Log still present'; end if;
  if not exists(select 1 from public.asset_jobs) then raise exception 'Cleanup job lost'; end if;
end;
$$;
rollback;
