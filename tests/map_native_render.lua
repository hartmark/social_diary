-- A native Wrath texture can rotate, but SetRotation destroys its UV crop.
-- Exercise the real mesh and map printer rather than a fake Bend callback.
local T = ...
local Check, Eq, Section = T.Check, T.Eq, T.Section
local ns = T.Boot()
local nativeCreateFrame = CreateFrame
local nativeCalls = 0
local function OldRegion(region)
    local oldMeta = getmetatable(region)
    region.HasScript = function() return true end
    region.SetGradientAlpha = function() end
    local missing = { SetVertexOffset = true, SetSnapToPixelGrid = true, SetTexelSnappingBias = true }
    if region.frameType == "FontString" then
        missing.SetRotation = true
    elseif region.frameType == "Texture" then
        region.SetRotation = function(self)
            nativeCalls = nativeCalls + 1
            self:SetTexCoord(-0.2071068, -0.2071068, -0.2071068, 1.2071068,
                1.2071068, -0.2071068, 1.2071068, 1.2071068)
        end
    end
    for key in pairs(missing) do region[key] = nil end
    setmetatable(region, { __index = function(self, key)
        if missing[key] then return nil end
        return oldMeta and oldMeta.__index(self, key)
    end })
    if region.CreateTexture then
        local create = region.CreateTexture
        region.CreateTexture = function(self, ...) return OldRegion(create(self, ...)) end
    end
    if region.CreateFontString then
        local create = region.CreateFontString
        region.CreateFontString = function(self, ...) return OldRegion(create(self, ...)) end
    end
    return region
end
local env = setmetatable({ CreateFrame = function(...) return OldRegion(nativeCreateFrame(...)) end }, { __index = _G })
env.SocialDiaryLegacyEnv = env
local chunk = assert(loadfile("Core/LegacyUI.lua"))
setfenv(chunk, env)
chunk()
CreateFrame = env.CreateFrame

Section("native map facets retain their UV crop through the real sheet toolkit")
local view, K = ns.UI.LooseSheet(UIParent, 400, 300, { glued = true,
    crease = { columns = { 0, 0.5, 1 }, rows = { 0, 0.5, 1 },
        folds = { columns = {}, rows = {} }, wander = 0, shift = 0 } })
K.Mount(0, 0, 400, 300, 0.04)
K.Fall("map-uv-regression", 0.04)
K.Lay()
Check(not view.turnsText, "fixture font strings unexpectedly rotate")
Check(not view.canBend, "fixture native textures unexpectedly move vertices")
local x, y = K.Screen(0, 0)
Eq(x, -200, "native sheet rotated geometry while its text could not turn")
Eq(y, 150, "native sheet rotated geometry while its text could not turn")
local path = "Interface\\WorldMap\\Hilsbrad\\Hilsbrad1"
local tilePool = K.Pool("BORDER", 1)
local overlayPool = K.Pool("BORDER", 2)
tilePool:Begin(); overlayPool:Begin()
local tiles = ns.UI.MapArt.Print({ layerWidth = 1002, layerHeight = 668 },
    { { file = path, x = 0, y = 0, w = 256, h = 256, fw = 256, fh = 256 } },
    { 100, 50, 220, 140 }, 0, 0, 400, { 1, 1, 1 }, K, tilePool, overlayPool)
tilePool:Finish(); overlayPool:Finish()
Eq(tiles, 1, "cropped native base tile was not printed")
local facets = 0
for _, texture in ipairs(T.mock.frames) do
    local rec = texture.recorded
    local file = rec and rec.calls.SetTexture
    if file and file[1] == path and texture:IsShown() then
        facets = facets + 1
        local uv = rec.calls.SetTexCoord
        Eq(uv.n, 4, "a zero-turn native map facet lost its rectangular UV arguments")
        Check(uv[1] >= 100 / 256 - 1e-9 and uv[2] <= 220 / 256 + 1e-9 and uv[2] > uv[1],
            "a native map facet sampled outside its horizontal crop")
        Check(uv[3] >= 50 / 256 - 1e-9 and uv[4] <= 140 / 256 + 1e-9 and uv[4] > uv[3],
            "a native map facet sampled outside its vertical crop")
        Check(texture.width > 0 and rec.height > 0, "a native map facet has no physical area")
    end
end
Check(facets > 1, "the real sheet mesh did not split the map into facets")
Eq(nativeCalls, 0, "native SetRotation replaced the map crop")
CreateFrame = nativeCreateFrame
