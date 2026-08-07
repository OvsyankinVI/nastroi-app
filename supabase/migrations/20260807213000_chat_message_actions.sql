-- Additive support for replies, editing and soft deletion.
alter table public.chat_messages
  add column if not exists edited_at timestamptz,
  add column if not exists reply_to_message_id uuid
    references public.chat_messages(id) on delete set null,
  add column if not exists deleted_at timestamptz;

create index if not exists chat_messages_reply_idx
  on public.chat_messages(reply_to_message_id)
  where reply_to_message_id is not null;

-- The app resolves the remote account once while loading friends and passes
-- the Auth UUID explicitly. Public/local Person IDs never enter chat_threads.
create or replace function public.get_or_create_direct_thread(
  p_friend_user_id uuid
)
returns table(
  thread_id uuid,
  other_user_id uuid,
  other_public_id text,
  other_name text,
  other_gender text,
  other_avatar_variant int,
  other_mood text,
  updated_at timestamptz,
  last_message_text text,
  unread_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_thread uuid;
begin
  if v_me is null or p_friend_user_id is null or v_me = p_friend_user_id then
    raise exception 'Chat is unavailable';
  end if;

  if not exists (
    select 1
    from public.friend_links link
    where link.status = 'accepted'
      and (
        (link.owner_user_id = v_me and link.friend_user_id = p_friend_user_id)
        or
        (link.owner_user_id = p_friend_user_id and link.friend_user_id = v_me)
      )
  ) then
    raise exception 'Users are not friends';
  end if;

  insert into public.chat_threads(user_a, user_b)
  values (
    least(v_me, p_friend_user_id),
    greatest(v_me, p_friend_user_id)
  )
  on conflict (user_a, user_b) do update
    set updated_at = public.chat_threads.updated_at
  returning id into v_thread;

  return query
  select
    thread.id,
    p_friend_user_id,
    profile.public_id,
    profile.name,
    profile.gender,
    profile.avatar_variant,
    profile.mood,
    coalesce(thread.last_message_at, thread.updated_at),
    thread.last_message_text,
    (
      select count(*)
      from public.chat_messages message
      where message.thread_id = thread.id
        and message.sender_id <> v_me
        and message.read_at is null
    )
  from public.chat_threads thread
  join public.people profile
    on profile.owner_user_id = p_friend_user_id
   and profile.relation_type = 'me'
  where thread.id = v_thread
  limit 1;
end;
$$;

grant execute on function public.get_or_create_direct_thread(uuid)
to authenticated;

-- Read receipts use the security-definer mark_chat_thread_read RPC. There is
-- deliberately no direct recipient UPDATE policy.
create policy "senders update own messages"
on public.chat_messages for update
using (
  sender_id = auth.uid()
  and public.is_chat_participant(thread_id, auth.uid())
)
with check (
  sender_id = auth.uid()
  and public.is_chat_participant(thread_id, auth.uid())
);

create or replace function public.validate_chat_message_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.reply_to_message_id is not null and not exists (
      select 1 from public.chat_messages quoted
      where quoted.id = new.reply_to_message_id
        and quoted.thread_id = new.thread_id
    ) then
      raise exception 'Reply target must belong to the same thread';
    end if;
    return new;
  end if;

  if new.id <> old.id
    or new.thread_id <> old.thread_id
    or new.sender_id <> old.sender_id
    or new.created_at <> old.created_at
    or new.reply_to_message_id is distinct from old.reply_to_message_id
  then
    raise exception 'Immutable message fields cannot be changed';
  end if;

  if old.deleted_at is not null and (
    new.text is distinct from old.text
    or new.deleted_at is distinct from old.deleted_at
  ) then
    raise exception 'Deleted message cannot be changed';
  end if;

  if new.deleted_at is not null then
    new.edited_at := old.edited_at;
  elsif new.text is distinct from old.text and new.edited_at is null then
    new.edited_at := now();
  end if;
  return new;
end;
$$;

do $$ begin
  if not exists(select 1 from pg_trigger where tgname = 'validate_chat_message_change') then
    create trigger validate_chat_message_change
    before insert or update on public.chat_messages
    for each row execute function public.validate_chat_message_change();
  end if;
end $$;

create or replace function public.sync_chat_thread_last_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.chat_threads thread
    where thread.id = new.thread_id
      and thread.last_message_at = new.created_at
  ) then
    update public.chat_threads
    set last_message_text = case
      when new.deleted_at is not null then 'Сообщение удалено'
      else left(new.text, 160)
    end,
    updated_at = now()
    where id = new.thread_id;
  end if;
  return new;
end;
$$;

do $$ begin
  if not exists(select 1 from pg_trigger where tgname = 'chat_message_updated') then
    create trigger chat_message_updated
    after update of text, deleted_at on public.chat_messages
    for each row execute function public.sync_chat_thread_last_message();
  end if;
end $$;

grant execute on function public.validate_chat_message_change() to authenticated;
grant execute on function public.sync_chat_thread_last_message() to authenticated;
