# TAKO — Teaching with Adaptive Knowledge Orchestration

TAKO is a mobile-first, offline-first educational math RPG built in Godot 4 (GDScript) for Android. The game blends narrative roleplaying elements with a bilingual learning companion that provides adaptive math assistance.

---

## 1. Project Overview

Players start as a student inside a billiard hall (a creative nod to the development team, Billiard Boys). Prompted by an in-game AI companion, the player transitions to a school building featuring **4 locked subject doors**: Mathematics, Science, Languages, and Philippine History. In this prototype, the **Mathematics door is active and unlocked**, demonstrating a highly scalable architecture prepared to receive other subjects.

Entering the Mathematics door leads to a grade hall containing classrooms for **Grades 7, 8, 9, and 10**. Progress is **non-gated**—players are free to enter any grade, backtrack from difficult problems, and review lessons in any order. Engaging with obstacles/enemies triggers math questions aligned with the DepEd curriculum. Answering incorrectly triggers personalized AI feedback explaining the mistake in the player's choice of language (English or Tagalog/Filipino).

---

## 2. System Requirements

To install and run the TAKO APK, the following device specifications are required:

* **Game Execution (Minimum)**: Android 10.0 (API Level 29) or higher.
* **On-Device Offline AI (Gemini Nano)**: Android 14.0 (API Level 34) or higher on supported devices featuring Android AICore services (e.g., Google Pixel 8/9 series, Samsung Galaxy S24 series).
* **Network Connectivity**: Optional. The game runs fully offline using a local database save state. Progress is automatically synced to the cloud backend whenever an internet connection becomes active.

---

## 3. Core Software Architecture Updates

Recent engineering cycles implemented the following features:

### A. Offline-First SQLite Database Integration
* Integrated [db_manager.gd](file:///d:/Tako/tako-game/scripts/SQLite/db_manager.gd) as a global Autoload singleton.
* Configured local schemas on the device (`user://tako.db`) for tracking user profiles, progress, and question attempt logs.
* Implemented automatic table migrations (mapping integer IDs to text UUIDs) and dirty flags to support seamless syncing to Supabase.

### B. Curriculum-Aligned Question Templates
* Implemented 14 parameterized, deterministic math templates in [question_templates.gd](file:///d:/Tako/tako-game/scripts/gameplay/math/question_templates.gd) covering Grades 7–10:
  * **Grade 7**: Basic negative arithmetic, simplifying fractions, decimal-to-fraction conversions, linear equations, rectangle perimeter.
  * **Grade 8**: Exponent multiplication, multi-step linear equations, linear slopes, systems of linear equations.
  * **Grade 9**: Quadratic equations, Pythagorean theorem.
  * **Grade 10**: Mean/median/mode statistics, bag-drawing probability, circle circumference.
* Every lambda block inside the template definitions is fully parenthesized `(func(): ...)` to resolve GDScript compilation/indentation unindent parsing errors.

### C. Equivalence Answer Validation
* Created [answer_validator.gd](file:///d:/Tako/tako-game/scripts/gameplay/math/answer_validator.gd) to parse and match equivalent formats, ensuring that equivalent answers (such as fraction `1/2`, decimal `0.5`, or non-simplified fractions like `2/4`) are evaluated as correct.

### D. Dual-Provider Gemini Integration
* Refactored [api_client.gd](file:///d:/Tako/tako-game/scripts/core/api_client.gd) to support dynamic provider switching:
  * **Google Gemini 1.5 Flash (Online REST)**: Uses standard HTTPS POST requests to Google's generative developer API when an internet connection is present.
  * **Google Gemini Nano (Offline JNI)**: Communicates asynchronously via native JNI signals with a Godot Android Plugin (`GodotGeminiNano`) to generate offline feedback on-device.
  * **Ollama (Local Developer Testing)**: Bypassed on Android builds, this local option remains available solely for debugging in the Godot PC editor.

### E. Secure Environment Key Configuration
* Added a local [.env](file:///d:/Tako/tako-game/.env) config loader to keep API keys secure during developer testing. The key is parsed on startup and omitted from Git via [.gitignore](file:///d:/Tako/tako-game/.gitignore).

---

## 4. AI & Phrasing Architecture

To avoid hallucinated math grading and incorrect solutions, TAKO separates **math grading logic** from **natural language generation**:

| Layer / Responsibility | Handler | Rationale |
|---|---|---|
| **Math Correctness** | Deterministic GDScript | Answers are compared and parsed in code—never by the LLM. |
| **Misconception Matching** | Rule-Based Templates | Wrong answers are compared to known math errors (e.g., adding denominators directly) before passing metadata to the AI. |
| **Explanation Phrasing** | Gemini 1.5 Flash / Gemini Nano | The AI takes the verified misconception metadata and phrases it into an encouraging, in-character explanation. |

---

## 5. Technology Stack

* **Game Engine**: Godot Engine 4.6.2 (GDScript)
* **Local Storage**: Godot SQLite addon
* **Cloud Storage & Sync**: Supabase (PostgreSQL + REST Auth)
* **AI Engine**: Gemini 1.5 Flash (Cloud API) & Gemini Nano (Android AICore JNI)

---

## 6. Project Directory Structure

```
TAKO/
├── scenes/
│   ├── core/          # GameManager, SceneManager, MainMenu, CharacterSelect
│   ├── gameplay/      # BattleScene, DialogueTrigger, Interactable
│   ├── levels/        # Billiards, School, Grade7-10 Halls
│   └── ui/            # DialogueBox, PauseMenu, HintsPopup, VirtualControls
├── scripts/
│   ├── core/          # Autoloads: ApiClient, GameManager, PlayerDataManager, Globals
│   ├── gameplay/      # BattleScene, Level loaders, movement animation state machines
│   │   └── math/      # QuestionTemplates, AnswerValidator, MathManager
│   └── SQLite/        # db_manager.gd (SQLite database controller)
├── resources/         # Themes, fonts, tilesets
├── assets/            # Audio, character sprites, monster frames, backgrounds
├── .gitignore         # Ignores .godot/ cache and local .env files
└── project.godot      # Godot engine project registry (Autoloads, input mapping)
```

---

## 7. Team Members & Roles

**Team Name:** Billiard Boys

| Name | Role |
|---|---|
| Balajadia, Vin Tristan E. | Database Administrator |
| Gilo, Eric Jonhson H. | Backend Developer |
| Guillermo, Christian P. | UI/UX Designer |
| Magdaong, Russell D. | Game Developer |
