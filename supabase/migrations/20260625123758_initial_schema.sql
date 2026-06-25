-- ============================================================
-- INITIAL SCHEMA
-- TAKO Hackathon
-- ============================================================

-- =========================
-- Profiles
-- =========================
create table public.profiles (
    id uuid references auth.users(id) on delete cascade primary key,
    username text not null,
    preferred_language text not null default 'en',
    xp int not null default 0,
    created_at timestamp with time zone not null default now()
);

-- =========================
-- Subjects
-- =========================
create table public.subjects (
    id text primary key,
    display_name text not null,
    is_active boolean not null default false
);

-- =========================
-- Progress
-- One row per user/subject/grade
-- =========================
create table public.progress (
    id uuid primary key default gen_random_uuid(),

    user_id uuid references auth.users(id) on delete cascade not null,

    subject text not null,

    grade_level int not null,

    progression_pct numeric not null default 0
        check (progression_pct >= 0 and progression_pct <= 100),

    points int not null default 0,

    updated_at timestamp with time zone not null default now(),

    unique(user_id, subject, grade_level)
);

-- =========================
-- Question Attempts
-- Keeps full history
-- =========================
create table public.question_attempts (
    id uuid primary key default gen_random_uuid(),

    user_id uuid references auth.users(id) on delete cascade not null,

    subject text not null,

    grade_level int not null,

    question_id text not null,

    is_correct boolean not null,

    misconception_category text,

    attempted_at timestamp with time zone not null default now()
);

-- ============================================================
-- Seed Subjects
-- ============================================================

insert into public.subjects (id, display_name, is_active)
values
('math', 'Math', true),
('science', 'Science', false),
('languages', 'Languages', false),
('history', 'History', false);

-- ============================================================
-- Enable Row Level Security
-- ============================================================

alter table public.profiles enable row level security;
alter table public.progress enable row level security;
alter table public.question_attempts enable row level security;
alter table public.subjects enable row level security;

-- ============================================================
-- Profiles Policies
-- ============================================================

create policy "Users can view own profile"
on public.profiles
for select
using (auth.uid() = id);

create policy "Users can insert own profile"
on public.profiles
for insert
with check (auth.uid() = id);

create policy "Users can update own profile"
on public.profiles
for update
using (auth.uid() = id);

-- ============================================================
-- Progress Policies
-- ============================================================

create policy "Users manage own progress"
on public.progress
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ============================================================
-- Question Attempts Policies
-- ============================================================

create policy "Users manage own attempts"
on public.question_attempts
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ============================================================
-- Subjects Policies
-- ============================================================

create policy "Anyone can read subjects"
on public.subjects
for select
using (true);

-- ============================================================
-- Automatically create profile on signup
-- ============================================================

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
    insert into public.profiles (
        id,
        username
    )
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'username', 'Player')
    );

    return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();