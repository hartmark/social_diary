-- WoW 3.3.5 rendering adapters, scoped to Social Diary's environment.
-- No Blizzard frame metatables or other addons' objects are modified.
local env = SocialDiaryLegacyEnv
if not env then return end
local nativeCreateFrame = env.CreateFrame

local function SetShown(self, shown)
    if shown then self:Show() else self:Hide() end
end
local function SetSize(self, w, h)
    self:SetWidth(w)
    self:SetHeight(h)
end
local function Region(region)
    if not region.SetShown then region.SetShown = SetShown end
    if not region.SetSize then region.SetSize = SetSize end
    return region
end
local function Texture(texture)
    Region(texture)
    if not texture.SetColorTexture then
        texture.SetColorTexture = function(self, r, g, b, a)
            self:SetTexture(r, g, b, a == nil and 1 or a)
        end
    end
    if texture.SetGradientAlpha then
        local gradient = texture.SetGradient
        texture.SetGradient = function(self, orientation, from, to, ...)
            if type(from) == "table" and type(to) == "table" then
                return self:SetGradientAlpha(orientation, from.r, from.g, from.b, from.a,
                    to.r, to.g, to.b, to.a)
            end
            if gradient then return gradient(self, orientation, from, to, ...) end
        end
    end
    -- Original Wrath's native SetRotation replaces a texture's UV crop,
    -- even at zero: the 23 Nov 2026 client probe expanded .2..8/.1..9 to
    -- roughly -.207..1.207. Map facets call SetRotation(0) after cropping,
    -- so invoking it stretches clamped edge pixels across the whole map.
    -- Own this operation for addon textures, including when a native method
    -- exists. Zero keeps the original four/eight arguments verbatim; icons
    -- that do turn use their crop's centre, never the full file's centre.
    local nativeCoord = texture.SetTexCoord
    local coords = { 0, 1, 0, 1 }
    local angle = 0
    local function Apply(self)
        if angle == 0 then return nativeCoord(self, unpack(coords)) end
        local corners = coords
        if #coords == 4 then
            corners = { coords[1], coords[3], coords[1], coords[4],
                coords[2], coords[3], coords[2], coords[4] }
        end
        local cx, cy = 0, 0
        for i = 1, 8, 2 do cx, cy = cx + corners[i] / 4, cy + corners[i + 1] / 4 end
        local c, s, out = math.cos(angle), math.sin(angle), {}
        for i = 1, 8, 2 do
            local x, y = corners[i] - cx, corners[i + 1] - cy
            out[i], out[i + 1] = cx + x * c - y * s, cy + x * s + y * c
        end
        return nativeCoord(self, unpack(out))
    end
    texture.SetTexCoord = function(self, ...)
        coords = { ... }
        return Apply(self)
    end
    texture.SetRotation = function(self, radians)
        angle = radians or 0
        return Apply(self)
    end
    return texture
end
local function FontString(text)
    Region(text)
    if not text.GetUnboundedStringWidth then
        text.GetUnboundedStringWidth = function(self)
            local width = self:GetWidth()
            self:SetWidth(0)
            local measured = self:GetStringWidth()
            self:SetWidth(width)
            return measured
        end
    end
    if not text.SetMaxLines then
        -- A fixed font-string height clips excess wrapped lines in 3.3.5.
        text.SetMaxLines = function(self, lines)
            local _, size = self:GetFont()
            self:SetHeight(lines and lines > 0 and lines * ((size or 13) + (self:GetSpacing() or 0)) or 0)
        end
    end
    return text
end
local function Frame(frame, kind)
    Region(frame)
    if kind == "EditBox" then
        -- Original Wrath edit boxes have no Enable/Disable methods. Release
        -- focus before blocking input, so a disabled number field cannot
        -- keep consuming keys or accept a click to focus it again.
        if not frame.Disable then
            frame.Disable = function(self)
                self:ClearFocus()
                self:EnableMouse(false)
                self:EnableKeyboard(false)
            end
        end
        if not frame.Enable then
            frame.Enable = function(self)
                self:EnableMouse(true)
                self:EnableKeyboard(true)
            end
        end
    end
    if frame.CreateTexture then
        local create = frame.CreateTexture
        frame.CreateTexture = function(self, ...) return Texture(create(self, ...)) end
    end
    if frame.CreateFontString then
        local create = frame.CreateFontString
        frame.CreateFontString = function(self, ...) return FontString(create(self, ...)) end
    end
    if frame.SetScript and frame.HasScript then
        local setScript = frame.SetScript
        frame.SetScript = function(self, script, handler)
            if self:HasScript(script) then setScript(self, script, handler) end
        end
    end
    -- Legacy sliders always follow their value step; legacy keyboard
    -- catchers already consume keys while EnableKeyboard(true) is in use.
    if not frame.SetObeyStepOnDrag then frame.SetObeyStepOnDrag = function() end end
    if not frame.SetPropagateKeyboardInput then
        frame.SetPropagateKeyboardInput = function(self, propagate)
            assert(not propagate, "3.3.5 cannot propagate keyboard input")
        end
    end
    return frame
end
rawset(env, "CreateFrame", function(kind, name, parent, template, ...)
    if template == "BackdropTemplate" then template = nil end
    return Frame(nativeCreateFrame(kind, name, parent, template, ...), kind)
end)

if not env.CreateColor then
    rawset(env, "CreateColor", function(r, g, b, a)
        return { r = r, g = g, b = b, a = a == nil and 1 or a }
    end)
end

-- Translate the small retail menu-description API used by the journal to
-- Blizzard's original dropdown menus, including nested filter facets.
if not env.MenuUtil then
    local menuFrame
    local function Node(entries)
        local node = {}
        function node:CreateTitle(title)
            entries[#entries + 1] = { text = title, isTitle = true, notCheckable = true }
        end
        function node:CreateDivider()
            entries[#entries + 1] = { text = " ", isTitle = true, notCheckable = true }
        end
        function node:CreateButton(label, action)
            local children = {}
            local entry = { text = label, notCheckable = true, func = action, menuList = children }
            entries[#entries + 1] = entry
            local child = Node(children)
            child._entry = entry
            return child
        end
        function node:CreateRadio(label, checked, action)
            entries[#entries + 1] = { text = label, checked = checked(), func = action, isNotRadio = false }
        end
        return node
    end
    local function Finish(entries)
        for _, entry in ipairs(entries) do
            if entry.menuList then
                if #entry.menuList > 0 then entry.hasArrow = true Finish(entry.menuList)
                else entry.menuList = nil end
            end
        end
    end
    rawset(env, "MenuUtil", {
        CreateContextMenu = function(owner, build)
            local entries = {}
            build(owner, Node(entries))
            Finish(entries)
            if not menuFrame then menuFrame = nativeCreateFrame("Frame", "SocialDiaryLegacyMenu", UIParent, "UIDropDownMenuTemplate") end
            EasyMenu(entries, menuFrame, "cursor", 0, 0, "MENU")
        end,
    })
end
