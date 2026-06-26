create table if not exists categorias_usuario (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  nombre     text not null,
  created_at timestamptz default now(),
  unique (user_id, nombre)
);
create index if not exists idx_categorias_usuario_user on categorias_usuario (user_id);
alter table categorias_usuario enable row level security;
create policy "cat_usuario_select" on categorias_usuario for select using (auth.uid() = user_id);
create policy "cat_usuario_insert" on categorias_usuario for insert with check (auth.uid() = user_id);
create policy "cat_usuario_update" on categorias_usuario for update using (auth.uid() = user_id);
create policy "cat_usuario_delete" on categorias_usuario for delete using (auth.uid() = user_id);
