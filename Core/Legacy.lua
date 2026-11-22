-- Private compatibility environment for the original 3.3.5 client.
-- Never replace Blizzard APIs for other addons.
if select(4, GetBuildInfo()) ~= 30300 then return end
local E = setmetatable({}, { __index = _G, __newindex = _G })
SocialDiaryLegacyEnv = E
local function API(k, v) rawset(E, k, v) end
API('GetServerTime', time)
API('UnitFullName', UnitName)
API('GetNormalizedRealmName', function() return (GetRealmName():gsub('%s+', '')) end)
API('IsInRaid', function() return GetNumRaidMembers() > 0 end)
API('IsInGroup', function() return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 end)
API('GetNumGroupMembers', function()
    local n = GetNumRaidMembers()
    return n > 0 and n or (GetNumPartyMembers() > 0 and GetNumPartyMembers() + 1 or 0)
end)
API('UnitIsInMyGuild', function(unit)
    local mine, theirs = GetGuildInfo('player'), GetGuildInfo(unit)
    return mine ~= nil and theirs == mine
end)
-- Normalize old 1/nil flag returns to modern boolean values.
for _, name in ipairs({ 'UnitIsDeadOrGhost', 'UnitIsGhost', 'UnitIsDead', 'IsResting',
    'IsFlying', 'IsSwimming', 'IsMounted', 'IsFalling', 'UnitOnTaxi', 'UnitCanAttack',
    'UnitIsVisible', 'UnitIsFeignDeath', 'IsOutdoors', 'IsIndoors', 'IsStealthed',
    'UnitAffectingCombat', 'UnitIsPlayer' }) do
    local native = _G[name]
    if native then API(name, function(...) local v = native(...); return v ~= nil and v ~= false and v ~= 0 end) end
end
local nativeInstance = IsInInstance
API('IsInInstance', function(...)
    local v, kind = nativeInstance(...)
    return v ~= nil and v ~= false and v ~= 0, kind
end)
API('C_AddOns', { GetAddOnMetadata = GetAddOnMetadata, IsAddOnLoaded = IsAddOnLoaded })
API('C_CVar', { GetCVar = GetCVar })
-- Timers are driven by one frame, including delayed roster settlement.
local timers, clock = {}, CreateFrame('Frame')
local function Timer(seconds, fn, repeating)
    local t = { at = GetTime() + seconds, fn = fn, interval = repeating and seconds }
    function t:Cancel() self.cancelled = true end
    function t:IsCancelled() return self.cancelled == true end
    timers[#timers + 1] = t
    clock:Show()
    return t
end
clock:SetScript('OnUpdate', function()
    local now = GetTime()
    for i = #timers, 1, -1 do
        local t = timers[i]
        if t.cancelled then table.remove(timers, i)
        elseif now >= t.at then
            if t.interval then t.at = now + t.interval else table.remove(timers, i) end
            local ok, err = pcall(t.fn, t)
            if not ok then geterrorhandler()(err) end
        end
    end
    if #timers == 0 then clock:Hide() end
end)
clock:Hide()
API('C_Timer', {
    After = function(s, fn) Timer(s, fn) end,
    NewTimer = function(s, fn) return Timer(s, fn) end,
    NewTicker = function(s, fn) return Timer(math.max(s, 0.01), fn, true) end,
})
local function ItemID(item)
    return type(item) == 'number' and item or tonumber(tostring(item):match('item:(%d+)'))
end
local function ItemInfo(item)
    local name, link, quality, level, minlevel, class, subclass, stack, equip, icon = GetItemInfo(item)
    local classID, subclassID
    -- Auction category indices are not item class IDs.
    if equip == 'INVTYPE_BAG' then
        classID = 1
        if GetItemFamily and GetItemFamily(item) == 0 then subclassID = 0 end
    end
    return ItemID(item) or ItemID(link), class, subclass, equip, icon, classID, subclassID
end
API('C_Item', {
    GetItemInfoInstant = ItemInfo, GetItemInfo = GetItemInfo,
    GetItemIconByID = function(id) return GetItemIcon(id) end,
    GetItemQualityByID = function(id) return select(3, GetItemInfo(id)) end,
})
API('C_Container', {
    GetContainerNumSlots = GetContainerNumSlots,
    ContainerIDToInventoryID = ContainerIDToInventoryID,
    GetContainerItemInfo = function(bag, slot)
        local icon, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
        if not icon then return nil end
        return { iconFileID = icon, stackCount = count, isLocked = locked,
            quality = quality, isReadable = readable, hasLoot = lootable, hyperlink = link }
    end,
})
-- Legacy area IDs are kept as native IDs. Never mix retail map ID tables.
local maps = {}
local function OnMap(fn)
    if WorldMapFrame and WorldMapFrame:IsShown() then return nil end
    local old, floor = GetCurrentMapAreaID(), GetCurrentMapDungeonLevel()
    SetMapToCurrentZone()
    local result = { fn() }
    if old and old > 0 then SetMapByID(old); if floor and floor > 0 then SetDungeonMapLevel(floor) end end
    return unpack(result)
end
local Map = {}
function Map.GetBestMapForUnit(unit)
    if unit ~= 'player' then return nil end
    return OnMap(function()
        local id = GetCurrentMapAreaID()
        if not id or id <= 0 then return nil end
        maps[id] = maps[id] or { mapID = id, name = GetRealZoneText(), mapType = 3, parentMapID = 0 }
        return id
    end)
end
function Map.GetMapInfo(id) return maps[id] end
function Map.GetPlayerMapPosition(id, unit)
    return OnMap(function()
        if GetCurrentMapAreaID() ~= id then return nil end
        local x, y = GetPlayerMapPosition(unit)
        if not x or (x == 0 and y == 0) then return nil end
        return { GetXY = function() return x, y end }
    end)
end
API('C_Map', Map)
-- No nameplate unit tokens, retail atlas textures, damage meter or death
-- recap exist in this client. Capability guards leave those features absent.
API('C_Texture', {})
-- The original log puts group size before the header flag and exposes the
-- quest ID through its hyperlink. Normalize the private log reader to the
-- shape expected by the addon's fallback readers; a daily flag is not an ID.
local nativeQuestLogTitle = GetQuestLogTitle
API('GetQuestLogTitle', function(index)
    local title, level, tag, _, header, collapsed, complete, daily = nativeQuestLogTitle(index)
    local link = not header and GetQuestLink(index)
    local id = type(link) == 'string' and tonumber(link:match('quest:(%d+)')) or nil
    return title, level, tag, header, collapsed, complete, daily, id
end)
local Q = {}
function Q.GetTitleForQuestID(id)
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, header, _, _, _, qid = E.GetQuestLogTitle(i)
        if not header and qid == id then return title end
    end
end
API('C_QuestLog', Q)
