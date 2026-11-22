-- Standalone checks for the old-client adapter; lua tests/legacy_ui.lua.
local unpack = table.unpack or unpack
local function NativeRegion()
    local r = { shown = false, width = 80, height = 10, text = "", spacing = 2 }
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetWidth(w) self.width = w end
    function r:GetWidth() return self.width end
    function r:SetHeight(h) self.height = h end
    function r:GetFont() return "font", 12 end
    function r:GetSpacing() return self.spacing end
    function r:GetStringWidth() return self.width == 0 and 120 or 80 end
    function r:SetTexture(...) self.texture = { ... } end
    function r:SetGradientAlpha(...) self.gradient = { ... } end
    function r:SetTexCoord(...) self.coords = { ... } end
    return r
end
local made = {}
local function NativeFrame(kind, name, parent, template)
    assert(template ~= "BackdropTemplate", "old client has no BackdropTemplate")
    local f = NativeRegion()
    f.kind, f.name, f.template = kind, name, template
    function f:CreateTexture() return NativeRegion() end
    function f:CreateFontString() return NativeRegion() end
    function f:HasScript(script) return script ~= "OnHyperlinkClick" end
    function f:SetScript(script, handler) assert(self:HasScript(script)) self[script] = handler end
    if kind == "EditBox" then
        f.focused, f.mouseEnabled, f.keyboardEnabled = true, true, true
        function f:ClearFocus() self.focused = false end
        function f:EnableMouse(enabled) self.mouseEnabled = enabled end
        function f:EnableKeyboard(enabled) self.keyboardEnabled = enabled end
    end
    if template == "NativeEditBox" then
        f.Enable = function(self) self.nativeEnabled = true end
        f.Disable = function(self) self.nativeEnabled = false end
        f.nativeEnable, f.nativeDisable = f.Enable, f.Disable
    end
    made[#made + 1] = f
    return f
end
local captured
local env = setmetatable({ CreateFrame = NativeFrame, unpack = unpack,
    EasyMenu = function(entries) captured = entries end,
}, { __index = _G })
env.SocialDiaryLegacyEnv = env
local globals = env
local chunk
if _VERSION == "Lua 5.1" then
    chunk = assert(loadfile("Core/LegacyUI.lua"))
    setfenv(chunk, globals)
else chunk = assert(loadfile("Core/LegacyUI.lua", "t", globals)) end
chunk()
local f = env.CreateFrame("Frame", nil, nil, "BackdropTemplate")
assert(f.template == nil)
f:SetShown(true) assert(f.shown)
f:SetShown(false) assert(not f.shown)
f:SetSize(40, 25) assert(f.width == 40 and f.height == 25)
f:SetScript("OnHyperlinkClick", function() end)
assert(not f.OnHyperlinkClick)
local native = NativeFrame("Frame")
assert(not native.SetShown and not native.SetColorTexture, "native objects must not change")
local edit = env.CreateFrame("EditBox")
edit:Disable()
assert(not edit.focused, "disabling a field must release keyboard focus")
assert(not edit.mouseEnabled and not edit.keyboardEnabled, "disabled fields must reject mouse and keyboard input")
edit:Enable()
assert(edit.mouseEnabled and edit.keyboardEnabled, "enabling a field must restore mouse and keyboard input")
assert(not edit.focused, "enabling a field must not steal focus")
local nativeEdit = NativeFrame("EditBox")
assert(not nativeEdit.Enable and not nativeEdit.Disable, "unwrapped edit boxes must remain unchanged")
assert(not f.Enable and not f.Disable, "the input adapter must apply only to edit boxes")
local modernEdit = env.CreateFrame("EditBox", nil, nil, "NativeEditBox")
assert(modernEdit.Enable == modernEdit.nativeEnable and modernEdit.Disable == modernEdit.nativeDisable,
    "existing native enable and disable methods must be preserved")
modernEdit:Disable() assert(modernEdit.nativeEnabled == false)
modernEdit:Enable() assert(modernEdit.nativeEnabled == true)
local t = f:CreateTexture()
t:SetColorTexture(0.1, 0.2, 0.3, 0.4)
assert(t.texture[4] == 0.4)
t:SetGradient("VERTICAL", env.CreateColor(1, 0, 0, 0.2), env.CreateColor(0, 1, 0, 0.7))
assert(t.gradient[1] == "VERTICAL" and t.gradient[5] == 0.2 and t.gradient[9] == 0.7)
t:SetTexCoord(0.2, 0.8, 0.1, 0.9)
t:SetRotation(math.pi / 4)
local rotated = t.coords[1]
t:SetRotation(math.pi / 4)
assert(t.coords[1] == rotated, "rotation must not compound")
t:SetRotation(0)
assert(t.coords[1] == 0.2 and t.coords[8] == 0.9)
local text = f:CreateFontString()
assert(text:GetUnboundedStringWidth() == 120 and text.width == 80)
text:SetMaxLines(3) assert(text.height == 42)
f:SetPropagateKeyboardInput(false)
assert(not pcall(f.SetPropagateKeyboardInput, f, true))
local picked
local rootOwner = {}
env.MenuUtil.CreateContextMenu(rootOwner, function(owner, root)
    assert(owner == rootOwner)
    root:CreateTitle("Filter")
    root:CreateButton("Clear", function() picked = "clear" end)
    local sub = root:CreateButton("Faction")
    sub:CreateRadio("Any", function() return true end, function() picked = "any" end)
end)
assert(captured[1].isTitle)
assert(captured[2].menuList == nil)
captured[2].func() assert(picked == "clear")
assert(captured[3].hasArrow and captured[3].menuList[1].checked)
captured[3].menuList[1].func() assert(picked == "any")
print("legacy_ui: scoped rendering, clipping, sizing and nested menus passed")
