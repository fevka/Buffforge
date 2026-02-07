local addonName, addon = ...
local Config = {}
addon.Config = Config

local Skin = ForgeSkin -- Reference to the library

local function GetCharKey()
    -- Key includes Spec ID
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or 0
    return UnitName("player") .. "-" .. GetRealmName() .. "-" .. specID
end

function Config:RefreshUI()
    if f and f:IsShown() then
        self:SelectTab("Spells") -- Force refresh
    end
end

-- === MAIN UI ===

local f -- Main Frame

function Config:Toggle()
    if not f then self:CreateUI() end
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        -- Refresh spell list in case spec changed
        self:SelectTab("Spells")
    end
end

function Config:CreateUI()
    if f then return end
    
    -- Main Window
    f = CreateFrame("Frame", "BuffForgeConfig", UIParent, "BackdropTemplate")
    f:Hide() -- Start hidden so Toggle works correctly
    f:SetSize(800, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    
    Skin:ApplyBackdrop(f)
    
    -- ForgeSkin Standard Title Bar
    Skin:CreateTitleBar(f, "BuffForge Settings", function() f:Hide() end)

    -- Tabs Area (Top)
    self.tabButtons = {}
    local tabs = {"General", "Spells"}
    local x = 15
    local y = -40
    
    for _, name in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetSize(120, 30)
        btn:SetPoint("TOPLEFT", x, y)
        Skin:ApplyBackdrop(btn)
        btn:SetBackdropColor(unpack(Skin.Colors.button))
        
        local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("CENTER")
        t:SetText(name)
        btn.text = t
        
        btn:SetScript("OnClick", function() self:SelectTab(name) end)
        self.tabButtons[name] = btn
        
        x = x + 125 -- Horizontal spacing
    end

    -- Scan Button (Requested Location: Top Right, same line as tabs)
    local scanTopBtn = Skin:CreateButton(f, "Scan Active Auras", 140, 30)
    scanTopBtn:SetPoint("TOPRIGHT", -15, -40) -- Aligned with tabs y=-40
    scanTopBtn:SetScript("OnClick", function()
        local k = GetCharKey()
        BuffForgeDB.profile[k] = BuffForgeDB.profile[k] or {}
        
        local count = 0
        for i=1, 40 do
            local data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not data then break end
            local id = data.spellId
            if id and not BuffForgeDB.profile[k][id] then
                 BuffForgeDB.profile[k][id] = {enabled=true, type="icon", size=40}
                 addon:UpdateIcon(id)
                 count = count + 1
            end
        end
        print("|cff00ff00BuffForge:|r Scanned "..count.." new auras.")
        self:SelectTab("Spells") -- Refresh view
    end)
    
    -- Content Area Background
    local contentBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    contentBg:SetPoint("TOPLEFT", 15, -75) -- Below tabs
    contentBg:SetPoint("BOTTOMRIGHT", -15, 15)
    Skin:ApplyBackdrop(contentBg, 0.8)
    
    -- View 1: General (Simple Frame, No Scroll)
    self.generalFrame = CreateFrame("Frame", nil, contentBg)
    self.generalFrame:SetPoint("TOPLEFT", 10, -10)
    self.generalFrame:SetPoint("BOTTOMRIGHT", -10, 10)
    self.generalFrame:Hide()
    
    -- View 2: Spells (Uses Container, NO ScrollFrame wrapper)
    self.spellsView = CreateFrame("Frame", nil, contentBg)
    self.spellsView:SetPoint("TOPLEFT", 10, -10)
    self.spellsView:SetPoint("BOTTOMRIGHT", -10, 10)
    self.spellsView:Hide()
    
    -- Footer
    -- Scan button moved to header content area per request
    
    self:SelectTab("Spells")
end



function Config:SelectTab(name)
    -- Update Sidebar
    for n, btn in pairs(self.tabButtons) do
        if n == name then
            btn:SetBackdropColor(unpack(Skin.Colors.accent))
            btn:SetBackdropBorderColor(unpack(Skin.Colors.accentHover))
            if btn.text then btn.text:SetTextColor(0, 0, 0) end
        else
            btn:SetBackdropColor(unpack(Skin.Colors.button))
            btn:SetBackdropBorderColor(unpack(Skin.Colors.border))
            if btn.text then btn.text:SetTextColor(unpack(Skin.Colors.text)) end
        end
    end
    
    if name == "General" then
        self.spellsView:Hide()
        self.generalFrame:Show()
        
        -- Clear General Frame
        local p = self.generalFrame
        for _, c in ipairs({p:GetChildren()}) do c:Hide(); c:SetParent(nil) end
        
        self:DrawGeneral(p)
        
    elseif name == "Spells" then
        self.generalFrame:Hide()
        self.spellsView:Show()
        
        -- Clear Spells View
        local p = self.spellsView
        for _, c in ipairs({p:GetChildren()}) do c:Hide(); c:SetParent(nil) end
        
        self:DrawSpells(p)
    end
end

-- === GENERAL TAB ===
function Config:DrawGeneral(p)
    local y = -20
    
    local h1 = Skin:CreateSectionHeader(p, "GLOBAL SETTINGS")
    h1:SetPoint("TOPLEFT", 10, y)
    y = y - 50
    
    local anchors = Skin:CreateCheckbox(p, "Unlock Anchors", BuffForgeDB.global.anchorsUnlocked, function(val)
        addon:ToggleAnchors()
    end)
    anchors:SetPoint("TOPLEFT", 10, y)
    y = y - 50
    
    local minimap = Skin:CreateCheckbox(p, "Show Minimap Button", not (BuffForgeDB.global.minimap and BuffForgeDB.global.minimap.hide), function(val)
        addon:ToggleMinimapButton(val)
    end)
    minimap:SetPoint("TOPLEFT", 10, y)
    y = y - 50
end

-- === SPELLS TAB ===
-- === SPELLS TAB ===
function Config:DrawSpells(p)
    -- Top: Add Spell
    local input = CreateFrame("EditBox", nil, p, "BackdropTemplate")
    input:SetSize(160, 24)
    input:SetPoint("TOPLEFT", 10, -5)
    Skin:ApplyBackdrop(input)
    input:SetBackdropColor(0.1, 0.1, 0.1, 1)
    input:SetFontObject("GameFontHighlight")
    input:SetAutoFocus(false)
    input:SetTextInsets(5, 5, 0, 0)
    input:SetText("ID/Name")
    
    local addBtn = Skin:CreateButton(p, "+", 24, 24)
    addBtn:SetPoint("LEFT", input, "RIGHT", 5, 0)
    addBtn:SetScript("OnClick", function()
        local txt = input:GetText()
        if txt and txt~="" and txt~="ID/Name" then
             local id = tonumber(txt)
             if not id then 
                local info = C_Spell.GetSpellInfo(txt)
                if info then id = info.spellID end
             end
             if id then
                 local k = GetCharKey()
                 BuffForgeDB.profile[k] = BuffForgeDB.profile[k] or {}
                 if not BuffForgeDB.profile[k][id] then
                     local defaults = {enabled=true, type="icon", size=40, simulatedMode=true}
                     
                     -- Pre-fill from DB (Auto-Sim)
                     if addon.GetSpellData then
                         local dbData = addon:GetSpellData(id)
                         if dbData then
                             defaults.simulatedCooldown = dbData.cooldown or 0
                             defaults.simulatedBuffDuration = addon:GetDurationFromDB(id) or dbData.buff_duration or 0
                         end
                     end
                     
                     BuffForgeDB.profile[k][id] = defaults
                 end
                 addon:UpdateIcon(id) 
                 -- Redraw
                 local parent = p
                 for _, c in ipairs({parent:GetChildren()}) do c:Hide(); c:SetParent(nil) end
                 self:DrawSpells(parent)
             end
        end
    end)
    
    input:SetScript("OnEnterPressed", function() addBtn:Click() input:ClearFocus() end)
    input:SetScript("OnEditFocusGained", function(self) if self:GetText()=="ID/Name" then self:SetText("") end end)
    input:SetScript("OnEditFocusLost", function(self) if self:GetText()=="" then self:SetText("ID/Name") end end)
    
    -- Separator
    local sep = CreateFrame("Frame", nil, p)
    sep:SetSize(720, 1) 
    sep:SetPoint("TOPLEFT", 0, -45)
    local line = sep:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(unpack(Skin.Colors.accent))
    line:SetAllPoints()
    
    -- Database Cooldown Dropdown
    local dbSpells = {}
    local _, playerClass = UnitClass("player")
    local currentSpec = GetSpecialization()
    local specName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "ALL"
    specName = specName:upper() 
    
    if BuffForge_SpellDB then
        local allSpells = BuffForge_SpellDB:GetAll()
        for spellID, data in pairs(allSpells) do
            local isCorrectClass = (data.class == playerClass)
            local hasCooldown = (data.cooldown and data.cooldown > 0)
            local isCorrectSpec = false
            if data.spec == "ALL" then isCorrectSpec = true
            else
                local specs = {strsplit(",", data.spec)}
                for _, spec in ipairs(specs) do
                    if strtrim(spec):upper() == specName:upper() then isCorrectSpec = true; break end
                end
            end
            
            if isCorrectClass and isCorrectSpec and hasCooldown then
                local typeColor = ""
                if data.type == "BURST" then typeColor = "|cffff8800"
                elseif data.type == "DEFENSIVE" then typeColor = "|cff00aaff"
                elseif data.type == "INTERRUPT" then typeColor = "|cffff0000"
                elseif data.type == "RAID_CD" then typeColor = "|cff00ff00"
                else typeColor = "|cffaaaaaa" end
                
                table.insert(dbSpells, {
                    text = string.format("%s%s|r (%ds)", typeColor, data.name, data.cooldown),
                    value = spellID
                })
            end
        end
    end
    table.sort(dbSpells, function(a,b) return a.text < b.text end)
    
    if #dbSpells > 0 then
        local dd = Skin:CreateDropdown(p, 250, dbSpells, function(val)
            if val then input:SetText(val) end
        end)
        dd:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
        dd.text:SetText("Select Spell from Book...")
    end

    -- Left: Scrollable List
    local listFrame, listChild = Skin:CreateScrollFrame(p, 200, 340)
    listFrame:SetPoint("TOPLEFT", 0, -60)
    listFrame:SetPoint("BOTTOMLEFT", 0, 10) -- Anchor bottom
    listFrame:EnableMouseWheel(false)
    
    -- Right: Settings ScrollFrame
    -- Dynamic Sizing: Anchor to list on left, and PARENT Right edge on right
    local settingsFrame, settingsChild = Skin:CreateScrollFrame(p, 100, 100) -- Size ignored due to points
    settingsFrame:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 20, 0)
    settingsFrame:SetPoint("BOTTOMRIGHT", -5, 10) 
    
    self.settingsChild = settingsChild 
    
    settingsFrame:EnableMouseWheel(true)
    settingsFrame:SetScript("OnMouseWheel", function(sf, delta)
        local cur = sf:GetVerticalScroll()
        local max = sf:GetVerticalScrollRange()
        sf:SetVerticalScroll(math.max(0, math.min(max, cur - (delta * 30))))
    end)
    
    -- Populate List
    local k = GetCharKey()
    local profile = BuffForgeDB.profile[k] or {}
    local sorted = {}
    for id, _ in pairs(profile) do table.insert(sorted, id) end
    table.sort(sorted)
    
    self.spellListButtons = {} 
    
    local ly = 0
    local firstSpell = nil
    
    for _, id in ipairs(sorted) do
        local opts = profile[id]
        local btn = CreateFrame("Button", nil, listChild, "BackdropTemplate")
        btn:SetSize(180, 28)
        btn:SetPoint("TOPLEFT", 0, ly)
        
        local isSelected = (self.selectedSpellID == id)
        if isSelected then
             Skin:ApplyBackdrop(btn)
             btn:SetBackdropColor(unpack(Skin.Colors.accent))
             btn:SetBackdropBorderColor(unpack(Skin.Colors.accentHover))
        else
             Skin:ApplyBackdrop(btn, 0); btn:SetBackdropBorderColor(0,0,0,0)
        end
        
        self.spellListButtons[id] = btn

        local info = C_Spell.GetSpellInfo(id)
        local name = info and info.name or id
        local icon = info and info.iconID or 134400
        
        local ico = btn:CreateTexture(nil, "ARTWORK")
        ico:SetSize(24, 24)
        ico:SetPoint("LEFT", 5, 0)
        ico:SetTexture(icon)
        
        local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("LEFT", ico, "RIGHT", 8, 0)
        t:SetWidth(125); t:SetJustifyH("LEFT")
        t:SetText(name)
        if isSelected then t:SetTextColor(0,0,0) else t:SetTextColor(1,1,1) end
        btn.text = t
        
        btn:SetScript("OnClick", function()
            self.selectedSpellID = id
            -- Highlight update logic embedded for brevity
            for bid, b in pairs(self.spellListButtons) do
                if bid == id then
                    Skin:ApplyBackdrop(b)
                    b:SetBackdropColor(unpack(Skin.Colors.accent))
                    if b.text then b.text:SetTextColor(0,0,0) end
                else
                    Skin:ApplyBackdrop(b, 0); b:SetBackdropBorderColor(0,0,0,0)
                    if b.text then b.text:SetTextColor(1,1,1) end
                end
            end
            self:DrawSpellSettings(settingsChild, id, opts)
        end)
        
        -- DELETE BUTTON
        local delBtn = CreateFrame("Button", nil, btn, "BackdropTemplate")
        delBtn:SetSize(20, 20); delBtn:SetPoint("RIGHT", -5, 0)
        Skin:ApplyBackdrop(delBtn); delBtn:SetBackdropColor(0.8, 0.2, 0.2, 1)
        local delTxt = delBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        delTxt:SetPoint("CENTER"); delTxt:SetText("-")
        delBtn:SetScript("OnClick", function()
            BuffForgeDB.profile[k][id] = nil
            addon:UpdateIcon(id)
            local parent = p
            for _, c in ipairs({parent:GetChildren()}) do c:Hide(); c:SetParent(nil) end
            self:DrawSpells(parent)
        end)
        
        if not firstSpell then firstSpell = {id = id, opts = opts} end
        ly = ly - 32
    end
    listChild:SetHeight(math.abs(ly) + 10)
    
    if not self.selectedSpellID and firstSpell then self.selectedSpellID = firstSpell.id end
    if self.selectedSpellID and profile[self.selectedSpellID] then
         C_Timer.After(0.01, function()
             self:DrawSpellSettings(settingsChild, self.selectedSpellID, profile[self.selectedSpellID])
             local b = self.spellListButtons[self.selectedSpellID]
             if b then 
                 Skin:ApplyBackdrop(b)
                 b:SetBackdropColor(unpack(Skin.Colors.accent))
                 if b.text then b.text:SetTextColor(0,0,0) end
             end
         end)
    end
end

function Config:DrawSpellSettings(parent, id, opts)
    -- Clear settings pane (Children AND Regions)
    for _, c in ipairs({parent:GetChildren()}) do c:Hide(); c:SetParent(nil) end
    for _, r in ipairs({parent:GetRegions()}) do r:Hide(); r:SetParent(nil) end
    
    if not opts then return end
    
    -- === DYNAMIC LAYOUT ===
    -- Calculate available width from parent (Settings ScrollChild)
    -- Parent width is controlled by ScrollFrame width.
    -- We assume ~500px min, but we can be dynamic.
    local totalW = parent:GetWidth()
    if totalW < 400 then totalW = 480 end -- Fallback/Default
    
    local L = {
        y = -10,
        col1 = 10,
        width = totalW - 20, -- Padding
        
        -- Dimensions
        sliderW = 140,
        labelW = 120,
        headerH = 30,
        rowH = 40, 
        pad = 20,
        
        parent = parent
    }
    
    -- Calc Col2 based on Width
    -- We want Col2 to start at roughly 55% of width
    L.col2 = math.floor(L.width * 0.55)
    
    -- === LAYOUT HELPERS (Same as before) ===
    function L:Header(text)
        local h = Skin:CreateSectionHeader(self.parent, text)
        h:SetPoint("TOPLEFT", self.col1, self.y)
        self.y = self.y - self.headerH - 10
    end
    
    function L:Slider(label, min, max, val, callback, col, customStep)
        local x = (col == 2) and self.col2 or self.col1
        local yPos = self.y
        local lbl = self.parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", x, yPos)
        lbl:SetText(label)
        lbl:SetWidth(self.labelW)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        local slider = Skin:CreateSlider(self.parent, min, max, customStep or 1, val, callback, self.sliderW)
        slider:SetPoint("TOPLEFT", x, yPos - 15)
        return slider
    end
    
    function L:Checkbox(label, val, callback, col)
        local x = (col == 2) and self.col2 or self.col1
        local cb = Skin:CreateCheckbox(self.parent, label, val, callback)
        cb:SetPoint("TOPLEFT", x, self.y)
        return cb
    end
    
    function L:Color(label, val, callback, col)
        local x = (col == 2) and self.col2 or self.col1
        local cp = Skin:CreateColorPicker(self.parent, label, val or {1,1,1,1}, callback)
        cp:SetPoint("TOPLEFT", x, self.y)
        cp:SetSize(self.sliderW, 24) 
        return cp
    end
    
    function L:NextRow() self.y = self.y - self.rowH end
    function L:Space(amount) self.y = self.y - (amount or self.pad) end
    
    local MOVE_RANGE = 400 
    
    -- === DRAWING THE UI ===
    local info = C_Spell.GetSpellInfo(id)
    L:Header((info and info.name) or ("Spell "..id))
    L:Space(10)
    
    -- SECTION 1: POSITION & SIZE
    L:Header("POSITION & SIZE")
    L:Slider("X Offset", -MOVE_RANGE, MOVE_RANGE, opts.x or 0, function(v) opts.x = v; addon:UpdateIcon(id) end, 1)
    L:Slider("Y Offset", -MOVE_RANGE, MOVE_RANGE, opts.y or 0, function(v) opts.y = v; addon:UpdateIcon(id) end, 2)
    L:NextRow()
    L:Slider("Icon Size", 10, 200, opts.size or 40, function(v) opts.size = v; addon:UpdateIcon(id) end, 1)
    if opts.type == "bar" then
        L:Slider("Bar Width", 50, 600, opts.width or 200, function(v) opts.width = v; addon:UpdateIcon(id) end, 2)
    end
    L:NextRow(); L:Space()
    
    -- SECTION 2: DISPLAY OPTIONS
    L:Header("DISPLAY OPTIONS")
    L:Checkbox("Display as Bar", opts.type == "bar", function(v) opts.type = v and "bar" or "icon"; addon:UpdateIcon(id); self:DrawSpellSettings(parent, id, opts) end, 1)
    L:Checkbox("Always Show", opts.alwaysShow, function(v) opts.alwaysShow = v; addon:UpdateIcon(id) end, 2)
    L:NextRow()
    L:Checkbox("Show Border", opts.showBorder, function(v) opts.showBorder = v; addon:UpdateIcon(id); self:DrawSpellSettings(parent, id, opts) end, 1)
    L:Checkbox("Enabled", opts.enabled, function(v) opts.enabled = v; addon:UpdateIcon(id) end, 2)
    L:NextRow()
    L:Checkbox("Desaturate on CD", opts.desaturate, function(v) opts.desaturate = v; addon:UpdateIcon(id) end, 1)
    L:NextRow(); L:Space()
    
    -- SECTION 3: COLORS & BORDER
    if opts.showBorder or opts.type == "bar" then
        L:Header("COLORS & BORDER")
        if opts.showBorder then 
            L:Color("Border Color", opts.borderColor, function(c) opts.borderColor = c; addon:UpdateIcon(id) end, 1) 
            -- Border Thickness Slider (Col 2)
            L:Slider("Border Thick.", 1, 10, opts.borderThickness or 1, function(v) opts.borderThickness = v; addon:UpdateIcon(id) end, 2)
        end
        L:NextRow()
        
        if opts.type == "bar" then 
            L:Color("Bar Color", opts.barColor, function(c) opts.barColor = c; addon:UpdateIcon(id) end, 1) 
        end
        L:NextRow(); L:Space()
    end
    
    -- SECTION 4: VISUAL EFFECTS
    L:Header("VISUAL EFFECTS")
    -- Row 1: Glow/Sparkle Dropdown & Color
    local effects = {
        {text="None", value="none"},
        {text="Pixel Glow", value="pixel"},
        {text="AutoCast Glow", value="autocast"},
        {text="Button Glow", value="button"},
        {text="Pulse", value="pulse"},
    }
    
    -- Manual Dropdown (Custom implementation for Layout Engine)
    local effLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    effLabel:SetPoint("TOPLEFT", L.col1, L.y)
    effLabel:SetText("Effect Type")
    
    local effDD = Skin:CreateDropdown(parent, 140, effects, function(v)
        opts.visualEffect = v
        addon:UpdateIcon(id)
    end)
    effDD:SetPoint("TOPLEFT", L.col1, L.y - 15)
    -- Find current text
    local currText = "None"
    for _, e in ipairs(effects) do if e.value == opts.visualEffect then currText = e.text break end end
    effDD.text:SetText(currText)
    
    -- Effect Color (Col 2)
    L:Color("Effect Color", opts.effectColor, function(c) opts.effectColor = c; addon:UpdateIcon(id) end, 2)
    
    L:NextRow(); L:Space(10) -- Extra space for dropdown
    
    -- Row 2: Standard Glow Sliders
    L:Slider("Cooldown Glow (s)", 0, 30, opts.threshold or 0, function(v) opts.threshold = v; addon:UpdateIcon(id) end, 1, 0.5)
    L:Slider("Buff Glow (s)", 0, 30, opts.buffThreshold or 0, function(v) opts.buffThreshold = v; addon:UpdateIcon(id) end, 2, 0.5)
    L:NextRow(); L:Space()
    
    -- SECTION 5: SIMULATION
    L:Header("SIMULATION")
    -- Info Text (No Box)
    local infoTxt = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoTxt:SetPoint("TOPLEFT", L.col1, L.y)
    infoTxt:SetWidth(L.width)
    infoTxt:SetJustifyH("LEFT")
    infoTxt:SetWordWrap(true)
    infoTxt:SetText("Cooldowns used out of combat are automatically saved to the database, ensuring optimal accuracy. This eliminates errors and allows the software to adaptively improve itself.")
    
    local textHeight = infoTxt:GetStringHeight()
    L:Space(textHeight + 10)
    
    L:Checkbox("Enable Simulated Mode", opts.simulatedMode, function(v)
        opts.simulatedMode = v; addon:UpdateIcon(id); self:DrawSpellSettings(parent, id, opts)
    end, 1)
    
    local dbBtn = Skin:CreateButton(parent, "Load Learned Data", 140, 24)
    dbBtn:SetPoint("TOPLEFT", L.col2, L.y + 2) 
    dbBtn:SetScript("OnClick", function()
         if addon.GetSpellData then
            local spellData = addon:GetSpellData(id)
            if spellData then
                opts.simulatedBuffDuration = addon:GetDurationFromDB(id) or spellData.buff_duration or 0
                opts.simulatedCooldown = spellData.cooldown or 0
                print("|cff00ff00BuffForge:|r Loaded Data.")
                addon:UpdateIcon(id)
                self:DrawSpellSettings(parent, id, opts)
            end
        end
    end)
    L:NextRow()
    
    if opts.simulatedMode then
        L:Slider("Buff Duration", 0, 60, opts.simulatedBuffDuration or 0, function(v) opts.simulatedBuffDuration = v end, 1)
        L:Slider("Cooldown", 0, 120, opts.simulatedCooldown or 0, function(v) opts.simulatedCooldown = v end, 2)
        L:NextRow()
    end
    
    parent:SetHeight(math.abs(L.y) + 50)
end

function Config:RefreshCurrentSpell(spellID)
    if not f or not f:IsShown() then return end
    if self.selectedSpellID == spellID and self.settingsChild and self.settingsChild:IsVisible() then
        local k = GetCharKey()
        local profile = BuffForgeDB.profile[k] or {}
        local opts = profile[spellID]
        
        -- Direct refresh using stored reference
        self:DrawSpellSettings(self.settingsChild, spellID, opts)
        -- print("BuffForge: UI Refreshed for "..spellID)
    end
end