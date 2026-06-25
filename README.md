# TAKO

A mobile-first math RPG built in Godot (GDScript). Players explore dungeon levels, encounter enemies, and defeat them by solving math questions generated and diagnosed by AI.

---

## Concept

The level format is unchanged from the original: players must defeat every enemy in a level to reach the exit. Each enemy encounter triggers a battle scene where the player answers a math question. Correct answer → enemy defeated. Wrong answer → AI-generated feedback nudges the player toward the right thinking.

---

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| **Game engine** | Godot 4.6 (GDScript) | Already built, exports natively to Android, handles rendering / animation / scenes |
| **Local storage** | Godot SQLite addon or built-in `ConfigFile` / `FileAccess` | Offline-first source of truth during play |
| **Backend / cloud DB** | Supabase (Postgres + Auth) | Login, cross-device progress backup, relational fit for progress/mastery data |
| **Networking** | Godot's `HTTPRequest` node | Calls Supabase REST API and the AI API endpoint directly — no separate Node.js layer needed unless custom backend logic is required |
| **Online AI** | Claude or GPT-4o API | Question phrasing + misconception diagnosis (high-quality reasoning, not used for math correctness) |
| **Offline AI fallback** | Rule-based misconception matcher (+ optionally Gemini Nano via a Kotlin/Android plugin — stretch goal) | Keeps explanations working with no connection |
| **Math correctness** | Deterministic GDScript functions (template-based question generation + computed answers) | Never trust the LLM to grade math — avoids hallucinated correctness |
| **Platform target** | Android (native export from Godot) | Matches the mobile-first / on-device AI direction |

---

## Project Structure

```
TAKO/
├── scenes/
│   ├── core/          # GameManager, SceneManager, MainMenu, CharacterSelect
│   ├── gameplay/      # BattleScene, DialogueTrigger, Interactable
│   ├── levels/        # Level0–Level31 dungeon scenes
│   └── ui/            # DialogueBox, PauseMenu, HintsPopup, HintButton
├── scripts/
│   ├── core/          # Autoloads: ApiClient, GameManager, SceneManager,
│   │                  #   PlayerDataManager, DialogueManager, AudioManager,
│   │                  #   Globals, Modules, Logger
│   ├── gameplay/      # BattleScene, Characters, Levels, UI
│   │   └── characters/# Player, Enemy, Input, Movement, Animation, States
│   ├── ui/            # VirtualControls (touch joystick for Android)
│   └── utilities/     # StateMachine, State
├── resources/         # Themes, fonts, tilesets, battle styleboxes
├── assets/            # Audio, sprites (characters, enemies, backgrounds)
└── export_presets.cfg # Android + Web export configs
```

---

## Math Domain

Questions are generated per enemy encounter based on the enemy's assigned `SkillType`:

| Skill | Description |
|---|---|
| `BasicArithmetic` | Addition, subtraction, multiplication, division |
| `Fractions` | Simplifying, comparing, operating on fractions |
| `Algebra` | Solving for unknowns, expressions, linear equations |
| `Geometry` | Area, perimeter, angles, basic coordinate geometry |
| `WordProblems` | Applied multi-step reasoning problems |
| `Statistics` | Mean, median, mode, basic probability |

---

## AI Integration

### Online (Claude / GPT-4o)
- Called via `HTTPRequest` when the device is online
- Responsible for **question phrasing** and **misconception feedback** only
- Math answer is always computed deterministically — the LLM is never trusted for grading

### Offline fallback
- Rule-based misconception matcher handles common wrong-answer patterns
- Gemini Nano via Kotlin/Android plugin is a stretch goal for richer on-device feedback

### Current dev setup (local Ollama)
During development, `ApiClient` points to a local [Ollama](https://ollama.com) instance at `http://localhost:11434`. Change the model in `scripts/core/api_client.gd`:

```gdscript
var model: String = "gemma3"  # swap for any installed model
```

---

## Battle Flow

```
Level overworld → touch enemy → BattleScene loads
  │
  ├─ AI generates question for enemy's SkillType
  ├─ Question displayed in Problem Panel
  │
  ├─ Player types answer → Submit / Enter
  │     ├─ Correct  → "Correct!" → 2s delay → return to level, enemy defeated
  │     └─ Incorrect → AI generates feedback → player retries
  │
  └─ All enemies in level defeated → exit trigger unlocks next level
```

---

## Controls

| Platform | Movement | Interact |
|---|---|---|
| Desktop / keyboard | WASD | E |
| Android / touch | Left-side virtual joystick | On-screen E button |

The virtual joystick is auto-shown on Android and hidden on desktop. It injects standard Godot input actions so all movement logic is unchanged.

---

## Backend (Supabase)

Planned schema:

- `players` — auth + profile
- `progress` — level completion, defeated enemies
- `mastery` — per-skill accuracy history

The game uses Godot's `HTTPRequest` node to call Supabase's REST API directly. No custom server required for basic CRUD.

---

## Getting Started

### Prerequisites
- Godot 4.6
- Android export templates (for device builds)
- [Ollama](https://ollama.com) with a model pulled (for local dev AI)

### Local dev
1. Clone the repo and open `project.godot` in Godot 4.6
2. Start Ollama: `ollama serve`
3. Pull a model: `ollama pull gemma3`
4. Press **Run** in the editor

### Android build
1. Set up Android export in Godot (SDK + keystore)
2. Project → Export → Android → Export Project
3. The virtual joystick activates automatically on device

---

## Roadmap

- [ ] Replace local Ollama with Claude / GPT-4o API calls
- [ ] Supabase auth + cloud save
- [ ] Deterministic question templates (remove LLM dependency for grading)
- [ ] Offline misconception matcher
- [ ] SQLite local storage for progress/mastery
- [ ] Gemini Nano on-device fallback (stretch goal)
- [ ] Polish Android UI (larger touch targets, responsive layout)
