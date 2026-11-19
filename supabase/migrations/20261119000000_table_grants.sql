-- Newer Supabase projects no longer grant table access to the API roles by
-- default, so grant it explicitly. Row Level Security still decides which rows
-- each role sees, and the browser roles stay read-only.

grant usage on schema public to anon, authenticated, service_role;

-- Public read (the website and TV): the policies allow select on these only.
grant select on public.players, public.tournaments, public.entrants,
  public.tournament_events, public.matches, public.seasons
  to anon, authenticated;

-- Server (Netlify Functions with the secret key): full access.
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

-- Same for anything created later.
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;
