# 🎱 Charlie's · Big Stick Energy

The app for **Big Stick Energy**, the pool tournament at **Charlie's Denver** (900 E. Colfax Ave, Denver, CO 80218 · 21+).
Last Wednesday of every month · Registration 6:30pm · Tournament 7:00pm · $5 buy-in, 1 vs 1 · 1st & 2nd place win cash & gift cards · Hosted by MJ.

- **Players check themselves in** by scanning a QR code on the TV. Returning players tap their name; new players add theirs.
- **Host dashboard** on the bar's iPad: watch check-ins arrive, start the bracket, tap winners, choose which match plays next.
- **TV mode**: a live check-in board before the start, then the full bracket with **On Table** / **Up Next** and a QR code players scan to see their stats.
- **Player pages** on phones: next opponent, matches until they're up, tonight's and all-time stats, and their picture (pixel character, pool ball, or photo).
- **Double elimination** with byes, grand-final bracket reset, undo, corrections, withdrawals, late entries and "undo start".
- **Stats over time**: leaderboard (all-time and by season), titles, win %, streaks, month-by-month history.

It runs entirely in the cloud (Netlify + Supabase); nothing needs to stay running on anyone's computer. This app has its own database: no players or results are shared with any other bar.

---

## Contents

1. [How a tournament night works](#how-a-tournament-night-works)
2. [Setup guide](#setup-guide)
3. [Bracket rules](#bracket-rules)
4. [Privacy and security](#privacy-and-security)
5. [Troubleshooting](#troubleshooting)
6. [For developers](#for-developers)

---

## How a tournament night works

1. On the iPad (home-screen icon): **Host** → enter the PIN → **＋ New Tournament** (the date defaults to today).
2. **Check-in (from 6:30pm).** Tap **📺 TV Mode**. The TV shows **SCAN HERE TO CHECK-IN** with a QR code and a live list of everyone checked in. Players scan it with their phone camera: returning players search and tap their name; new players tap **New Player? +**. If a name looks like an existing player, the app asks "Is one of these you?" first. Names appear on the TV and the iPad within seconds. The host can still add or remove anyone from the iPad.
3. Check the settings (pool tables, random draw, bracket reset). Want to set the matchups yourself? Turn **Random draw** off and use the **Round 1 matchups** box: tap two names to swap them.
4. **7:00pm:** tap **🎱 Start Tournament**. The bracket is drawn, check-in closes, and the TV switches to the bracket by itself.
5. On **Matches**, tap the winner under **On Table**. Everything updates live. Tap a match under **Up Next** to **Play this next** or **Put on the table now**. By default the match that has waited longest plays next, so a winner rests while waiting matches are played.
6. Mistakes: tap **Undo** in the pop-up (or ↶ Undo). Fix an older result from the **Bracket** tab. Started too soon? **⚙︎ Settings → Undo start** goes back to registration with everyone still signed up.
7. When the final is decided, the champion screen appears and the results save to history.

**Players tab:** everyone's status, late entries, and **Withdraw** for anyone who left.
**Pictures:** players tap **Choose your picture** after checking in (or **Change picture** on their page). Photos are cropped and shrunk on the phone (about 10–20 KB). Characters and pool balls are drawn by the app. Pictures stay with the player every month; the host can remove one under **Host → Players → Reset picture**.

---

## Setup guide

You need three accounts: **GitHub** (holds this code), **Supabase** (the database) and **Netlify** (the website). Until Supabase is connected the site runs in **demo mode** (a blue banner; data saved in that one browser only; demo PIN `1234`).

### 1. Database (Supabase): a new project, not the Buddies one

1. **https://supabase.com** → **New project**. Name it `charlies-big-stick-energy`, generate a database password (save it), region **West US**. Wait for it to finish.
2. **Create the tables, one way (not both):**
   - **Automatic:** **Project Settings → Integrations → GitHub** → connect the `charliespoolapp` repository. Working directory `.`, turn on **Deploy to production**, production branch `main`. Supabase then applies [`supabase/migrations`](supabase/migrations) whenever `main` changes. (Already-pushed files may need one new push to `main` before the first run happens; ask the developer.)
   - **Manual:** **SQL Editor → New query**, paste all of [`supabase/migrations/20261118000000_init.sql`](supabase/migrations/20261118000000_init.sql), **Run**.
3. Check **Table Editor**: you should see `players`, `tournaments`, `entrants`, `tournament_events`, `matches`, `seasons`, `host_login_attempts`, `checkin_attempts`.
4. Copy three values from **Project Settings → API Keys** (and **Data API** for the URL):
   - **Project URL**: exactly `https://xxxxxxxx.supabase.co` (no path after it). The ID is also in your dashboard address: `supabase.com/dashboard/project/xxxxxxxx`.
   - **Publishable key** (`sb_publishable_…`): safe to be public.
   - **Secret key** (`sb_secret_…`): keep private.

### 2. Website (Netlify)

1. **https://app.netlify.com** → **Add new project → Import an existing project → GitHub** → pick **charliespoolapp**.
2. Build settings fill themselves in from `netlify.toml`. **Leave Base directory blank.** Branch `main`, build command `npm run build`, publish directory `dist`, functions directory `netlify/functions`.
3. **Environment variables** (one key each, exact spelling, no quotes or spaces, **All scopes**, **same value for all deploy contexts**):

   | Key | Value |
   |---|---|
   | `VITE_SUPABASE_URL` | the Project URL, `https://xxxxxxxx.supabase.co` |
   | `SUPABASE_URL` | the same Project URL again (the full address, not just the ID) |
   | `VITE_SUPABASE_ANON_KEY` | the publishable key |
   | `SUPABASE_SERVICE_ROLE_KEY` | the secret key |
   | `HOST_PIN` | a 6-digit PIN you choose, **digits only** (the PIN pad only types numbers). Leave "Contains secret values" **unticked** so you can read it back. |

4. **Deploy.** Then rename the site (e.g. `charlies-big-stick-energy` → `https://charlies-big-stick-energy.netlify.app`).
5. **After changing any variable: Deploys → Trigger deploy → Deploy site.** Settings only take effect after a new deploy.
6. Open **`https://YOUR-SITE.netlify.app/.netlify/functions/health`**. Every line should be ✅; any ❌ says exactly what to fix.

### 3. iPad and TV

- **iPad:** Safari → `https://YOUR-SITE.netlify.app/host` → Share → **Add to Home Screen**. Open it from the icon and enter the PIN (it stays signed in for 12 hours). Settings → Display → Auto-Lock → Never during the tournament.
- **TV, option A (AirPlay):** Control Center → **Screen Mirroring** → the TV, then tap **📺 TV Mode**.
- **TV, option B (smart TV browser or a laptop on the TV):** open **`https://YOUR-SITE.netlify.app/tv`** and bookmark it. It always shows the current tournament and switches by itself every month.

### Optional: demo data

On a computer with Node 22: clone the repo, `npm install`, copy `.env.example` to `.env`, fill in `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`, then `npm run seed` (20 fictional players and a few past tournaments). Delete those tournaments before going live.

---

## Bracket rules

- **Double elimination.** First loss → losers bracket; second loss → out. Everyone plays at least two matches.
- **4 to 64 players.** The bracket fills 4/8/16/32/64 spots; extra spots are **byes** (a bye is never a win, loss or match played). Byes go to the top seeds.
- **Losers-bracket crossover** keeps players who drop down from immediately replaying someone from their own section where possible.
- **Grand final:** winners-bracket champion vs losers-bracket champion; if the losers-bracket champ wins, a **reset** match decides it (setting, on by default).
- **Play order:** the match that has waited longest goes on the next free table; the host can override with **Play this next** / **Put on the table now**.
- **Corrections** recalculate everything after them; results that no longer make sense are listed and erased after you confirm.
- **Withdrawals** turn the player's remaining matches into forfeits (not counted in anyone's stats).
- **Late entry** fills an open bye spot only if that spot's player hasn't played their next match yet; otherwise the app explains why not.
- **Placements:** 1st, 2nd, then by the losers round you went out in (3rd, 4th, 5th–6th, 7th–8th…).

---

## Privacy and security

- No phone numbers, emails or accounts: only display names, pictures and results.
- The public can only **read**. Every change goes through a Netlify Function that checks the host's signed session; the host PIN is checked on the server, with a limit on wrong guesses.
- Self check-in and picture changes are public but only work during registration (check-in) and are rate-limited per phone; the host can remove any picture.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Blank page or **Setup problem** screen | It names the setting to fix. Netlify → Environment variables, then **Trigger deploy**. |
| Blue "Demo mode" banner on the live site | `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` missing → add, redeploy. |
| "Setup problem: SUPABASE_URL …" | Use the full `https://xxxx.supabase.co` (a bare project ID also works); not a dashboard link. |
| "Wrong PIN" | Re-create `HOST_PIN` with digits only, all scopes, same value everywhere, secret box unticked; redeploy. After 8 wrong tries, wait 15 minutes. |
| Setup check shows a table ❌ | Run the SQL file in Supabase → SQL Editor (or check the GitHub integration's deploy log). |
| "Photo uploads aren't set up yet" | The photo bucket wasn't created; characters and balls still work. Re-run the SQL file. |
| Yellow "Reconnecting…" | Wi-Fi dropped. Nothing is lost; it catches up by itself. |

---

## For developers

React 19 + Vite + TypeScript + Tailwind CSS 4 · Netlify (static site + Functions) · Supabase (Postgres + Realtime + Storage). Fonts are bundled (`@fontsource/yellowtail`, `bebas-neue`, `bowlby-one`).

```bash
npm install
npm run dev        # http://localhost:5173 (demo mode unless .env has Supabase keys)
npm test           # bracket engine, service layer, functions, SQL migration (PGlite)
npm run build
```

Bar-specific wording (names, times, address, day of week) lives in [`src/brand.ts`](src/brand.ts); colors and fonts in [`src/index.css`](src/index.css).

```
src/engine/        pure double-elimination engine + tests
src/shared/        service (all host/public actions), store interface, stats, avatars, seed
src/data/          SupabaseBackend (production) / DemoBackend (no config)
src/pages/         public pages, check-in, TV, player view, host/
netlify/functions/ api, host-login, checkin, avatar, health, keep-alive (daily)
supabase/          config.toml + migrations (one setup file)
```
