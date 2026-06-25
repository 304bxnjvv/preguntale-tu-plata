create table if not exists tarjeta_estado (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null unique references auth.users(id) on delete cascade,
  total_a_pagar           numeric not null default 0,
  monto_minimo            numeric not null default 0,
  fecha_vencimiento       date,
  cupo_total              numeric not null default 0,
  cupo_utilizado          numeric not null default 0,
  cuotas                  text not null default '[]',
  comprometido_proximo_mes numeric not null default 0,
  created_at              timestamptz default now()
);
create unique index if not exists idx_tarjeta_estado_user_id on tarjeta_estado (user_id);

alter table tarjeta_estado enable row level security;
create policy "ver_propio_estado_tarjeta" on tarjeta_estado for select using (auth.uid() = user_id);
create policy "insertar_propio_estado_tarjeta" on tarjeta_estado for insert with check (auth.uid() = user_id);
create policy "actualizar_propio_estado_tarjeta" on tarjeta_estado for update using (auth.uid() = user_id);
create policy "eliminar_propio_estado_tarjeta" on tarjeta_estado for delete using (auth.uid() = user_id);
