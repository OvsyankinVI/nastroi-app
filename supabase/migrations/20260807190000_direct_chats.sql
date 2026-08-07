-- Additive MVP for secure one-to-one chats.
create extension if not exists pgcrypto;

create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz,
  last_message_text text,
  constraint chat_threads_different_users check (user_a <> user_b),
  constraint chat_threads_ordered_users check (user_a < user_b),
  constraint chat_threads_unique_pair unique (user_a, user_b)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  text text not null check (length(btrim(text)) between 1 and 4000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists chat_messages_thread_created_idx on public.chat_messages(thread_id, created_at desc);

create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('ios', 'android')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists user_push_tokens_user_idx on public.user_push_tokens(user_id);

alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.user_push_tokens enable row level security;

create or replace function public.is_chat_participant(p_thread_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.chat_threads where id = p_thread_id and p_user_id in (user_a, user_b)); $$;

create or replace function public.is_active_friend_thread(p_thread_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from public.chat_threads t join public.friend_links f
      on f.status='accepted' and ((f.owner_user_id=t.user_a and f.friend_user_id=t.user_b) or (f.owner_user_id=t.user_b and f.friend_user_id=t.user_a))
    where t.id=p_thread_id and auth.uid() in (t.user_a,t.user_b)
  );
$$;

create policy "participants read threads" on public.chat_threads for select using (auth.uid() in (user_a, user_b));
create policy "participants read messages" on public.chat_messages for select using (public.is_chat_participant(thread_id, auth.uid()));
create policy "participants send messages" on public.chat_messages for insert with check (sender_id = auth.uid() and public.is_chat_participant(thread_id, auth.uid()) and public.is_active_friend_thread(thread_id));
create policy "users read own push tokens" on public.user_push_tokens for select using (user_id = auth.uid());
create policy "users insert own push tokens" on public.user_push_tokens for insert with check (user_id = auth.uid());
create policy "users update own push tokens" on public.user_push_tokens for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "users delete own push tokens" on public.user_push_tokens for delete using (user_id = auth.uid());

create or replace function public.get_or_create_direct_thread(p_friend_public_id text)
returns table(thread_id uuid, other_user_id uuid, other_public_id text, other_name text, other_gender text, other_avatar_variant int, other_mood text, updated_at timestamptz, last_message_text text, unread_count bigint)
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_friend uuid; v_thread uuid;
begin
  select owner_user_id into v_friend from public.people where public_id = p_friend_public_id and relation_type = 'me' limit 1;
  if v_me is null or v_friend is null or v_me = v_friend then raise exception 'Chat is unavailable'; end if;
  if not exists(select 1 from public.friend_links where status = 'accepted' and ((owner_user_id = v_me and friend_user_id = v_friend) or (owner_user_id = v_friend and friend_user_id = v_me))) then raise exception 'Users are not friends'; end if;
  insert into public.chat_threads(user_a, user_b) values (least(v_me, v_friend), greatest(v_me, v_friend)) on conflict (user_a, user_b) do update set updated_at = public.chat_threads.updated_at returning id into v_thread;
  return query select t.id, v_friend, p.public_id, p.name, p.gender, p.avatar_variant, p.mood, t.updated_at, t.last_message_text,
    (select count(*) from public.chat_messages m where m.thread_id=t.id and m.sender_id<>v_me and m.read_at is null)
  from public.chat_threads t join public.people p on p.owner_user_id=v_friend and p.relation_type='me' where t.id=v_thread limit 1;
end $$;

create or replace function public.list_chat_threads()
returns table(thread_id uuid, other_user_id uuid, other_public_id text, other_name text, other_gender text, other_avatar_variant int, other_mood text, updated_at timestamptz, last_message_text text, unread_count bigint)
language sql stable security definer set search_path = public as $$
  select t.id, case when t.user_a=auth.uid() then t.user_b else t.user_a end, p.public_id, p.name, p.gender, p.avatar_variant, p.mood,
    coalesce(t.last_message_at,t.updated_at), t.last_message_text,
    (select count(*) from public.chat_messages m where m.thread_id=t.id and m.sender_id<>auth.uid() and m.read_at is null)
  from public.chat_threads t join public.people p on p.owner_user_id=(case when t.user_a=auth.uid() then t.user_b else t.user_a end) and p.relation_type='me'
  where auth.uid() in (t.user_a,t.user_b) order by coalesce(t.last_message_at,t.updated_at) desc;
$$;

create or replace function public.mark_chat_thread_read(p_thread_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_chat_participant(p_thread_id, auth.uid()) then raise exception 'Access denied'; end if;
  update public.chat_messages set read_at=now() where thread_id=p_thread_id and sender_id<>auth.uid() and read_at is null;
end $$;

create or replace function public.on_chat_message_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_chat_participant(new.thread_id,new.sender_id) then raise exception 'Sender is not a participant'; end if;
  update public.chat_threads set updated_at=now(), last_message_at=new.created_at, last_message_text=left(new.text,160) where id=new.thread_id;
  return new;
end $$;
do $$ begin
  if not exists(select 1 from pg_trigger where tgname = 'chat_message_inserted') then
    create trigger chat_message_inserted before insert on public.chat_messages for each row execute function public.on_chat_message_insert();
  end if;
end $$;

grant execute on function public.get_or_create_direct_thread(text) to authenticated;
grant execute on function public.list_chat_threads() to authenticated;
grant execute on function public.mark_chat_thread_read(uuid) to authenticated;
grant execute on function public.is_chat_participant(uuid,uuid) to authenticated;
grant execute on function public.is_active_friend_thread(uuid) to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.chat_messages;
exception when duplicate_object then null; end $$;
