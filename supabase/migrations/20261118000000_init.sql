-- Charlie's Big Stick Energy: complete database setup (one file for a fresh project).
--
-- Security model
--   * The public (anon key in the browser) can only READ the non-sensitive
--     tables below. Row Level Security has no insert/update/delete policies, so
--     every write is rejected unless it comes from a Netlify Function using the
--     secret (service_role) key, which checks the host PIN first.
--   * Host login attempts live in a table with RLS enabled and NO policies:
--     invisible to the public. No phone numbers or other contact info are stored.


-- ---------------------------------------------------------------- players
create table public.players (
  id uuid primary key default gen_random_uuid(),
  display_name text not null check (char_length(display_name) between 1 and 40),
  -- lowercase letters/digits only; prevents "Big Mike" vs "big  mike" duplicates
  name_key text not null unique check (name_key <> ''),
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------ tournaments
create table public.tournaments (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  name text not null,
  status text not null default 'draft' check (status in ('draft', 'live', 'complete')),
  settings jsonb not null default '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  champion_id uuid references public.players(id) on delete set null,
  created_at timestamptz not null default now(),
  -- bumped on every change so live screens refresh (realtime can't filter deletes)
  updated_at timestamptz not null default now()
);
create index tournaments_date_idx on public.tournaments (date desc);
create index tournaments_status_idx on public.tournaments (status);

create table public.entrants (
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  seed int not null check (seed >= 1),
  final_place int check (final_place >= 1),
  created_at timestamptz not null default now(),
  primary key (tournament_id, player_id)
);
create index entrants_player_idx on public.entrants (player_id);

-- The ordered result log. The bracket is always recomputed from these events.
create table public.tournament_events (
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  seq int not null check (seq >= 0),
  event jsonb not null,
  created_at timestamptz not null default now(),
  primary key (tournament_id, seq)
);

-- Every finished match with its winner AND loser (byes are never stored).
create table public.matches (
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  match_id text not null,
  bracket text not null check (bracket in ('W', 'L', 'GF')),
  round int not null,
  winner_id uuid not null references public.players(id) on delete restrict,
  loser_id uuid not null references public.players(id) on delete restrict,
  kind text not null check (kind in ('normal', 'walkover')),
  seq int not null,
  primary key (tournament_id, match_id)
);
create index matches_winner_idx on public.matches (winner_id);
create index matches_loser_idx on public.matches (loser_id);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  start_date date not null,
  end_date date not null,
  check (end_date >= start_date)
);

create table public.host_login_attempts (
  id bigint generated always as identity primary key,
  ip text not null,
  ok boolean not null,
  created_at timestamptz not null default now()
);
create index host_login_attempts_ip_idx on public.host_login_attempts (ip, created_at desc);

-- ------------------------------------------------------- row level security
alter table public.players enable row level security;
alter table public.tournaments enable row level security;
alter table public.entrants enable row level security;
alter table public.tournament_events enable row level security;
alter table public.matches enable row level security;
alter table public.seasons enable row level security;
alter table public.host_login_attempts enable row level security;

-- Public read-only access to non-sensitive tables.
create policy "public read players" on public.players for select to anon, authenticated using (true);
create policy "public read tournaments" on public.tournaments for select to anon, authenticated using (true);
create policy "public read entrants" on public.entrants for select to anon, authenticated using (true);
create policy "public read events" on public.tournament_events for select to anon, authenticated using (true);
create policy "public read matches" on public.matches for select to anon, authenticated using (true);
create policy "public read seasons" on public.seasons for select to anon, authenticated using (true);
-- host_login_attempts: no policies = no public access.

-- Belt and braces: the browser roles can never write, even if a policy is added by mistake.
revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
revoke all on public.host_login_attempts from anon, authenticated;

-- --------------------------------------------------------- atomic event writes
-- Replaces events from position p_from onward, but only if the tournament has
-- exactly p_expected events right now. This stops two devices from recording
-- conflicting results at the same moment. Used for record / undo / correct.
create or replace function public.write_events(
  p_tournament uuid,
  p_expected int,
  p_from int,
  p_events jsonb
) returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  current_count int;
begin
  perform 1 from public.tournaments where id = p_tournament for update;
  if not found then
    raise exception 'Tournament not found' using errcode = 'P0002';
  end if;

  select count(*) into current_count from public.tournament_events where tournament_id = p_tournament;
  if current_count <> p_expected then
    raise exception 'STALE: expected % events, found %', p_expected, current_count using errcode = 'P0001';
  end if;
  if p_from < 0 or p_from > current_count then
    raise exception 'Invalid event position %', p_from;
  end if;

  delete from public.tournament_events where tournament_id = p_tournament and seq >= p_from;
  insert into public.tournament_events (tournament_id, seq, event)
  select p_tournament, p_from + (t.ord - 1)::int, t.value
  from jsonb_array_elements(coalesce(p_events, '[]'::jsonb)) with ordinality as t(value, ord);

  return p_from + jsonb_array_length(coalesce(p_events, '[]'::jsonb));
end;
$$;

revoke execute on function public.write_events(uuid, int, int, jsonb) from public, anon, authenticated;
grant execute on function public.write_events(uuid, int, int, jsonb) to service_role;

-- Replaces all stored matches for a tournament in one transaction.
create or replace function public.replace_matches(p_tournament uuid, p_rows jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.matches where tournament_id = p_tournament;
  insert into public.matches (tournament_id, match_id, bracket, round, winner_id, loser_id, kind, seq)
  select p_tournament, r.match_id, r.bracket, r.round, r.winner_id, r.loser_id, r.kind, r.seq
  from jsonb_to_recordset(coalesce(p_rows, '[]'::jsonb))
    as r(match_id text, bracket text, round int, winner_id uuid, loser_id uuid, kind text, seq int);
end;
$$;

revoke execute on function public.replace_matches(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.replace_matches(uuid, jsonb) to service_role;

-- ------------------------------------------------------------------ realtime
-- Live updates for the iPad, TV and phones. Clients refetch when these change.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.tournaments, public.entrants, public.tournament_events;
  end if;
end;
$$;

-- ------------------------------------------------------------- check-in
-- Self check-in from phones (the TV's QR code) is a public write, so the
-- check-in function limits how often one network address can use it.
create table public.checkin_attempts (
  id bigint generated always as identity primary key,
  ip text not null,
  created_at timestamptz not null default now()
);
create index checkin_attempts_ip_idx on public.checkin_attempts (ip, created_at desc);

alter table public.checkin_attempts enable row level security;
-- No policies: invisible to the public; only the server (secret key) uses it.
revoke all on public.checkin_attempts from anon, authenticated;

-- --------------------------------------------------------------- pictures
-- Player pictures: a pixel character ("px:<n>") or an uploaded photo URL.
-- NULL means the player's default character.
alter table public.players
  add column if not exists avatar text
  check (avatar is null or (char_length(avatar) <= 500 and (avatar ~ '^px:[0-9]{1,3}$' or avatar ~ '^https://')));

-- Public bucket for uploaded photos (small JPEGs, resized on the phone).
-- Anyone can view; only the server (secret key) can upload or delete.
do $$
begin
  if exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('avatars', 'avatars', true, 262144, array['image/jpeg', 'image/png', 'image/webp'])
    on conflict (id) do nothing;
  end if;
end;
$$;
