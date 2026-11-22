# Social Diary

A World of Warcraft addon that remembers the people you meet in the open world —
groups, trades, whispers, fights, deaths, sightings, reunions — and presents them,
plus your own journey (levels, firsts, zones, sessions), as a hand-written,
paper-styled journal. Open with `/sd`.

## Target game: original Wrath of the Lich King 3.3.5a

This fork's `wotlk-3.3.5` branch targets the original build 12340 client,
Interface 30300. It starts from upstream Social Diary v1.5.0, which targets
WoW Forever's retail API. Keep the existing journal and saved-data model;
adapt old-client APIs through the addon's private environment in
`Core/Legacy.lua` and rendering wrappers in `Core/LegacyUI.lua`. Do not
replace global Blizzard APIs or change other addons' frames/metatables.

Every addon Lua chunk except the adapters enters `SocialDiaryLegacyEnv`
when present. TOC paths must use Windows backslashes: the original client's
loader rejects forward slashes. `tests/wowmock.lua` normalizes those paths
for offline loading. Development commands are loaded explicitly by the mock,
not by the shipped TOC.

Run all three checks before pushing:

```sh
luajit tests/run.lua
luajit tests/legacy.lua
luajit tests/legacy_ui.lua
```

The first suite models the upstream API; the other checks exercise the old
client adapter and rendering compatibility. Passing mocks does not prove
complete in-game compatibility. The journal opens in the user's client;
other capture and rendering paths still need in-game validation.

## Where to find what

| Path | Contents |
|---|---|
| `social_diary.toc` | Load order, SavedVariables (`SocialDiaryDB`, `SocialDiaryCharDB`) |
| `Core/` | Data model and logic: DB, identity, people, diary, timeline, journey, sessions, reunions, slash commands, event wiring |
| `Core/Bridges/` | Optional integrations (Questie) |
| `Capture/` | Game-event listeners that record interactions (group, trade, whisper, combat, deaths, PvP, sightings, journey) |
| `Data/` | Static data tables (e.g. quest-chain finales) |
| `UI/` | Journal frames and pages, cards, toasts, heat map, settings; shared style in `Style*.lua` |
| `Dev/` | Debug tools and test data (not for release) |
| `tests/` | Offline test suite against a WoW API mock (`wowmock.lua`). Run: `luajit tests/run.lua` (`-v` verbose, or pass file names) — add new files to `FILES` in `run.lua` |
| `.claude/` | Skills (`skills/`) and project rules (`rules/`) are in the repo. The PRD, plans, research notes and UI proposals stay local and untracked (`.gitignore`); code comments cite them by name and requirement ID |
| `CHANGELOG.md` | Release notes |
| `README.md`, `CONTRIBUTING.md`, `.github/` | Public front door: install, privacy, credits; contributor guide; CI (`tests.yml`), release (`release.yml`), issue forms |

Never commit images (`*.png` is gitignored) or anything recorded from real players (names, GUIDs, chat). Tests and examples use invented names.

## Rules

When working on UI, invoke a subagent and supply it with the /frontend-design skill, as this agent has the expertise to design the UI.

Work on Your Diary's plates (layouts, captions, margin notes and cards, marks, the full zone page) goes to a subagent that loads /plates (`.claude/skills/plates/`) as well as /frontend-design.

If you work on more text a player reads, give it to the /copywriter skill (`.claude/skills/copywriter/`) using a subagent.

Releases go through /release-version (`.claude/skills/release-version/`).
