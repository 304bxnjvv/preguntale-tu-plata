-- Migración 006: tablas presupuestos y metas

create table if not exists presupuestos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  categoria   text not null,
  monto_tope  numeric not null default 0,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now(),
  unique (user_id, categoria)
);
create index if not exists idx_presupuestos_user on presupuestos (user_id);
alter table presupuestos enable row level security;
create policy "presupuesto_select" on presupuestos for select using (auth.uid() = user_id);
create policy "presupuesto_insert" on presupuestos for insert with check (auth.uid() = user_id);
create policy "presupuesto_update" on presupuestos for update using (auth.uid() = user_id);
create policy "presupuesto_delete" on presupuestos for delete using (auth.uid() = user_id);

create table if not exists metas (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  nombre           text not null,
  monto_objetivo   numeric not null default 0,
  monto_actual     numeric not null default 0,
  fecha_objetivo   date,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);
create index if not exists idx_metas_user on metas (user_id);
alter table metas enable row level security;
create policy "meta_select" on metas for select using (auth.uid() = user_id);
create policy "meta_insert" on metas for insert with check (auth.uid() = user_id);
create policy "meta_update" on metas for update using (auth.uid() = user_id);
create policy "meta_delete" on metas for delete using (auth.uid() = user_id);
