-- A native minimap button, independent of any external broker libraries.
local T = ...
local mock, Check, Eq, Section = T.mock, T.Check, T.Eq, T.Section
local oldCursor, oldShape = GetCursorPosition, GetMinimapShape
local cursorX, cursorY, shape = 0, 0, "ROUND"
GetCursorPosition = function() return cursorX, cursorY end
GetMinimapShape = function() return shape end
Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap:SetSize(140, 140)
Minimap.GetHeight = function() return 140 end
Minimap.GetCenter = function() return 100, 100 end
Minimap.GetEffectiveScale = function() return 2 end

local ns = T.Boot()
local button = SocialDiaryMinimapButton

Section("the minimap button opens the book and settings")
Check(button and button:IsShown(), "no visible minimap button")
Eq(button:GetScript("OnUpdate"), nil, "idle minimap button polls the cursor")
Eq(button.parent, Minimap, "the minimap is not the button's parent")
local toggled, settings = 0, 0
local oldToggle, oldSettings = ns.UI.ToggleJournal, ns.UI.ShowSettings
ns.UI.ToggleJournal = function() toggled = toggled + 1 end
ns.UI.ShowSettings = function() settings = settings + 1 end
local click = button:GetScript("OnClick")
click(button, "LeftButton")
Eq(toggled, 1, "left click does not toggle the journal")
Eq(settings, 0, "left click opens settings")
click(button, "RightButton")
Eq(settings, 1, "right click does not open settings")
Eq(toggled, 1, "right click toggles the journal")
local frames = #mock.frames
mock.fire("PLAYER_LOGIN")
Eq(SocialDiaryMinimapButton, button, "another login replaces the button")
Eq(#mock.frames, frames, "another login creates frames")

local function Position()
    local point = button.recorded.points[1]
    return point.args[3], point.args[4]
end
local function Near(value, expected, label)
    Check(math.abs(value - expected) < 0.001, label)
end

Section("dragging follows the scaled cursor and saves this character's angle")
-- The minimap centre is (100,100) at effective scale 2.
cursorX, cursorY = 400, 200
button:GetScript("OnDragStart")(button)
Check(button:GetScript("OnUpdate"), "dragging has no cursor update")
local x, y = Position()
Near(x, 75, "right edge x")
Near(y, 0, "right edge y")
cursorX, cursorY = 200, 400
button:GetScript("OnUpdate")(button, 0.01)
x, y = Position()
Near(x, 0, "top edge x")
Near(y, 75, "top edge y")
button:GetScript("OnDragStop")(button)
Eq(button:GetScript("OnUpdate"), nil, "cursor polling persists after drag")
Near(ns.Setting("minimapAngle"), 90, "drag angle was not saved")
Near(SocialDiaryCharDB.settings.minimapAngle, 90, "angle is not per character")

Section("square minimaps keep the button on their edge")
shape = "SQUARE"
cursorX, cursorY = 400, 400
button:GetScript("OnDragStart")(button)
x, y = Position()
Near(x, 75, "square upper right x")
Near(y, 75, "square upper right y")
button:Hide()
Eq(button:GetScript("OnUpdate"), nil, "hiding a dragged button leaves cursor polling")
Near(ns.Setting("minimapAngle"), 45, "hiding does not save the final angle")
button:Show()

Section("saved angles are used when the addon is loaded again")
-- Re-evaluate just this module with the current saved settings.
ns.UI.ToggleJournal, ns.UI.ShowSettings = oldToggle, oldSettings
local root = (arg[0]:match("^(.*)/tests/run.lua$") or ".")
local chunk = assert(loadfile(root .. "/UI/Minimap.lua"))
chunk("social_diary", ns)
mock.fire("PLAYER_LOGIN")
button = SocialDiaryMinimapButton
x, y = Position()
Near(x, 75, "saved square angle x")
Near(y, 75, "saved square angle y")
Eq(button:GetScript("OnUpdate"), nil, "reloaded button polls while idle")

GetCursorPosition, GetMinimapShape = oldCursor, oldShape
