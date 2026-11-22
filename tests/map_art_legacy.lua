-- Original Wrath's map files are named paths, not retail file-data IDs.
local T = ...
local Check, Eq, Section = T.Check, T.Eq, T.Section
local ns = T.Boot()
local oldLayers, oldTextures = C_Map.GetMapArtLayers, C_Map.GetMapArtLayerTextures
local oldExplored = C_MapExplorationInfo.GetExploredMapTextures
local nativeLayer = { layerWidth = 1002, layerHeight = 668,
    tileWidth = 256, tileHeight = 256, legacyMap = true }
local paths = {}
for i = 1, 12 do paths[i] = "Interface\\WorldMap\\Hilsbrad\\Hilsbrad" .. i end
C_Map.GetMapArtLayers = function() return { nativeLayer } end
C_Map.GetMapArtLayerTextures = function() return paths end
C_MapExplorationInfo.GetExploredMapTextures = function()
    return { { textureWidth = 300, textureHeight = 200, offsetX = 700, offsetY = 400,
        fileDataIDs = { "Interface\\WorldMap\\Hilsbrad\\TestArea1", "Interface\\WorldMap\\Hilsbrad\\TestArea2" } } }
end

Section("legacy map tiles use native paths and physical map bounds")
-- 1412 deliberately shares the ID of a retail map with static reveal data.
-- The old-client marker must win even with the reveal setting enabled.
Check(ns.UI.MapOverlayData[1412] and #ns.UI.MapOverlayData[1412] > 0, "fixture has no colliding retail overlay data")
local layer, pieces, areas = ns.UI.MapArt.For(1412, true)
Eq(layer, nativeLayer, "legacy layer was replaced")
Eq(#pieces, 14, "twelve base files and two native overlay tiles")
Eq(areas, 1, "retail reveal data leaked into native map")
Eq(pieces[1].file, paths[1], "first native file path")
Eq(pieces[12].file, paths[12], "last native file path")
Eq(pieces[4].w, 234, "last column reaches past the map")
Eq(pieces[12].h, 156, "last row reaches past the map")
Eq(pieces[12].fw, 256, "base file width must remain 256")
Eq(pieces[12].fh, 256, "base file height must remain 256")
Eq(pieces[14].fw, 64, "partial overlay uses its power-of-two file width")

Section("legacy path textures are printed with clipped UV coordinates")
local printed = {}
local pool = { Next = function()
    local piece = {
        SetTexture = function(self, file) self.file = file end,
        SetTexCoord = function(self, ...) self.tc = { ... } end,
        SetVertexColor = function() end,
    }
    printed[#printed + 1] = piece
    return piece
end }
local K = {
    Split = function(x0, y0, x1, y1, fn) fn(x0, y0, x1, y1, 1) end,
    Bend = function(piece, x0, y0, x1, y1) piece.box = { x0, y0, x1, y1 } end,
}
local base, explored = ns.UI.MapArt.Print(layer, pieces, { 0, 0, 1002, 668 }, 0, 0, 1002,
    { 1, 1, 1 }, K, pool, pool)
Eq(base, 12, "all twelve native base tiles are printed")
Eq(explored, 2, "native explored overlay is printed")
local last = printed[12]
Eq(last.file, paths[12], "renderer did not pass native path to SetTexture")
Eq(last.box[3], 1002, "renderer draws beyond the map's right edge")
Eq(last.box[4], 668, "renderer draws beyond the map's bottom edge")
Check(math.abs(last.tc[2] - 234 / 256) < 1e-9, "last-column texture sampled past its map pixels")
Check(math.abs(last.tc[4] - 156 / 256) < 1e-9, "last-row texture sampled past its map pixels")
Check(math.abs(printed[14].tc[2] - 44 / 64) < 1e-9, "partial explored tile has wrong UV crop")

Section("revealing a legacy map adds its own unexplored areas exactly once")
nativeLayer.legacyOverlays = {
    { 300, 200, 700, 400, { "Interface\\WorldMap\\Hilsbrad\\TestArea1", "Interface\\WorldMap\\Hilsbrad\\TestArea2" } },
    { 100, 100, 20, 20, { "Interface\\WorldMap\\Hilsbrad\\UnseenArea1" } },
}
local _, allPieces, allAreas = ns.UI.MapArt.For(1412, true)
Eq(allAreas, 2, "native reveal did not merge explored and unexplored areas")
Eq(#allPieces, 15, "native reveal duplicated the already explored region")
Eq(allPieces[15].file, "Interface\\WorldMap\\Hilsbrad\\UnseenArea1", "native reveal used another map's overlay")
local _, knownPieces, knownAreas = ns.UI.MapArt.For(1412, false)
Eq(knownAreas, 1, "turning reveal off retains unseen regions")
Eq(#knownPieces, 14, "turning reveal off changes the explored region")
nativeLayer.legacyOverlays = nil

Section("legacy maps with no explored areas retain their base artwork")
C_MapExplorationInfo.GetExploredMapTextures = function() return {} end
local _, bare, count = ns.UI.MapArt.For(1412, false)
Eq(#bare, 12, "missing explored areas removed native base art")
Eq(count, 0, "empty native exploration invents overlays")
local _, revealed, revealCount = ns.UI.MapArt.For(1412, true)
Eq(#revealed, 12, "reveal setting added unrelated retail overlays")
Eq(revealCount, 0, "reveal setting invented explored areas")

C_Map.GetMapArtLayers, C_Map.GetMapArtLayerTextures = oldLayers, oldTextures
C_MapExplorationInfo.GetExploredMapTextures = oldExplored
