create table public.water_logs (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  logged_at timestamptz not null default now(),
  amount_ml integer not null check (amount_ml between 1 and 2000),
  updated_at timestamptz not null default now()
);
create index water_logs_user_time_idx on public.water_logs(user_id,logged_at desc);
create table public.removed_entries (
  user_id uuid references auth.users(id) on delete cascade,
  entry_id uuid,
  kind text check (kind in ('meal','water')),
  deleted_at timestamptz not null default now(),
  primary key (user_id,entry_id,kind)
);
create table public.food_corrections (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  food_key text not null check (food_key in ('rice','dal','egg','chana','roti','khichuri')),
  grams integer not null check (grams between 1 and 3000),
  calorie_low integer not null check (calorie_low between 0 and 6000),
  calorie_high integer not null check (calorie_high between calorie_low and 6000),
  consent_version text not null,
  created_at timestamptz not null default now()
);
alter table public.water_logs enable row level security;
alter table public.removed_entries enable row level security;
alter table public.food_corrections enable row level security;
revoke all on public.water_logs,public.removed_entries,public.food_corrections from public,anon,authenticated;
grant select on public.water_logs,public.food_corrections to authenticated;
grant all on public.water_logs,public.removed_entries,public.food_corrections to service_role;
create policy own_water_logs on public.water_logs for select to authenticated using ((select auth.uid())=user_id);
create policy own_corrections on public.food_corrections for select to authenticated using ((select auth.uid())=user_id);

create function public.pw_mark_meal_removed()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from auth.users where id=old.user_id) then
    insert into public.removed_entries(user_id,entry_id,kind) values(old.user_id,old.id,'meal') on conflict do nothing;
    delete from public.ai_cache where user_id=old.user_id;
  end if;
  return old;
end;
$$;
create function public.pw_guard_meal_insert()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.removed_entries where user_id=new.user_id and entry_id=new.id and kind='meal') then
    raise exception 'NOT_FOUND';
  end if;
  return new;
end;
$$;
create trigger mark_meal_removed after delete on public.meals
  for each row execute function public.pw_mark_meal_removed();
create trigger guard_meal_insert before insert on public.meals
  for each row execute function public.pw_guard_meal_insert();
revoke all on function public.pw_mark_meal_removed(),public.pw_guard_meal_insert() from public,anon,authenticated;

create function public.pw_water_write(p_user uuid,p_action text,p_data jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare wid uuid := (p_data->>'id')::uuid; w public.water_logs;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text,741));
  if exists(select 1 from public.deletion_jobs where user_id=p_user) then raise exception 'DELETION_PENDING'; end if;
  select * into w from public.water_logs where user_id=p_user and id=wid;
  case p_action
    when 'delete_water' then
      if w.id is not null then
        insert into public.removed_entries(user_id,entry_id,kind) values(p_user,wid,'water') on conflict do nothing;
        delete from public.water_logs where user_id=p_user and id=wid;
      end if;
      return '{"removed":true}'::jsonb;
    when 'log_water' then
      if w.id is not null then return to_jsonb(w); end if;
      if exists(select 1 from public.removed_entries where user_id=p_user and entry_id=wid and kind='water') then raise exception 'NOT_FOUND'; end if;
      insert into public.water_logs(id,user_id,amount_ml) values(wid,p_user,(p_data->>'amount_ml')::integer) returning * into w;
    when 'edit_water' then
      if w.id is null then raise exception 'NOT_FOUND'; end if;
      if w.updated_at is distinct from (p_data->>'expected_updated_at')::timestamptz then raise exception 'STALE_WATER'; end if;
      update public.water_logs set amount_ml=(p_data->>'amount_ml')::integer,updated_at=clock_timestamp()
        where user_id=p_user and id=wid returning * into w;
    else raise exception 'INVALID_ACTION';
  end case;
  return to_jsonb(w);
end;
$$;

create function public.pw_share(p_user uuid,p_action text,p_data jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare enabled boolean; v text := 'corrections-1';
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text,741));
  if exists(select 1 from public.deletion_jobs where user_id=p_user) then raise exception 'DELETION_PENDING'; end if;
  if p_action='correction_consent' then
    enabled := (p_data->>'enabled')::boolean;
    update public.profiles set correction_consent=enabled,consent_at=now(),consent_version=v,updated_at=now() where user_id=p_user;
    if not found then raise exception 'NOT_FOUND'; end if;
    if not enabled then delete from public.food_corrections where user_id=p_user; end if;
    return jsonb_build_object('enabled',enabled);
  end if;
  if p_action <> 'share_correction' then raise exception 'INVALID_ACTION'; end if;
  if not exists(select 1 from public.profiles where user_id=p_user and correction_consent) then raise exception 'CONSENT_REQUIRED'; end if;
  insert into public.food_corrections(id,user_id,food_key,grams,calorie_low,calorie_high,consent_version)
    values((p_data->>'id')::uuid,p_user,p_data->>'food_key',(p_data->>'grams')::integer,
      (p_data->>'calorie_low')::integer,(p_data->>'calorie_high')::integer,v) on conflict (id) do nothing;
  return '{"submitted":true}'::jsonb;
end;
$$;

create function public.pw_delete_begin(p_user uuid,p_account boolean)
returns jsonb language plpgsql set search_path='' as $$
declare job public.deletion_jobs;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text,741));
  insert into public.deletion_jobs(user_id,delete_account) values(p_user,p_account)
    on conflict(user_id) do update set delete_account = public.deletion_jobs.delete_account or excluded.delete_account
    returning * into job;
  return to_jsonb(job);
end;
$$;

create function public.pw_delete_finalize(p_user uuid,p_account boolean)
returns jsonb language plpgsql set search_path='' as $$
declare job public.deletion_jobs;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text,741));
  select * into job from public.deletion_jobs where user_id=p_user;
  if not found then return jsonb_build_object('delete_account',false); end if;
  if job.delete_account and not p_account then raise exception 'DELETION_PENDING'; end if;
  if exists(select 1 from storage.objects where bucket_id='meal-media' and split_part(name,'/',1)=p_user::text)
    then raise exception 'STORAGE_PENDING'; end if;
  delete from public.meals where user_id=p_user;
  delete from public.water_logs where user_id=p_user;
  delete from public.removed_entries where user_id=p_user;
  delete from public.target_history where user_id=p_user;
  delete from public.food_corrections where user_id=p_user;
  delete from public.ai_usage where user_id=p_user;
  delete from public.ai_cache where user_id=p_user;
  delete from public.asset_jobs where user_id=p_user;
  delete from public.profiles where user_id=p_user;
  if job.delete_account then
    update public.deletion_jobs set rows_cleared_at=now() where user_id=p_user;
  else
    delete from public.deletion_jobs where user_id=p_user;
  end if;
  return jsonb_build_object('delete_account',job.delete_account);
end;
$$;

create function public.pw_sweep()
returns jsonb language plpgsql security definer set search_path='' as $$
declare media record;
begin
  delete from public.ai_cache where expires_at < now();
  delete from public.ai_usage where utc_day < (now() at time zone 'UTC')::date - 2;
  delete from public.removed_entries where deleted_at < now() - interval '30 days';
  for media in
    select s.name,u.id as uid from storage.objects s join auth.users u on s.owner_id=u.id::text
    where s.bucket_id='meal-media' and split_part(s.name,'/',1)=u.id::text
      and s.created_at<now()-interval '24 hours'
      and not exists(select 1 from public.meals where image_storage_path=s.name)
      and not exists(select 1 from public.asset_jobs where path=s.name)
    order by s.created_at limit 100
  loop
    if pg_try_advisory_xact_lock(hashtextextended(media.uid::text,741))
      and not exists(select 1 from public.meals where image_storage_path=media.name) then
      insert into public.asset_jobs(path,user_id) values(media.name,media.uid) on conflict do nothing;
    end if;
  end loop;
  return (select coalesce(jsonb_agg(path),'[]'::jsonb)
    from (select path from public.asset_jobs order by created_at limit 100) pending);
end;
$$;

revoke all on function public.pw_water_write(uuid,text,jsonb),public.pw_share(uuid,text,jsonb),
  public.pw_delete_begin(uuid,boolean),public.pw_delete_finalize(uuid,boolean),public.pw_sweep() from public,anon,authenticated;
grant execute on function public.pw_water_write(uuid,text,jsonb),public.pw_share(uuid,text,jsonb),
  public.pw_delete_begin(uuid,boolean),public.pw_delete_finalize(uuid,boolean),public.pw_sweep() to service_role;

create or replace function public.pw_overview()
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare uid uuid := auth.uid(); p public.profiles; local_day date; since_time timestamptz; until_time timestamptz;
  job public.deletion_jobs;
begin
  select * into job from public.deletion_jobs where user_id=uid;
  select * into p from public.profiles where user_id=uid;
  local_day := (now() at time zone coalesce(p.timezone,'UTC'))::date;
  since_time := (local_day-6)::timestamp at time zone coalesce(p.timezone,'UTC');
  until_time := (local_day+1)::timestamp at time zone coalesce(p.timezone,'UTC');
  return jsonb_build_object('profile',case when p.user_id is not null then to_jsonb(p) else null end,'local_day',local_day,
    'meals',coalesce((select jsonb_agg(public.pw_meal_json(m.id) order by consumed_at)
      from public.meals m where user_id=uid and consumed_at>=since_time and consumed_at<until_time),'[]'::jsonb),
    'targets',coalesce((select jsonb_agg(jsonb_build_object('effective_on',effective_on,'target_kcal',target_kcal) order by effective_on)
      from public.target_history where user_id=uid and effective_on<=local_day and effective_on>=coalesce(
        (select max(effective_on) from public.target_history where user_id=uid and effective_on<=local_day-6),local_day-6
      )),'[]'::jsonb),
    'water',coalesce((select jsonb_agg(to_jsonb(w) order by logged_at)
      from public.water_logs w where user_id=uid and logged_at>=since_time and logged_at<until_time),'[]'::jsonb),
    'pending_asset_count',(select count(*) from public.asset_jobs where user_id=uid),
    'deletion_pending',job.user_id is not null,
    'deletion_account',coalesce(job.delete_account,false));
end;
$$;

drop function public.pw_store_ai(uuid,text,jsonb);
create function public.pw_store_ai(p_user uuid,p_key text,p_data jsonb,p_started_at timestamptz)
returns void language plpgsql set search_path='' as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text,741));
  if exists(select 1 from public.deletion_jobs where user_id=p_user) or not exists(
    select 1 from public.profiles where user_id=p_user and created_at<=p_started_at
  ) then return; end if;
  insert into public.ai_cache values(p_user,p_key,now()+interval '1 hour',p_data)
    on conflict(user_id,cache_key) do update set expires_at=excluded.expires_at,data=excluded.data;
end;
$$;
revoke all on function public.pw_store_ai(uuid,text,jsonb,timestamptz) from public,anon,authenticated;
grant execute on function public.pw_store_ai(uuid,text,jsonb,timestamptz) to service_role;
