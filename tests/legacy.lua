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
GetCurrentMapAreaID = function() return 14 end
GetCurrentMapDungeonLevel = function() return 0 end
SetMapToCurrentZone = function() end
SetMapByID = function() end
SetDungeonMapLevel = function() end
GetPlayerMapPosition = function() return 0.4, 0.5 end
GetMapInfo = function() return 'Durotar' end
GetAuctionItemClasses = function() return 'Weapon', 'Armor', 'Container' end
GetAuctionItemSubClasses = function() return 'Miscellaneous' end
GetContainerNumSlots = function() return 16 end
GetContainerItemInfo = function() end
GetItemIcon = function() return 'Interface\\Icons\\INV_Misc_Book_09' end
InterfaceOptions_AddCategory = function() end
EasyMenu = function() end
local rewardHook
hooksecurefunc = function(name, fn) if name == 'GetQuestReward' then rewardHook = fn end end
GetQuestID = function() return 123 end
-- Old mock doesn't normally model HookScript on GameTooltip.
GameTooltip = CreateFrame('GameTooltip', 'GameTooltip', UIParent)
GameTooltip.HookScript = function() end
IsResting = function() return 1 end
IsInInstance = function() return nil, 'none' end
local ns = mock.LoadAddon('.')
local E = assert(SocialDiaryLegacyEnv)
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
assert(ns.ownGUID == own.guid, 'own old-format GUID')
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
assert(quests == 1, 'quest reward captured once')
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
