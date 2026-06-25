# TAKO — Teaching with Adaptive Knowledge Orchestration

---

## Project Overview

TAKO is a mobile-first, offline-first math RPG built in Godot 4 (GDScript) for Android. Players begin as a student having a quiet "midlife crisis" inside a billiard hall — a nod to our team name, Billiard Boys. An AI companion nudges him to stop wasting time and go learn instead. He leaves for school, where he's greeted by **4 doors representing subjects**: Math, Science, Languages, and Philippine History. Only **Math is active** in this prototype — the other three are visibly present but locked, signaling that the architecture is built to scale beyond this hackathon.

Walking through the Math door leads to a hallway with **Grade 7, 8, 9, and 10 choices**, all open from the start — progression is **not gated**, so players can enter any grade in any order and switch freely between them.

Inside a grade's hall, the player encounters "enemies" — each one is a math question scoped to that grade's skill domain. Answering correctly fills a **progression bar** specific to that grade. Answering incorrectly isn't a fail state — the **AI companion explains exactly what went wrong and walks through the correct reasoning**, in whatever language the student is typing in (English or Filipino). Players can **backtrack** past a hard question and return to it later. Reaching 100% in a grade hall unlocks the option to move to another grade/subject or replay questions for review.

The game is built to be genuinely playable with **zero internet connection** — Android's on-device **Gemini Nano** keeps AI feedback running offline — while syncing progress to the cloud whenever a connection is available.

---

## AI Architecture (Important — Read Before Modifying AI Logic)

TAKO deliberately separates **what the AI is trusted to do** from **what stays deterministic**, to avoid hallucinated math and unreliable grading:

| Task | Handled by | Why |
|---|---|---|
| **Math correctness** | Deterministic GDScript logic (template-based question generation, computed answers in code) | The AI is never asked "is this right?" — answers are always validated in code, never by a model |
| **Misconception identification** | Rule-based matching against known wrong-answer patterns per question template | Since questions come from parameterized templates, we already know what a given wrong answer typically indicates (sign error, wrong operation, etc.) — no AI guessing required |
| **Explanation phrasing** | AI (Claude/GPT online, Gemini Nano offline) | The AI's actual job is taking already-correct facts (what mistake was made, why) and phrasing them as a warm, in-character explanation — never determining the facts itself |
| **Companion banter / encouragement / milestone reactions** | Mostly scripted/templated dialogue; AI-flavored only where low-stakes | Keeps the companion feeling alive without unnecessary AI calls |

**Two-tier explanation generation:**
- **Online:** Claude/GPT API generates richer, more natural explanations, mirroring the player's language (English/Filipino) directly — no separate translation step.
- **Offline:** On-device **Gemini Nano** (via Android ML Kit GenAI / AICore) generates the same explanation from the same pre-determined facts, so the game stays genuinely AI-powered with zero connection — not just AI-when-convenient.

UI text (menus, buttons, labels) is **hardcoded** in English/Tagalog string tables with a manual toggle — no AI involved in UI localization, since that content is static and finite.

---
## Features
- **Story-driven intro** — billiard hall → school → subject doors → grade hallway, establishing both narrative hook and scalable subject/grade structure
- **AI-personalized misconception feedback** — wrong answers trigger a targeted explanation of the *specific* mistake made, not a generic "wrong, try again," generated in the player's language (English/Filipino)
- **Fully offline-first** — local save (SQLite) is the source of truth during play; Gemini Nano provides AI feedback with no internet required; progress syncs to Supabase only when a connection is available
- **Ungated grade progression** — Grade 7, 8, 9, 10 halls are all open from the start; each tracks its own independent progression %
- **Backtracking** — players can skip a difficult question and return to it later within a grade hall
- **Subject scalability (visible, not yet built)** — Science, Languages, and Philippine History doors are present but locked, signaling future expansion
- **Bilingual companion** — mirrors however the student types (English/Filipino) 
- **Touch controls** — virtual joystick and interact button auto-shown on Android
---

## Setup Instructions

### Prerequisites

- Android SDK + export templates
- An Android device running Android 10+ for Gemini Nano on-device AI (availability depends on supported Pixel/Samsung devices)
- A [Supabase](https://supabase.com) project (Postgres + Auth) for cloud sync
- An API key for Claude or GPT (online explanation generation)

### Android build (production)

1. In Godot: **Project → Export → Android**
2. Set your Android SDK path and debug keystore
3. Click **Export Project**
4. Install the APK on a supported Android device — Gemini Nano activates automatically; the virtual joystick appears on-screen

### Clearing save data

Open the in-game menu → **Settings** → **Clear Save Data** (tap twice to confirm).

---

## Technologies Used

| Layer | Technology | Purpose |
|---|---|---|
| **Game engine** | Godot 4.6 (GDScript) | Rendering, scenes, animation, Android export |
| **Math correctness** | Deterministic GDScript logic | Answer validation and misconception pattern matching — AI is never trusted to grade math or identify mistakes |
| **Online AI** | Claude / GPT API | Explanation phrasing when connected — richer, fuller natural language, language-mirrored |
| **Offline AI** | Gemini Nano (Android built-in, via ML Kit GenAI / AICore) | Explanation phrasing when offline — same job as the online tier, run entirely on-device |
| **Networking** | Godot `HTTPRequest` node | Calls Claude/GPT API and Supabase REST API directly |
| **Local storage** | Godot SQLite addon (`user://` path) | Offline-first source of truth: progression %, points, question history, per grade |
| **Cloud backend** | Supabase (Postgres + Auth) | Login, cross-device progress sync, mastery history |
| **Platform target** | Android (Godot native export) | Primary deployment target |

---

## Team Members and Roles

**Team Name:** Billiard Boys

| Name | Role |
|---|---|
| Balajadia, Vin Tristan E. | Database Administrator |
| Gilo, Eric Jonhson H. | All-around Helper |
| Guillermo, Christian P. | UI/UX Designer |
| Magdaong, Russell D. | Game Developer |

---

## Project Structure

```
TAKO/
├── scenes/
│   ├── core/          # GameManager, SceneManager, MainMenu, CharacterSelect
│   ├── gameplay/      # BattleScene, DialogueTrigger, Interactable
│   ├── levels/        # Billiards, School, GradeHallway, Grade7-10 Halls
│   └── ui/            # DialogueBox, PauseMenu, HintsPopup, HintButton, LanguageToggle
├── scripts/
│   ├── core/          # Autoloads: ApiClient, GameManager, SceneManager,
│   │                  #   PlayerDataManager, DialogueManager, AudioManager, Globals
│   ├── gameplay/      # BattleScene, Characters, Levels, UI
│   │   ├── characters/# Player, Enemy, Input, Movement, Animation, States
│   │   └── math/       # QuestionTemplates, AnswerValidator, MisconceptionMatcher
│   ├── ui/            # VirtualControls (Android touch joystick)
│   └── utilities/     # StateMachine, State
├── resources/         # Themes, fonts, tilesets, styleboxes
├── assets/            # Audio, sprites (characters, enemies, backgrounds, UI)
└── export_presets.cfg # Android + Web export configurations
```

---

## Battle Flow

```
Grade Hall → walk into enemy → BattleScene loads
  │
  ├─ Deterministic engine generates question for enemy's grade + SkillType,
  │   computes the correct answer in code
  ├─ Question shown in Problem Panel
  │
  ├─ Player types/selects answer → Submit
  │     ├─ Correct   → "Correct!" → progression bar updates → enemy defeated
  │     └─ Incorrect → Misconception identified via rule-based matching
  │                     → AI (Claude/GPT online, Gemini Nano offline) phrases
  │                       the explanation in the player's language
  │                     → player retries (unlimited) or backtracks to another question
  │
  └─ All enemies defeated in a grade hall → progression hits 100%
      → player may move to another grade/subject or replay for review
```

---

## Math Skill Domains (per Grade Hall)

| SkillType | Coverage | Typical Grade Focus |
|---|---|---|
| `BasicArithmetic` | Addition, subtraction, multiplication, division | Grade 7 |
| `Fractions` | Simplifying, comparing, operating on fractions | Grade 7–8 |
| `Algebra` | Solving for unknowns, expressions, linear equations | Grade 8–9 |
| `Geometry` | Area, perimeter, angles, coordinate geometry | Grade 9 |
| `WordProblems` | Applied multi-step reasoning | All grades |
| `Statistics` | Mean, median, mode, basic probability | Grade 10 |

> Prototype scope: 1–2 strong skill domains per grade hall rather than full curriculum coverage, to keep the hackathon build focused and polished.

---

## Data Model (Supabase)

- **`profiles`** — extends `auth.users` with username and `preferred_language` (en/tl)
- **`progress`** — one row per (user, subject, grade_level): `progression_pct`, `points`
- **`question_attempts`** — per-attempt log: `question_id`, `is_correct`, `misconception_category` — supports backtracking and future mastery analytics
- **`subjects`** — lookup table for the 4 doors (`id`, `display_name`, `is_active`) — only `math` is active in this prototype

Row-level security ensures each player can only read/write their own `progress` and `question_attempts` rows.
