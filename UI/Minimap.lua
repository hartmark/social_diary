if SocialDiaryLegacyEnv then setfenv(1, SocialDiaryLegacyEnv) end
-- A book on the minimap's edge. Its position belongs to this character;
-- cursor polling runs only while the player is dragging the button.
local addonName, ns = ...

local DEFAULT_ANGLE = 220
local button, angle, dragging

-- Quadrants: bottom right, bottom left, top right, top left.
local SHAPES = {
    ROUND = { true, true, true, true },
    SQUARE = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
}

local function Place()
    local radians = math.rad(angle)
    local x, y = math.cos(radians), math.sin(radians)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quarters = SHAPES[shape] or SHAPES.ROUND
    local quadrant = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
    if not quarters[quadrant] then
        local edge = math.max(math.abs(x), math.abs(y))
        x, y = x / edge, y / edge
    end
    local rx = math.max(Minimap:GetWidth() / 2, 1) + 5
    local ry = math.max(Minimap:GetHeight() / 2, 1) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * rx, y * ry)
end

local function Drag()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    if not cx or not cy or not scale or scale <= 0 then return end
    local x, y = GetCursorPosition()
    x, y = x / scale - cx, y / scale - cy
    if x == 0 and y == 0 then return end
    angle = math.deg(math.atan2(y, x)) % 360
    Place()
end

local function StopDragging()
    if not dragging then return end
    dragging = false
    button:SetScript("OnUpdate", nil)
    ns.SetSetting("minimapAngle", angle)
end

local function Build()
    if button or not Minimap then return end
    angle = ns.Setting("minimapAngle")
    if type(angle) ~= "number" or angle ~= angle or math.abs(angle) == math.huge then
        angle = DEFAULT_ANGLE
    end
    angle = angle % 360

    button = CreateFrame("Button", "SocialDiaryMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local ground = button:CreateTexture(nil, "BACKGROUND")
    ground:SetSize(24, 24)
    ground:SetPoint("CENTER")
    ground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    ns.Style.Tooltip(button, {
        { "Social Diary" },
        { "Left-click to open your journal.", 1, 1, 1 },
        { "Right-click to open settings.", 1, 1, 1 },
        { "Drag to move the button.", 0.7, 0.7, 0.7 },
    })
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then ns.UI.ShowSettings()
        elseif mouseButton == "LeftButton" then ns.UI.ToggleJournal() end
    end)
    button:SetScript("OnDragStart", function()
        dragging = true
        GameTooltip:Hide()
        button:SetScript("OnUpdate", Drag)
        Drag()
    end)
    button:SetScript("OnDragStop", StopDragging)
    button:SetScript("OnHide", StopDragging)
    button:SetScript("OnShow", Place)
    Minimap:HookScript("OnSizeChanged", Place)
    Place()
    button:Show()
end

ns.On("PLAYER_LOGIN", Build)
