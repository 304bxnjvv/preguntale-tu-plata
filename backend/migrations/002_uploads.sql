create table if not exists uploads (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  filename        text not null,
  n_transacciones integer not null default 0,
  fuente          text not null default 'cartola',
  created_at      timestamptz default now()
);
create index if not exists idx_uploads_user_created on uploads (user_id, created_at);

alter table uploads enable row level security;
create policy "ver_propias_uploads" on uploads for select using (auth.uid() = user_id);
create policy "insertar_propias_uploads" on uploads for insert with check (auth.uid() = user_id);
