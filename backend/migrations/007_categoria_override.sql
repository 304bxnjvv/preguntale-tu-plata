create table if not exists categoria_overrides (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  comercio_key text not null,
  categoria    text not null,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now(),
  unique (user_id, comercio_key)
);
create index if not exists idx_cat_override_user on categoria_overrides (user_id);
alter table categoria_overrides enable row level security;
create policy "override_select" on categoria_overrides for select using (auth.uid() = user_id);
create policy "override_insert" on categoria_overrides for insert with check (auth.uid() = user_id);
create policy "override_update" on categoria_overrides for update using (auth.uid() = user_id);
create policy "override_delete" on categoria_overrides for delete using (auth.uid() = user_id);

alter table transactions add column if not exists categoria_manual boolean not null default false;
