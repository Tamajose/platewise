\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values ('71111111-1111-4111-8111-111111111111');
select public.pw_profile_write('71111111-1111-4111-8111-111111111111',
  '{"height_cm":170,"weight_kg":70,"daily_calorie_target":2200,"water_goal_ml":2100,"preferred_units":"metric","timezone":"Asia/Dhaka","preferred_language":"en"}');
insert into public.target_history values ('71111111-1111-4111-8111-111111111111', ((now() at time zone 'Asia/Dhaka')::date-4), 1800);

set local role service_role;
do $$
declare uid uuid:='71111111-1111-4111-8111-111111111111';
  p jsonb:='{"id":"78888888-1111-4111-8111-111111111111","amount_ml":250}'; w jsonb;
  c jsonb:='{"id":"79999999-1111-4111-8111-111111111111","food_key":"rice","grams":140,"calorie_low":145,"calorie_high":190}';
begin
  w:=public.pw_water_write(uid,'log_water',p);
  perform public.pw_water_write(uid,'log_water',p);
  if (select count(*) from public.water_logs where user_id=uid) <> 1 then raise exception 'Duplicate water entry'; end if;
  w:=public.pw_water_write(uid,'edit_water',p || jsonb_build_object('amount_ml',380,'expected_updated_at',w->>'updated_at'));
  if (w->>'amount_ml')::int <> 380 then raise exception 'Wrong edited water amount'; end if;
  perform public.pw_water_write(uid,'delete_water',p);
  begin
    perform public.pw_water_write(uid,'log_water',p);
    raise exception 'Water entry resurrected on retry';
  exception when raise_exception then if sqlerrm <> 'NOT_FOUND' then raise; end if;
  end;
  begin
    perform public.pw_share(uid,'share_correction',c);
    raise exception 'Contribution accepted without consent';
  exception when raise_exception then if sqlerrm <> 'CONSENT_REQUIRED' then raise; end if;
  end;
  perform public.pw_share(uid,'correction_consent','{"enabled":true}');
  perform public.pw_share(uid,'share_correction',c);
  if (select count(*) from public.food_corrections where user_id=uid) <> 1 then raise exception 'Correction was not queued'; end if;
  perform public.pw_share(uid,'correction_consent','{"enabled":false}');
  if exists(select 1 from public.food_corrections where user_id=uid) then raise exception 'Withdrawal did not delete corrections'; end if;
end;
$$;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','71111111-1111-4111-8111-111111111111',true);
do $$
declare overview jsonb:=public.pw_overview();
begin
  if (overview->'targets'->0->>'target_kcal')::integer <> 1800
    or (overview->'targets'->1->>'target_kcal')::integer <> 2200
    then raise exception 'Historical target was not preserved'; end if;
  if jsonb_array_length(overview->'water')<>0 then raise exception 'Water deletion did not update overview'; end if;
end;
$$;
reset role;

-- Keep the synthetic Storage row inside a savepoint so it can be rolled back.
savepoint with_storage_object;
set local role authenticated;
insert into storage.objects(bucket_id,name,owner_id)
  values ('meal-media','71111111-1111-4111-8111-111111111111/73333333-3333-4333-8333-333333333333.jpg','71111111-1111-4111-8111-111111111111');
reset role;
do $$
declare uid uuid:='71111111-1111-4111-8111-111111111111';
begin
  perform public.pw_delete_begin(uid,false);
  begin
    perform public.pw_delete_finalize(uid,false);
    raise exception 'Final deletion accepted retained image';
  exception when raise_exception then if sqlerrm <> 'STORAGE_PENDING' then raise; end if;
  end;
  if not exists(select 1 from public.deletion_jobs where user_id=uid) then raise exception 'Deletion job lost'; end if;
end;
$$;
rollback to savepoint with_storage_object;
release savepoint with_storage_object;

do $$
declare uid uuid:='71111111-1111-4111-8111-111111111111'; r jsonb;
begin
  perform public.pw_delete_begin(uid,false);
  r:=public.pw_delete_finalize(uid,false);
  if (r->>'delete_account')::boolean
    or not exists(select 1 from auth.users where id=uid)
    or exists(select 1 from public.profiles where user_id=uid)
    or exists(select 1 from public.target_history where user_id=uid)
    or exists(select 1 from public.deletion_jobs where user_id=uid)
    then raise exception 'Delete-data postcondition failed'; end if;
end;
$$;
rollback;
