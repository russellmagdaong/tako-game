# TAKO — Teaching with Adaptive Knowledge Orchestration

TAKO is a mobile-first, offline-first educational math RPG built in **Godot 4 (GDScript)** for Android. It blends narrative roleplaying with a bilingual (English / Filipino) AI learning companion that generates curriculum-aligned math questions and adaptive, personalized feedback.

The entire experience — authentication, dashboard, and gameplay — ships as a **single Godot APK**.

---

## 1. Project Overview

Players begin as a student inside a billiard hall (a nod to the development team, **Billiard Boys**). Guided by an in-game AI companion, the player moves to a school building with **4 subject doors**: Mathematics, Science, Languages, and Philippine History. In this prototype the **Mathematics door is active**, demonstrating a scalable architecture ready to receive other subjects.

Behind the Mathematics door is a grade hall with classrooms for **Grades 7–10**. Progress is **non-gated** — players can enter any grade, backtrack, and review in any order. Encountering an enemy triggers a DepEd-curriculum math question. Answering incorrectly produces **AI-generated feedback** that reacts to the player's actual answer and gets more specific with each attempt, in the player's chosen language.

---

## 2. Key Features

- **Single consolidated app** — landing, sign in / sign up, dashboard, and the RPG all run inside one Godot project.
- **Offline-first** — a local SQLite database stores all player data. The game is fully playable with no network connection.
- **Flexible accounts** — play instantly as a **Guest** (fully offline), or create an **online account** (Supabase email/password) whose progress syncs to the cloud. If the backend is unreachable, sign-up/sign-in gracefully fall back to a local account.
- **Cloud sync** — when signed in online, local changes are pushed to Supabase automatically.
- **AI-generated content** — Google Gemini phrases each question uniquely and writes encouraging, misconception-aware feedback.
- **Bilingual** — English and Tagalog/Filipino throughout questions and feedback.

---

## 3. Technology Stack

| Layer | Technology |
|---|---|
| **Game Engine** | Godot Engine **4.6.2** (GDScript) |
| **Local Storage** | `godot-sqlite` addon (`user://tako.db`) |
| **Cloud Backend** | Supabase (PostgreSQL, GoTrue Auth, PostgREST) |
| **AI (online)** | Google **Gemini 2.5 Flash** (REST API) |
| **AI (on-device, scaffolded)** | Google Gemini Nano via Android AICore (see §7) |
| **AI (dev only)** | Ollama (local desktop testing) |

---

## 4. Architecture

### Autoload singletons (`scripts/core/`)
- **`AuthManager`** — guest sessions (local UUID, offline), Supabase GoTrue email/password auth, offline local-account fallback, session persistence (`user://auth_session.json`).
- **`GameManager`** — app entry point; shows landing / dashboard based on session, and drives the RPG.
- **`SceneManager`** — level loading, transitions, and battles.
- **`PlayerDataManager`** — in-memory player facade persisted through SQLite.
- **`SupabaseSyncManager`** — pushes dirty local rows to Supabase (one-way local→cloud) on a timer when online and authenticated.
- **`ApiClient`** — AI provider abstraction (Gemini Flash / Gemini Nano / Ollama) with a static-template fallback.
- **`DatabaseManager`** (`scripts/SQLite/`) — SQLite schema, migrations, and data access.

### AI & phrasing separation
To avoid the LLM ever mis-grading math, **correctness logic is fully deterministic** and separated from natural-language generation:

| Responsibility | Handler | Rationale |
|---|---|---|
| **Math correctness** | Deterministic GDScript (`AnswerValidator`) | Answers are parsed/compared in code — never by the AI. Equivalent forms (`1/2`, `0.5`, `2/4`) are accepted. |
| **Misconception matching** | Rule-based templates (`QuestionTemplates`) | Wrong answers are matched to known error patterns before any AI call. |
| **Question & feedback phrasing** | Gemini 2.5 Flash | The AI turns verified specs/misconceptions into unique questions and escalating, in-character explanations. |

### Curriculum content
14 parameterized, deterministic templates in [question_templates.gd](scripts/gameplay/math/question_templates.gd):
- **Grade 7:** negative-integer arithmetic, simplifying fractions, decimal→fraction, linear equations, rectangle perimeter.
- **Grade 8:** exponent product rule, multi-step linear equations, slope between two points.
- **Grade 9:** quadratic discriminant, distance between points (Pythagorean), direct variation.
- **Grade 10:** median of a data set, circle circumference, probability (drawing from a bag).

If the AI is unavailable, deterministic question/feedback templates in `MathManager` are used instead, so gameplay never blocks.

---

## 5. System Requirements

- **Run the APK:** Android 7.0 (API 24) or higher (as configured in the Android export).
- **Network:** Optional. The game runs fully offline; online accounts and cloud sync activate when a connection is available.
- **On-device offline AI (Gemini Nano):** only on AICore-capable flagships (e.g., Pixel 8/9, Galaxy S24/S25). Not active in the current build — see §7.

---

## 6. Setup & Installation

### Option A — Install the prebuilt APK (easiest)
You don't need Godot or any build tools to play. A ready-to-install **`TAKO.apk`** is provided with the project.

1. Copy `TAKO.apk` to your Android device (or an emulator such as MuMu Player).
2. Open it and allow installation from unknown sources if prompted.
3. Launch **TAKO** and tap **Play as Guest** to start immediately, or **Sign In / Sign Up** for a cloud account.

The Supabase and Gemini keys are already bundled in this build, so online accounts, cloud sync, and AI work out of the box (with an internet connection). The game is also fully playable offline.

> Via ADB: `adb install -r TAKO.apk`

### Option B — Run / build from source

#### Prerequisites
- **Godot Engine 4.6.2** (standard build).
- For Android export: **Android export templates** (Godot → Editor → Manage Export Templates) and a configured **Android SDK / keystore**.

#### Run in the editor
1. Clone the repository:
   ```bash
   git clone https://github.com/russellmagdaong/tako-game.git
   ```
2. Open the project in **Godot 4.6.2** (import `project.godot`). The first import builds the asset cache.
3. Configure the **Gemini API key** (required for AI; kept out of git):
   - Create a file named `.env` in the project root (`res://.env`) with:
     ```
     GEMINI_API_KEY="your-google-gemini-api-key"
     ```
   - Get a key from [Google AI Studio](https://aistudio.google.com/apikey). `.env` is gitignored and bundled into the APK via the export filter.
4. The **Supabase URL and anon key** are already set in `project.godot` under the `[tako]` section. To point at your own project, edit `tako/supabase/url` and `tako/supabase/anon_key`.
5. Press **F5** to run. You'll land on the title screen — tap **Play as Guest** to start immediately, or **Sign In / Sign Up** for an online account.

#### Build the Android APK
1. Project → **Export** → select the **Android** preset (outputs `../TAKO.apk`).
2. Ensure a debug/release keystore is configured, then **Export Project**.
3. Install on a device/emulator (e.g., `adb install -r TAKO.apk`).

#### Backend (Supabase) setup
If you use your own Supabase project, the app expects these tables: `profiles`, `progress`, `question_attempts`, `player_state`, `defeated_enemies`, `achievements`, `triggered_dialogues`, `subjects` (column shapes match `TABLE_CONFIG` in [supabase_sync_manager.gd](scripts/core/supabase_sync_manager.gd)).

For online accounts and cloud sync to work:
- Enable **Row-Level Security** policies allowing each authenticated user to manage their own rows (`auth.uid() = user_id`, and `auth.uid() = id` for `profiles`), plus a `handle_new_user` trigger to create a `profiles` row on signup.
- For frictionless testing, disable email confirmation under **Authentication → Sign In / Providers → Email**, or configure custom **SMTP** (the built-in email service is heavily rate-limited).

---

## 7. On-Device AI (Gemini Nano) — Status

`ApiClient` includes a complete code path for **Gemini Nano** (offline, on-device) via a Godot Android plugin (`GodotGeminiNano`). It is **scaffolding only** in the current build: no plugin is bundled, so the app never activates it and there is no impact on existing behavior.

- **Online:** Gemini 2.5 Flash (cloud).
- **Offline:** deterministic static templates.
- **Future:** on AICore-capable devices, adding the `GodotGeminiNano` plugin would enable offline AI feedback automatically; unsupported devices continue using the fallback.

---

## 8. Project Directory Structure

```
TAKO/
├── scenes/
│   ├── core/          # GameManager, MainMenu, CharacterSelect
│   ├── gameplay/      # BattleScene, interactables, triggers
│   ├── levels/        # Billiards, School, Grade 7–10 halls
│   └── ui/
│       ├── auth/      # LandingScreen, LoginScreen
│       ├── dashboard/ # Dashboard (Home / World / Settings tabs)
│       └── ...        # DialogueBox, PauseMenu, VirtualControls
├── scripts/
│   ├── core/          # Autoloads: AuthManager, GameManager, SceneManager,
│   │                  #   PlayerDataManager, SupabaseSyncManager, ApiClient, Globals
│   ├── gameplay/
│   │   └── math/      # QuestionTemplates, AnswerValidator, MathManager
│   ├── ui/
│   │   ├── auth/      # landing_screen.gd, login_screen.gd
│   │   └── dashboard/ # dashboard.gd
│   └── SQLite/        # db_manager.gd
├── resources/         # Themes, fonts, tilesets, UI styles
├── assets/            # Audio, sprites, backgrounds, logo
├── .env               # Gemini API key (gitignored, dev-supplied)
├── export_presets.cfg # Android / Web export configuration
└── project.godot      # Autoloads, Supabase config, input mapping
```

---

## 9. Team Members & Roles

**Team Name:** Billiard Boys

| Name | Role |
|---|---|
| Balajadia, Vin Tristan E. | Database Administrator |
| Gilo, Eric Jonhson H. | Backend Developer |
| Guillermo, Christian P. | UI/UX Designer |
| Magdaong, Russell D. | Game Developer |
