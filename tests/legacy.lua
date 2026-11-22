-- Original 3.3.5's loader rejects forward slashes in TOC file paths.
for line in io.lines('social_diary.toc') do
    if line:match('^[^#].*%.lua%s*$') then
        assert(not line:find('/', 1, true), 'TOC must use Windows path separators: ' .. line)
        local file = line:gsub('\\', '/')
        local handle = assert(io.open(file, 'rb')); handle:close()
    end
end
-- Old-client boot and event regression test. Run with Lua 5.1 or LuaJIT.
local mock = dofile('tests/wowmock.lua')
mock.Reset()
local oldFrame = CreateFrame
local modern = { 'SetColorTexture', 'SetRotation', 'SetShown', 'SetSize', 'SetClipsChildren',
    'CreateMaskTexture', 'AddMaskTexture', 'SetVertexOffset', 'SetGradient', 'SetPropagateKeyboardInput',
    'SetObeyStepOnDrag', 'SetMaxLines', 'GetUnboundedStringWidth' }
local function LegacyObject(f)
    local absent = {}
    if f.frameType == 'EditBox' then
        f.Enable, f.Disable = nil, nil
        absent.Enable, absent.Disable = true, true
    end
    for _, k in ipairs(modern) do f[k] = nil; absent[k] = true end
    if f.frameType == 'Texture' then
        absent.SetRotation = nil
        -- Actual build12340 observed in-game: native SetRotation(0) discards
        -- a previous crop and expands UVs beyond the texture's boundaries.
        f.SetRotation = function(self)
            self:SetTexCoord(-0.2071068, -0.2071068, -0.2071068, 1.2071068,
                1.2071068, -0.2071068, 1.2071068, 1.2071068)
        end
    end
    local old = getmetatable(f)
    setmetatable(f, { __index = function(self, key)
        if absent[key] then return nil end
        return old and old.__index(self, key)
    end })
    if f.CreateTexture then
        local create = f.CreateTexture
        f.CreateTexture = function(self, ...) return LegacyObject(create(self, ...)) end
    end
    if f.CreateFontString then
        local create = f.CreateFontString
        f.CreateFontString = function(self, ...) return LegacyObject(create(self, ...)) end
    end
    f.GetChildren = function() return end
    f.SetGradientAlpha = function() end
    f.HasScript = function(self, s) return s ~= 'OnHyperlinkClick' and s ~= 'OnHyperlinkEnter' and s ~= 'OnHyperlinkLeave' end
    return f
end
CreateFrame = function(kind, name, parent, template)
    assert(template ~= 'BackdropTemplate')
    return LegacyObject(oldFrame(kind, name, parent, template))
end
for k in pairs(_G) do if type(k) == 'string' and k:match('^C_') then _G[k] = nil end end
Enum, Settings, Menu, MenuUtil, TooltipDataProcessor = nil, nil, nil, nil, nil
CreateColor, GetServerTime, UnitFullName, GetNormalizedRealmName = nil, nil, nil, nil
SocialUIFrame, SOUNDKIT, GetFileIDFromPath = nil, nil, nil
FriendsFrame = CreateFrame('Frame', 'FriendsFrame', UIParent)
FriendsFrame.numTabs = 4
FriendsFrameTab4 = CreateFrame('Button', 'FriendsFrameTab4', FriendsFrame)
GetBuildInfo = function() return '3.3.5', '12340', '', 30300 end
local realTime = 1000
GetTime = function() return realTime end
time = function() return mock.now end
GetNumRaidMembers = function() return mock.inRaid and mock.groupSize or 0 end
GetNumPartyMembers = function() return not mock.inRaid and math.max(mock.groupSize - 1, 0) or 0 end
GetGuildInfo = function() end
GetAddOnMetadata = function(_, key) return key == 'Version' and '1.5.0-wotlk.1' or 'Social Diary' end
-- GetCurrentMapAreaID returns DBC ID + 1; SetMapByID takes the DBC ID.
-- Original FrameXML WorldMapFrame_ToggleWindowSize explicitly subtracts one.
local selectedMap, selectedFloor = 5, 2
local currentMap, playerX, playerY = 25, 0.4, 0.5
local folders = { [5] = 'Durotar', [25] = 'Hilsbrad', [16] = 'Alterac' }
local mapChanges = 0
GetCurrentMapAreaID = function() return selectedMap end
GetCurrentMapDungeonLevel = function() return selectedFloor end
GetCurrentMapContinent = function() return selectedMap == 5 and 2 or 1 end
GetCurrentMapZone = function() return selectedMap == 25 and 2 or 1 end
GetMapZones = function(continent)
    if continent == 2 then return 'Durotar' end
    return 'Alterac Mountains', 'Hillsbrad Foothills'
end
SetMapToCurrentZone = function() mapChanges = mapChanges + 1; selectedMap, selectedFloor = currentMap, 0 end
SetMapByID = function(id) mapChanges = mapChanges + 1; selectedMap, selectedFloor = id + 1, 0 end
SetDungeonMapLevel = function(floor) selectedFloor = floor end
GetPlayerMapPosition = function()
    if selectedMap == currentMap then return playerX, playerY end
    return 0, 0
end
GetMapInfo = function() return folders[selectedMap] end
GetMapOverlayInfo = function(index)
    if selectedMap == 25 and index == 1 then
        return 'Interface\\WorldMap\\Hilsbrad\\DARROWHILL', 205, 155, 414, 154
    end
end
UnitPosition = nil
WorldMapFrame = CreateFrame('Frame', 'WorldMapFrame', UIParent)
GetAuctionItemClasses = function() return 'Weapon', 'Armor', 'Container' end
GetAuctionItemSubClasses = function() return 'Miscellaneous' end
GetContainerNumSlots = function() return 16 end
GetContainerItemInfo = function() end
GetItemIcon = function() return 'Interface\\Icons\\INV_Misc_Book_09' end
InterfaceOptions_AddCategory = function() end
EasyMenu = function() end
local rewardHook
hooksecurefunc = function(name, fn) if name == 'GetQuestReward' then rewardHook = fn end end
GetQuestID = nil -- This API does not exist in the original client.
local questTitle = 'A quiet errand'
local questLog = {
    { title = 'The valley', header = true },
    { title = 'Another errand', id = 456 },
    { title = 'A quiet errand', id = 123, daily = 1 },
}
GetTitleText = function() return questTitle end
GetNumQuestLogEntries = function() return #questLog, #questLog - 1 end
GetQuestLogTitle = function(index)
    local q = questLog[index]
    if q then return q.title, 20, nil, 0, q.header, false, 1, q.daily end
end
GetQuestLink = function(index)
    local q = questLog[index]
    if q and q.id then return '|cffffff00|Hquest:' .. q.id .. ':20|h[' .. q.title .. ']|h|r' end
end
GetQuestLogSelection = function() return 2 end -- Deliberately not the turned-in quest.
-- Old mock doesn't normally model HookScript on GameTooltip.
GameTooltip = CreateFrame('GameTooltip', 'GameTooltip', UIParent)
GameTooltip.HookScript = function() end
IsResting = function() return 1 end
IsInInstance = function() return nil, 'none' end
Minimap = CreateFrame('Frame', 'Minimap', UIParent)
Minimap.GetWidth = function() return 140 end
Minimap.GetHeight = function() return 140 end
Minimap.GetEffectiveScale = function() return 1 end
Minimap.GetCenter = function() return 100, 100 end
GetCursorPosition = function() return 200, 100 end
local ns = mock.LoadAddon('.')
local E = assert(SocialDiaryLegacyEnv)
local cropped = E.CreateFrame('Frame'):CreateTexture()
cropped:SetTexCoord(0.2, 0.8, 0.1, 0.9)
cropped:SetRotation(0)
local nativeUV = cropped.recorded.calls.SetTexCoord
assert(nativeUV.n == 4 and nativeUV[1] == 0.2 and nativeUV[2] == 0.8
    and nativeUV[3] == 0.1 and nativeUV[4] == 0.9, 'native zero rotation corrupts map texture crop')
local coldTextures = E.C_Map.GetMapArtLayerTextures(25, 1)
assert(coldTextures and coldTextures[1] == 'Interface\\WorldMap\\Hilsbrad\\Hilsbrad1', 'historical map lookup must convert native read ID to setter ID')
assert(selectedMap == 5 and selectedFloor == 2, 'cold map lookup changed selected map or floor')
assert(E.C_QuestLog.GetTitleForQuestID(123) == 'A quiet errand', 'quest title lookup must use normalized legacy log fields')
assert(E.IsResting() == true and E.IsInInstance() == false, 'old boolean values normalized')
assert(_G.C_Timer == nil and E.C_Timer, 'compat API must stay addon-local')
assert(ns.SafeGUID('0x00000000000000A1'))
assert(not ns.SafeGUID('0xF13000B19D0000DA'))
assert(ns.NpcID('0xF13000B19D0000DA') == 45469)
local own = { guid = '0x00000000000000A1', first = 'Harald', level = 28, class = 'WARRIOR', race = 'Human', sex = 2, faction = 'Alliance' }
local other = { guid = '0x00000000000000B2', first = 'Ingvar', level = 27, class = 'MAGE', race = 'Human', sex = 2, faction = 'Alliance' }
mock.SetUnit('player', own)
mock.SetUnit('target', other)
mock.SetUnit('party1', other)
mock.groupSize = 2
mock.fire('ADDON_LOADED', 'social_diary')
ns.db.settings.frontRead = true
mock.fire('PLAYER_LOGIN')
mock.fire('PLAYER_ENTERING_WORLD')
assert(SocialDiaryMinimapButton and SocialDiaryMinimapButton:IsShown(), 'old-client minimap button loaded')
SocialDiaryMinimapButton:GetScript('OnDragStart')(SocialDiaryMinimapButton)
SocialDiaryMinimapButton:GetScript('OnDragStop')(SocialDiaryMinimapButton)
assert(ns.Setting('minimapAngle') == 0, 'old-client minimap drag saved')
assert(not SocialDiaryMinimapButton:GetScript('OnUpdate'), 'old-client minimap drag stopped')
assert(ns.ownGUID == own.guid, 'own old-format GUID')
local function Near(a, b) return type(a) == 'number' and math.abs(a - b) < 0.001 end
assert(E.C_Map.GetBestMapForUnit('player') == 25, 'runtime map ID must not be replaced with DBC row ID')
assert(selectedMap == 5 and selectedFloor == 2, 'map snapshot changed the selected map or floor')
assert(E.C_Map.GetMapInfo(25).name == 'Hillsbrad Foothills', 'map label uses native localized zone name')
local width, height = E.C_Map.GetMapWorldSize(25)
assert(Near(width, 3200) and Near(height, 2133.333252), 'map physical dimensions')
local nativeLayer = E.C_Map.GetMapArtLayers(25)[1]
assert(nativeLayer.legacyMap and nativeLayer.layerWidth == 1002 and #nativeLayer.legacyOverlays > 0, 'native map art and reveal metadata missing')
local textures = E.C_Map.GetMapArtLayerTextures(25, 1)
assert(#textures == 12 and textures[1] == 'Interface\\WorldMap\\Hilsbrad\\Hilsbrad1', 'native texture paths')
local explored = E.C_MapExplorationInfo.GetExploredMapTextures(25)
assert(#explored == 1 and explored[1].fileDataIDs[1] == 'Interface\\WorldMap\\Hilsbrad\\DARROWHILL1', 'native explored overlay paths')
assert(selectedMap == 5 and selectedFloor == 2, 'overlay read changed selected map/floor')
local north, east, _, instance = E.UnitPosition('player')
assert(Near(north, -666.666626) and Near(east, -213.3333252) and instance == 0, 'derived native world position')
assert(_G.UnitPosition == nil, 'world-position adapter must not change other addons')
local worldID, world = E.C_Map.GetWorldPosFromMapPos(25, E.CreateVector2D(0.4, 0.5))
local _, projected = E.C_Map.GetMapPosFromWorldPos(worldID, world, 25)
local px, py = projected:GetXY()
assert(Near(px, 0.4) and Near(py, 0.5), 'zone/world projection round trip')
assert(not E.C_Map.GetMapPosFromWorldPos(1, world, 25), 'cross-instance projection invented coordinates')
local sample = ns.JourneyCapture.Sample(mock.now)
assert(sample and sample.mapID == 25 and Near(sample.wx, east) and Near(sample.wy, north), 'route capture requires derived world coordinates')
local beforeChanges = mapChanges
WorldMapFrame:Show()
assert(not E.C_Map.GetBestMapForUnit('player'), 'open world map must pause position capture')
assert(#E.C_MapExplorationInfo.GetExploredMapTextures(25) == 0, 'open world map should not switch to another zone')
assert(mapChanges == beforeChanges and selectedMap == 5 and selectedFloor == 2, 'open world map selection changed')
WorldMapFrame:Hide()
local nativeOverlay = GetMapOverlayInfo
GetMapOverlayInfo = function() error('native overlay read failed') end
assert(not pcall(E.C_MapExplorationInfo.GetExploredMapTextures, 25), 'native map read failure was swallowed')
assert(selectedMap == 5 and selectedFloor == 2, 'failed map read did not restore selection')
GetMapOverlayInfo = nativeOverlay
assert(#E.C_MapExplorationInfo.GetExploredMapTextures(25) == 1, 'failed map read left adapter locked')
local handle = E.C_Timer.NewTicker(1, function() end)
assert(not handle:IsCancelled()); handle:Cancel(); assert(handle:IsCancelled())
local calls = 0
E.C_Timer.After(1, function() calls = calls + 1 end)
realTime = realTime + 4
for _, frame in ipairs(mock.frames) do
    if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 4) end
end
assert(calls == 1, 'timer fires after delay')
assert(ns.Roster.Has(other.guid), 'legacy entering-world settles group scan')
assert(ns.Characters.Get(other.guid), 'party player observed')
local quests = 0
ns.On('QUEST_TURNED_IN', function(_, id) assert(id == 123); quests = quests + 1 end)
mock.fire('QUEST_COMPLETE'); rewardHook(); rewardHook()
assert(quests == 1, 'quest reward captured once, without GetQuestID or relying on log selection')
mock.fire('QUEST_COMPLETE'); mock.fire('QUEST_FINISHED'); rewardHook()
assert(quests == 1, 'closed reward window kept a stale quest')
questTitle = 'Not in the log'
mock.fire('QUEST_COMPLETE'); rewardHook()
assert(quests == 1, 'unmatched title recorded the selected quest')
questTitle = 'A quiet errand'
questLog[#questLog + 1] = { title = questTitle, id = 789 }
mock.fire('QUEST_COMPLETE'); rewardHook()
assert(quests == 1, 'ambiguous title recorded an arbitrary quest')
table.remove(questLog)
mock.fire('QUEST_COMPLETE'); rewardHook()
assert(quests == 2, 'valid reward was not recorded after ambiguous title')
mock.SetUnit('party1', nil); mock.groupSize = 0
mock.fire('PARTY_MEMBERS_CHANGED')
assert(not ns.Roster.Has(other.guid), 'legacy party leave')
local kills = 0
ns.On('PARTY_KILL', function(_, src, dst) assert(src == own.guid and dst == other.guid); kills = kills + 1 end)
mock.fire('COMBAT_LOG_EVENT_UNFILTERED', mock.now, 'PARTY_KILL', own.guid, 'Harald', 0, other.guid, 'Ingvar', 0)
assert(kills == 1, 'old combat-log payload')
SlashCmdList.SOCIALDIARY("")
ns.UI.ShowSettings('recording')
local settings = ns.UI.SettingsPage()
settings.chatLines.box:SetFocus()
ns.SetSetting('storeChat', false)
ns.UI.RefreshSettingsPage()
assert(not settings.chatLines.box:HasFocus(), 'disabled legacy field keeps keyboard focus')
assert(settings.chatLines.box.recorded.calls.EnableMouse[1] == false, 'disabled legacy field accepts mouse')
assert(settings.chatLines.box.recorded.calls.EnableKeyboard[1] == false, 'disabled legacy field accepts keyboard')
ns.SetSetting('storeChat', true)
ns.UI.RefreshSettingsPage()
assert(settings.chatLines.box.recorded.calls.EnableMouse[1] == true, 'enabled legacy field rejects mouse')
assert(settings.chatLines.box.recorded.calls.EnableKeyboard[1] == true, 'enabled legacy field rejects keyboard')
for _, section in ipairs({ 'interface', 'toasts', 'shortcuts', 'sounds', 'integrations', 'memory', 'about' }) do
    ns.UI.ShowSettings(section)
end
print('PASS: 3.3.5 boot, GUIDs, scoped APIs, timers, groups, quest reward, combat log and journal')
