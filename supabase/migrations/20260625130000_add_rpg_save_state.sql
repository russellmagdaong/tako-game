-- ============================================================
-- RPG SAVE STATE SYNC TABLES
-- ============================================================

create table public.player_state (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null unique,
    player_name text not null default '',
    selected_character text not null default 'playerm',
    last_level text not null default '',
    last_position_x numeric not null default 0,
    last_position_y numeric not null default 0,
    music_volume numeric not null default 0.5,
    sfx_volume numeric not null default 0.5,
    has_played boolean not null default false,
    updated_at timestamp with time zone not null default now()
);

create table public.triggered_dialogues (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    dialogue_id text not null,
    unique(user_id, dialogue_id)
);

create table public.defeated_enemies (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    enemy_id text not null,
    unique(user_id, enemy_id)
);

create table public.achievements (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade not null,
    achievement_id text not null,
    unlocked_at timestamp with time zone not null default now(),
    unique(user_id, achievement_id)
);

alter table public.player_state enable row level security;
alter table public.triggered_dialogues enable row level security;
alter table public.defeated_enemies enable row level security;
alter table public.achievements enable row level security;

create policy "Users manage own player state"
on public.player_state
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users manage own triggered dialogues"
on public.triggered_dialogues
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users manage own defeated enemies"
on public.defeated_enemies
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users manage own achievements"
on public.achievements
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
