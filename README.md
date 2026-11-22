# Social Diary for Wrath of the Lich King

Social Diary remembers the people you meet and keeps your journey in a paper
journal. This fork adapts it to the **original WoW 3.3.5a client**, build 12340
(Interface 30300).

Current version: **1.5.0-wotlk.2**. The default branch is
[`wotlk-3.3.5`](https://github.com/hartmark/social_diary/tree/wotlk-3.3.5).

The port is based on [Social Diary](https://github.com/social-diary/social_diary)
[v1.5.0](https://github.com/social-diary/social_diary/tree/v1.5.0), commit
`88bf2122843c483d7ba9af66c35c0c7cfd81770f`. That version was written for WoW
Forever's modern addon API. Features from upstream v4 are not included here.

## Install

1. [Download the WotLK branch ZIP](https://github.com/hartmark/social_diary/archive/refs/heads/wotlk-3.3.5.zip).
2. Extract it and rename the extracted repository folder to `social_diary`.
3. Put that folder in your game's `Interface/AddOns/` directory. The file
   `Interface/AddOns/social_diary/social_diary.toc` must exist directly there,
   without another repository folder inside it.
4. Close WoW completely and start it again. Enable **Social Diary** in the
   character selection screen's AddOns list.

Keep this fork when updating: upstream Forever builds do not support the
original 3.3.5 client.

## Open the diary

- `/sd` opens the journal.
- `/sd add` adds your current target to the diary.
- `/sd settings` opens its settings.
- The **Social Diary** tab on the Friends window opens the journal too.

People you cross paths with are pencilled in automatically. Those who never
become part of your diary are rubbed out after 30 days by default. Adding
someone inks them in for good. Everything stays on your computer.

## What the port adapts

The compatibility layer handles the original client's player IDs, group events,
timers, combat-log kills and deaths, and quest rewards. It also adapts tooltips,
settings and journal rendering. These API adapters are private to Social Diary.

## Known limits

- Nearby players are noticed through your target, focus, mouseover and group.
  The original client has no modern nameplate unit tokens.
- Retail map artwork and overlays, the modern damage meter and death recap
  are unavailable.
- Some paper masks and geometric effects are simplified.
- Your zone and coordinates are read through the old map API. Coordinates
  are skipped while the world map is open to preserve its selected view.

## Validation

The upstream mock suite passes **6,495 checks**. Separate old-client tests cover
loading, player IDs, timers, groups, quest rewards, combat-log payloads and
opening the journal. Rendering adapter tests pass too:

```sh
luajit tests/run.lua
luajit tests/legacy.lua
luajit tests/legacy_ui.lua
```

Opening the diary with `/sd` has also been reported working in the actual
3.3.5 client after the TOC path correction. Capture and the full interface
have not yet been comprehensively verified in the game.

## Credits and licence

Social Diary was created by [social-diary](https://github.com/social-diary).
This fork retains the upstream v1.5.0 [MIT licence](LICENSE).

The unmodified **Neuton Italic** font is Copyright 2010 The Neuton Project
Authors and is supplied under the [SIL Open Font License 1.1](Fonts/OFL.txt).
The optional Questie integration comes from upstream; credit also belongs to
[Questie and QuestieDB](https://github.com/Questie). The retained upstream map
overlay table was generated from client DB2 tables through
[wago.tools](https://wago.tools); retail map overlays are unavailable in this port.

World of Warcraft and Blizzard are trademarks of Blizzard Entertainment.
Social Diary is an unofficial fan project, unaffiliated with Blizzard.
