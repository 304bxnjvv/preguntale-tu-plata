create table if not exists chat_messages (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  role            text not null,
  content         text not null,
  created_at      timestamptz default now()
);
create index if not exists idx_chat_messages_user_created on chat_messages (user_id, created_at);

alter table chat_messages enable row level security;
create policy "ver_propios_mensajes" on chat_messages for select using (auth.uid() = user_id);
create policy "insertar_propios_mensajes" on chat_messages for insert with check (auth.uid() = user_id);
