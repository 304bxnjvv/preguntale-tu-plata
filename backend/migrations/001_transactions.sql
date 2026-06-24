-- Aplicar en Supabase: SQL Editor → pegar y ejecutar.
create table if not exists transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  fecha       date not null,
  descripcion text not null,
  monto       numeric not null,
  moneda      text not null default 'CLP',
  tarjeta     text,
  tipo        text not null,
  categoria   text,
  banco       text not null,
  fuente      text not null,
  created_at  timestamptz default now()
);

create index if not exists idx_transactions_user_fecha
  on transactions (user_id, fecha);

-- RLS: protege el acceso directo de clientes Supabase.
-- (El backend FastAPI se conecta con el rol postgres y filtra por user_id él mismo.)
alter table transactions enable row level security;

create policy "ver_propias" on transactions
  for select using (auth.uid() = user_id);

create policy "insertar_propias" on transactions
  for insert with check (auth.uid() = user_id);
