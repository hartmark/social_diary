Social Diary for original WoW 3.3.5a
===================================
Version: 1.5.0-wotlk.2
Client: 3.3.5a build 12340, Interface 30300.
Fork: https://github.com/hartmark/social_diary (branch wotlk-3.3.5).
Based on upstream social-diary/social_diary v1.5.0, MIT licence,
commit 88bf2122843c483d7ba9af66c35c0c7cfd81770f.

Download the wotlk-3.3.5 branch ZIP, extract it and rename the repository
folder to social_diary. Put it under Interface/AddOns so that
Interface/AddOns/social_diary/social_diary.toc exists without nesting.
Close and restart the entire client, then enable Social Diary in AddOns.

/sd opens the journal; /sd add remembers your target; /sd settings opens
settings. A Social Diary tab is also added to the Friends window.
Left-click the minimap book button to open or close the journal; right-click
it for settings. Drag it around the minimap to move it. Its position is
remembered for each character.

Private compatibility adapters handle original player IDs, group events,
timers, combat-log kills/deaths, quest rewards, tooltips and rendering.

Limits: nearby players are observed through target/focus/mouseover/group;
modern nameplate unit tokens, retail map art/overlays, damage meter and
death recap are unavailable. Some paper effects are simplified.
Coordinates are skipped while the world map is open to preserve its view.
Upstream v4 features are not included. Do not update to a Forever build.

Validation: 6,519 upstream mock checks and separate old-client API/UI tests
pass. Opening /sd has been reported working in the actual 3.3.5 client;
capture and the full interface still need broader in-game verification.
The minimap button has not yet been verified in the game.
Run: luajit tests/run.lua; luajit tests/legacy.lua; luajit tests/legacy_ui.lua.

Original Social Diary: https://github.com/social-diary/social_diary
Code licence: LICENSE (MIT). Unmodified Neuton Italic font:
Copyright 2010 The Neuton Project Authors; Fonts/OFL.txt (SIL OFL 1.1).
See README.md for installation, validation and the full upstream credits.
