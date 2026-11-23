create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  height_cm numeric(5,1) not null check (height_cm between 100 and 250),
  weight_kg numeric(5,1) not null check (weight_kg between 30 and 350),
  daily_calorie_target integer check (daily_calorie_target between 1200 and 5000),
  water_goal_ml integer not null default 2000 check (water_goal_ml between 500 and 5000),
  timezone text not null default 'Asia/Dhaka',
  preferred_units text not null check (preferred_units in ('metric','us')),
  preferred_language text not null check (preferred_language in ('en','bn')),
  correction_consent boolean not null default false,
  consent_at timestamptz,
  consent_version text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.target_history (
  user_id uuid references auth.users(id) on delete cascade,
  effective_on date not null,
  target_kcal integer check (target_kcal between 1200 and 5000),
  primary key (user_id, effective_on)
);

create table public.meals (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  consumed_at timestamptz not null,
  source text not null check (source in ('photo','text','voice','menu','comparison','manual','nearby')),
  status text not null default 'confirmed' check (status = 'confirmed'),
  image_storage_path text unique,
  calorie_low integer not null check (calorie_low between 0 and 20000),
  calorie_high integer not null check (calorie_high between calorie_low and 20000),
  representative_calories integer generated always as ((calorie_low + calorie_high + 1) / 2) stored,
  representative_value_method text not null default 'midpoint_rounded' check (representative_value_method = 'midpoint_rounded'),
  confidence text not null check (confidence in ('low','medium','high')),
  user_edited boolean not null default false,
  assumptions jsonb not null default '[]',
  model text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index meals_user_time_idx on public.meals(user_id, consumed_at desc);

create table public.meal_items (
  meal_id uuid not null references public.meals(id) on delete cascade,
  ordinal integer not null check (ordinal between 1 and 16),
  name text not null check (char_length(name) between 1 and 100),
  normalized_food_reference text,
  quantity numeric(9,3) not null check (quantity > 0 and quantity <= 3000),
  unit text not null check (unit in ('g','ml','cup','piece','serving','tbsp','tsp','oz','slice','bowl')),
  estimated_grams numeric check (estimated_grams between 0 and 12000),
  calorie_low integer not null check (calorie_low between 0 and 6000),
  calorie_high integer not null check (calorie_high between calorie_low and 6000),
  protein_g numeric check (protein_g between 0 and 1000),
  carbohydrate_g numeric check (carbohydrate_g between 0 and 1500),
  fat_g numeric check (fat_g between 0 and 1000),
  fiber_g numeric check (fiber_g between 0 and 300),
  sodium_mg numeric check (sodium_mg between 0 and 50000),
  nutrient_source text not null check (nutrient_source in ('unavailable','model_estimate','seeded','reference','manual')),
  provenance text not null check (provenance in ('model','demo','manual','menu_text','reference','scaled')),
  primary key (meal_id, ordinal)
);

create table public.deletion_jobs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  delete_account boolean not null,
  started_at timestamptz not null default now(),
  rows_cleared_at timestamptz
);

create table public.asset_jobs (
  path text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_id uuid,
  created_at timestamptz not null default now(),
  check (path like user_id::text || '/%')
);
create index asset_jobs_user_idx on public.asset_jobs(user_id, meal_id);

alter table public.profiles enable row level security;
alter table public.target_history enable row level security;
alter table public.meals enable row level security;
alter table public.meal_items enable row level security;
alter table public.deletion_jobs enable row level security;
alter table public.asset_jobs enable row level security;

create policy own_profile on public.profiles for select to authenticated using ((select auth.uid()) = user_id);
create policy own_target_history on public.target_history for select to authenticated using ((select auth.uid()) = user_id);
create policy own_meals on public.meals for select to authenticated using ((select auth.uid()) = user_id);
create policy own_items on public.meal_items for select to authenticated using (exists (
  select 1 from public.meals where id = meal_id and user_id = (select auth.uid())
));
create policy own_deletion on public.deletion_jobs for select to authenticated using ((select auth.uid()) = user_id);
create policy own_asset_jobs on public.asset_jobs for select to authenticated using ((select auth.uid()) = user_id);

revoke all on public.profiles, public.target_history, public.meals, public.meal_items, public.deletion_jobs, public.asset_jobs from public, anon, authenticated;
grant select on public.profiles, public.target_history, public.meals, public.meal_items, public.deletion_jobs, public.asset_jobs to authenticated;
grant all on public.profiles, public.target_history, public.meals, public.meal_items, public.deletion_jobs, public.asset_jobs to service_role;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('meal-media','meal-media',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create function public.pw_storage_insert(p_name text)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := auth.uid();
begin
  if u is null or p_name !~ ('^' || u::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp)$') then
    return false;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text, 741));
  return not exists (select 1 from public.deletion_jobs where user_id = u)
    and not exists (select 1 from public.asset_jobs where path = p_name);
end;
$$;
revoke all on function public.pw_storage_insert(text) from public, anon, authenticated;
grant execute on function public.pw_storage_insert(text) to authenticated;
create policy put_own_media on storage.objects for insert to authenticated
  with check (bucket_id = 'meal-media' and public.pw_storage_insert(name));
create policy read_own_media on storage.objects for select to authenticated
  using (bucket_id = 'meal-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

create function public.pw_meal_json(p_id uuid)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select to_jsonb(m) || jsonb_build_object('items', coalesce((
    select jsonb_agg(to_jsonb(i) - array['meal_id','ordinal'] order by ordinal)
    from public.meal_items i where i.meal_id = m.id
  ), '[]'::jsonb))
  from public.meals m where m.id = p_id;
$$;
revoke all on function public.pw_meal_json(uuid) from public, anon;
grant execute on function public.pw_meal_json(uuid) to authenticated, service_role;

create function public.pw_profile_write(p_user uuid, p_data jsonb)
returns jsonb language plpgsql set search_path = '' as $$
declare p public.profiles; d date; old_target integer; had_profile boolean;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 741));
  if exists (select 1 from public.deletion_jobs where user_id = p_user) then raise exception 'DELETION_PENDING'; end if;
  if not exists (select 1 from pg_timezone_names where name = p_data->>'timezone') then raise exception 'INVALID_TIMEZONE'; end if;
  select daily_calorie_target into old_target from public.profiles where user_id = p_user;
  had_profile := found;
  insert into public.profiles(user_id,height_cm,weight_kg,daily_calorie_target,water_goal_ml,timezone,preferred_units,preferred_language)
  values (p_user,(p_data->>'height_cm')::numeric,(p_data->>'weight_kg')::numeric,
    (p_data->>'daily_calorie_target')::integer,(p_data->>'water_goal_ml')::integer,p_data->>'timezone',
    p_data->>'preferred_units',p_data->>'preferred_language')
  on conflict (user_id) do update set height_cm=excluded.height_cm,weight_kg=excluded.weight_kg,
    daily_calorie_target=excluded.daily_calorie_target,water_goal_ml=excluded.water_goal_ml,
    timezone=excluded.timezone,preferred_units=excluded.preferred_units,preferred_language=excluded.preferred_language,
    updated_at=now()
  returning * into p;
  if not had_profile or old_target is distinct from p.daily_calorie_target then
    d := (now() at time zone p.timezone)::date;
    insert into public.target_history values(p_user,d,p.daily_calorie_target)
      on conflict(user_id,effective_on) do update set target_kcal=excluded.target_kcal;
  end if;
  return to_jsonb(p);
end;
$$;

create function public.pw_meal_write(p_user uuid, p_action text, p_data jsonb)
returns jsonb language plpgsql set search_path = '' as $$
declare mid uuid := (p_data->>'id')::uuid; m public.meals; photo text := p_data->>'image_storage_path';
  a_low integer; a_high integer; media_paths jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 741));
  if exists(select 1 from public.deletion_jobs where user_id=p_user) then raise exception 'DELETION_PENDING'; end if;
  if p_action = 'discard_photo' then
    if photo is null or split_part(photo,'/',1) <> p_user::text then raise exception 'NOT_FOUND'; end if;
    if not exists (select 1 from public.meals where image_storage_path=photo) then
      insert into public.asset_jobs(path,user_id) values(photo,p_user) on conflict do nothing;
      return jsonb_build_object('paths',jsonb_build_array(photo));
    end if;
    return '{"paths":[]}'::jsonb;
  end if;
  select * into m from public.meals where id=mid and user_id=p_user;
  if p_action = 'delete_meal' then
    if m.image_storage_path is not null then
      insert into public.asset_jobs(path,user_id,meal_id) values(m.image_storage_path,p_user,mid) on conflict do nothing;
    end if;
    delete from public.meals where id=mid and user_id=p_user;
    select coalesce(jsonb_agg(path),'[]') into media_paths from public.asset_jobs where user_id=p_user and meal_id=mid;
    return jsonb_build_object('paths',media_paths);
  end if;
  if p_action = 'confirm_meal' and m.id is not null then return public.pw_meal_json(mid); end if;
  if p_action = 'edit_meal' then
    if m.id is null then raise exception 'NOT_FOUND'; end if;
    if m.updated_at is distinct from (p_data->>'expected_updated_at')::timestamptz then raise exception 'STALE_MEAL'; end if;
  elsif p_action <> 'confirm_meal' then
    raise exception 'INVALID_ACTION';
  elsif photo is not null and (
    split_part(photo,'/',1) <> p_user::text
    or exists(select 1 from public.asset_jobs where path=photo)
    or not exists(select 1 from storage.objects where bucket_id='meal-media' and name=photo and owner_id=p_user::text)
  ) then raise exception 'NOT_FOUND';
  end if;
  select sum((i->>'calorie_low')::integer),sum((i->>'calorie_high')::integer)
    into a_low,a_high from jsonb_array_elements(p_data->'items') as i;
  if p_action = 'confirm_meal' then
    insert into public.meals(id,user_id,consumed_at,source,image_storage_path,calorie_low,calorie_high,confidence,user_edited,assumptions,model)
    values(mid,p_user,coalesce((p_data->>'consumed_at')::timestamptz,now()),p_data->>'source',photo,a_low,a_high,
      p_data->>'confidence',coalesce((p_data->>'user_edited')::boolean,false),p_data->'assumptions',p_data->>'model');
  else
    update public.meals set calorie_low=a_low,calorie_high=a_high,confidence=p_data->>'confidence',user_edited=true,
      assumptions=p_data->'assumptions',updated_at=clock_timestamp() where id=mid and user_id=p_user;
    delete from public.meal_items where meal_id=mid;
  end if;
  insert into public.meal_items
    select mid, ord::integer, i->>'name',i->>'normalized_food_reference',(i->>'quantity')::numeric,
      i->>'unit',(i->>'estimated_grams')::numeric,(i->>'calorie_low')::integer,(i->>'calorie_high')::integer,
      (i->>'protein_g')::numeric,(i->>'carbohydrate_g')::numeric,(i->>'fat_g')::numeric,(i->>'fiber_g')::numeric,
      (i->>'sodium_mg')::numeric,i->>'nutrient_source',i->>'provenance'
    from jsonb_array_elements(p_data->'items') with ordinality as t(i,ord);
  return public.pw_meal_json(mid);
end;
$$;

create function public.pw_overview()
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare uid uuid := auth.uid(); p public.profiles; local_day date; since_time timestamptz; until_time timestamptz;
begin
  select * into p from public.profiles where user_id=uid;
  if not found then return '{"profile":null,"meals":[],"targets":[],"water":[]}'::jsonb; end if;
  local_day := (now() at time zone p.timezone)::date;
  since_time := (local_day - 6)::timestamp at time zone p.timezone;
  until_time := (local_day + 1)::timestamp at time zone p.timezone;
  return jsonb_build_object('profile',to_jsonb(p),'local_day',local_day,
    'meals',coalesce((select jsonb_agg(public.pw_meal_json(m.id) order by consumed_at)
      from public.meals m where user_id=uid and consumed_at >= since_time and consumed_at < until_time),'[]'::jsonb),
    'targets',coalesce((select jsonb_agg(jsonb_build_object('effective_on',effective_on,'target_kcal',target_kcal) order by effective_on)
      from public.target_history where user_id=uid and effective_on <= local_day),'[]'::jsonb),
    'water','[]'::jsonb,
    'pending_asset_count',(select count(*) from public.asset_jobs where user_id=uid));
end;
$$;

revoke all on function public.pw_profile_write(uuid,jsonb),public.pw_meal_write(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.pw_profile_write(uuid,jsonb),public.pw_meal_write(uuid,text,jsonb) to service_role;
revoke all on function public.pw_overview() from public,anon;
grant execute on function public.pw_overview() to authenticated;

create table public.ai_usage (
  user_id uuid references auth.users(id) on delete cascade,
  utc_day date,
  units integer not null check (units >= 0),
  primary key (user_id,utc_day)
);
create table public.ai_cache (
  user_id uuid references auth.users(id) on delete cascade,
  cache_key text,
  expires_at timestamptz not null,
  data jsonb not null,
  primary key (user_id,cache_key)
);
alter table public.ai_usage enable row level security;
alter table public.ai_cache enable row level security;
revoke all on public.ai_usage,public.ai_cache from public,anon,authenticated;
grant all on public.ai_usage,public.ai_cache to service_role;

create function public.pw_claim_ai(p_user uuid,p_units integer,p_limit integer)
returns boolean language plpgsql set search_path = '' as $$
declare booked integer; day date := (now() at time zone 'UTC')::date;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text,741));
  if exists(select 1 from public.deletion_jobs where user_id=p_user) then raise exception 'DELETION_PENDING'; end if;
  if p_units < 1 or p_units > p_limit then return false; end if;
  insert into public.ai_usage values(p_user,day,p_units)
    on conflict(user_id,utc_day) do update set units=public.ai_usage.units+excluded.units
    where public.ai_usage.units+excluded.units<=p_limit
    returning units into booked;
  return booked is not null;
end;
$$;
revoke all on function public.pw_claim_ai(uuid,integer,integer) from public,anon,authenticated;
grant execute on function public.pw_claim_ai(uuid,integer,integer) to service_role;

create function public.pw_store_ai(p_user uuid,p_key text,p_data jsonb)
returns void language plpgsql set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text,741));
  if exists(select 1 from public.deletion_jobs where user_id=p_user) then return; end if;
  insert into public.ai_cache values(p_user,p_key,now()+interval '1 hour',p_data)
    on conflict(user_id,cache_key) do update set expires_at=excluded.expires_at,data=excluded.data;
end;
$$;
revoke all on function public.pw_store_ai(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.pw_store_ai(uuid,text,jsonb) to service_role;
