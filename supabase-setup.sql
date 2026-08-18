-- =====================================================
-- gamelose — схема базы данных Supabase
-- Выполнить это всё в Supabase: SQL Editor -> New query -> Run
-- Скрипт можно запускать повторно — он всё пересоздаёт.
-- =====================================================

-- 0. Полная пересборка (на случай повторного запуска)
drop table if exists public.replies cascade;
drop table if exists public.topics cascade;
drop table if exists public.profiles cascade;
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

-- 1. Профили пользователей (username привязан к auth)
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  created_at timestamptz default now()
);

-- 2. Темы форума
create table public.topics (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text default '',
  author_id uuid references auth.users on delete cascade,
  author_name text not null,
  created_at timestamptz default now()
);

-- 3. Ответы в темах
create table public.replies (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid references public.topics on delete cascade not null,
  body text not null,
  author_id uuid references auth.users on delete cascade,
  author_name text not null,
  created_at timestamptz default now()
);

-- 4. Создание профиля автоматически при регистрации
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8))
  );
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- 5. Безопасность: Row Level Security (RLS)
-- читать могут все, писать — только авторизованные и только от своего имени
alter table public.profiles enable row level security;
alter table public.topics enable row level security;
alter table public.replies enable row level security;

create policy "profiles are readable" on public.profiles
  for select using (true);

create policy "topics are readable" on public.topics
  for select using (true);

create policy "topics can be created" on public.topics
  for insert with check (auth.uid() = author_id);

create policy "replies are readable" on public.replies
  for select using (true);

create policy "replies can be created" on public.replies
  for insert with check (auth.uid() = author_id);
