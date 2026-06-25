create table if not exists subscriptions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null unique references auth.users(id) on delete cascade,
  estado          text not null default 'trial',  -- trial|activa|cancelada|vencida
  trial_ends_at   timestamptz,
  periodo_fin     timestamptz,
  created_at      timestamptz default now()
);
create unique index if not exists idx_subscriptions_user_id on subscriptions (user_id);

alter table subscriptions enable row level security;
create policy "ver_propia_suscripcion" on subscriptions for select using (auth.uid() = user_id);
create policy "insertar_propia_suscripcion" on subscriptions for insert with check (auth.uid() = user_id);
create policy "actualizar_propia_suscripcion" on subscriptions for update using (auth.uid() = user_id);
