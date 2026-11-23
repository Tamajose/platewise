create table public.restaurants (
  id text primary key,
  name text not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  dataset text not null check (dataset = 'seeded'),
  source text not null,
  attribution text not null,
  last_verified_at timestamptz
);
create table public.menu_items (
  id text primary key,
  restaurant_id text not null references public.restaurants(id) on delete cascade,
  name text not null,
  portion text not null,
  calorie_low int not null check (calorie_low between 0 and 6000),
  calorie_high int not null check (calorie_high between calorie_low and 6000),
  protein_g numeric check (protein_g >= 0),
  carbohydrate_g numeric check (carbohydrate_g >= 0),
  fat_g numeric check (fat_g >= 0),
  fiber_g numeric check (fiber_g >= 0),
  sodium_mg numeric check (sodium_mg >= 0)
);
create index menu_items_restaurant_id on public.menu_items(restaurant_id);
alter table public.restaurants enable row level security;
alter table public.menu_items enable row level security;
create policy read_seeded_restaurants on public.restaurants for select to authenticated using (dataset='seeded');
create policy read_seeded_menus on public.menu_items for select to authenticated using (true);
revoke all on public.restaurants, public.menu_items from public,anon,authenticated;
grant select on public.restaurants, public.menu_items to authenticated;
grant all on public.restaurants, public.menu_items to service_role;
