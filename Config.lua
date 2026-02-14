local addonName, addon = ...
local Config = {}
addon.Config = Config
local Skin = ForgeSkin 

local function GetCharKey()
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or 0
    return UnitName("player") .. "-" .. GetRealmName() .. "-" .. specID
end

function Config:RefreshUI()
    if f and f:IsShown() then self:SelectTab("Spells") end
end

local f 

function Config:Toggle()
    if not f then self:CreateUI() end
    if f:IsShown() then
        f:Hide()
        addon.ConfigMode = false
        addon:ScanAuras()
    else
        f:Show()
        addon.ConfigMode = true
        addon:ScanAuras()
        self:SelectTab("Spells")
    end
end

function Config:CreateUI()
    if f then return end
    f = CreateFrame("Frame", "BuffForgeConfig", UIParent, "BackdropTemplate")
    f:Hide()
    f:SetSize(800, 550)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetFrameStrata("HIGH")
    f:SetScript("OnHide", function() addon.ConfigMode = false; addon:ScanAuras() end)
    
    Skin:ApplyBackdrop(f)
    Skin:CreateTitleBar(f, "BuffForge Settings", function() f:Hide() end)

    self.tabButtons = {}
    local tabs = {"General", "Spells"}
    local x = 15; local y = -40
    for _, name in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetSize(120, 30); btn:SetPoint("TOPLEFT", x, y)
        Skin:ApplyBackdrop(btn); btn:SetBackdropColor(unpack(Skin.Colors.button))
        local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("CENTER"); t:SetText(name); btn.text = t
        btn:SetScript("OnClick", function() self:SelectTab(name) end)
        self.tabButtons[name] = btn
        x = x + 125
    end

    local scanTopBtn = Skin:CreateButton(f, "Scan Active Auras", 140, 30)
    scanTopBtn:SetPoint("TOPRIGHT", -15, -40)
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
        self:SelectTab("Spells")
    end)
    
    local contentBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    contentBg:SetPoint("TOPLEFT", 15, -75); contentBg:SetPoint("BOTTOMRIGHT", -15, 15)
    Skin:ApplyBackdrop(contentBg, 0.8)
    
    self.generalFrame = CreateFrame("Frame", nil, contentBg)
    self.generalFrame:SetPoint("TOPLEFT", 10, -10); self.generalFrame:SetPoint("BOTTOMRIGHT", -10, 10)
    self.generalFrame:Hide()
    
    self.spellsView = CreateFrame("Frame", nil, contentBg)
    self.spellsView:SetPoint("TOPLEFT", 10, -10); self.spellsView:SetPoint("BOTTOMRIGHT", -10, 10)
    self.spellsView:Hide()
    
    self:SelectTab("Spells")
end

function Config:SelectTab(name)
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
        self.spellsView:Hide(); self.generalFrame:Show()
        local p = self.generalFrame
        for _, c in ipairs({p:GetChildren()}) do c:Hide(); c:SetParent(nil) end
        for _, r in ipairs({p:GetRegions()}) do r:Hide(); r:SetParent(nil) end
        self:DrawGeneral(p)
        
    elseif name == "Spells" then
        self.generalFrame:Hide(); self.spellsView:Show()
        local p = self.spellsView
        for _, c in ipairs({p:GetChildren()}) do c:Hide(); c:SetParent(nil) end
        for _, r in ipairs({p:GetRegions()}) do r:Hide(); r:SetParent(nil) end
        self:DrawSpells(p)
    end
end

function Config:DrawGeneral(p)
    local y = -10
    -- Global Settings Divider (Referans aldığımız orijinal yapı)
    local h1 = Skin:CreateSectionHeader(p, "GLOBAL SETTINGS")
    h1:SetPoint("TOPLEFT", 10, y); y = y - 40
    
    local anchors = Skin:CreateCheckbox(p, "Unlock Anchors", BuffForgeDB.global.anchorsUnlocked, function(val) addon:ToggleAnchors() end)
    anchors:SetPoint("TOPLEFT", 10, y); y = y - 30

    local minimap = Skin:CreateCheckbox(p, "Show Minimap Button", not (BuffForgeDB.global.minimap and BuffForgeDB.global.minimap.hide), function(val) addon:ToggleMinimapButton(val) end)
    minimap:SetPoint("TOPLEFT", 10, y); y = y - 30

    -- Blizzard CD Settings
    local cdText = Skin:CreateCheckbox(p, "Show Blizzard CD Text", BuffForgeDB.global.showBlizzardCDText ~= false, function(val) 
        BuffForgeDB.global.showBlizzardCDText = val
        addon:UpdateAllIcons()
    end)
    cdText:SetPoint("TOPLEFT", 10, y); y = y - 30

    local cdSwipe = Skin:CreateCheckbox(p, "Show Blizzard CD Swipe", BuffForgeDB.global.showBlizzardCDSwipe ~= false, function(val) 
        BuffForgeDB.global.showBlizzardCDSwipe = val
        addon:UpdateAllIcons()
    end)
    cdSwipe:SetPoint("TOPLEFT", 10, y); y = y - 30

    -- HIJACK SETTING
    -- Default is TRUE (nil check inside logic defaults to true, so here we display it as true if nil)
    local hijackVal = (BuffForgeDB.global.hideBlizzardFrames ~= false) 
    
    local hijack = Skin:CreateCheckbox(p, "Hijack Blizzard Buff Bars (Hide Default)", hijackVal, function(val)
        BuffForgeDB.global.hideBlizzardFrames = val
        if BlizzardAuraTracker then BlizzardAuraTracker:ScanViewers() end
    end)
    -- Add tooltip or description? Maybe just the label is enough.
    hijack:SetPoint("TOPLEFT", 10, y); y = y - 40
end

function Config:DrawSpells(p)
    -- 1. Search Box (Replaces EditBox + Add Button + Dropdown)
    local searchBox = SpellSearchBox:Create(p, function(id, name, type)
         if id then
             local k = GetCharKey()
             BuffForgeDB.profile[k] = BuffForgeDB.profile[k] or {}
             
             -- Force Add / Update
             if not BuffForgeDB.profile[k][id] then
                 print("|cff00ff00BuffForge:|r Added new spell: "..name.." ("..id..")")
                 local defaults = {enabled=true, type="icon", size=40, simulatedMode=true}
                 if addon.GetSpellData then
                     local dbData = addon:GetSpellData(id)
                     if dbData then
                         defaults.simulatedCooldown = dbData.cooldown or 0
                         defaults.simulatedBuffDuration = addon:GetDurationFromDB(id) or dbData.buff_duration or 0
                     end
                 end
                 BuffForgeDB.profile[k][id] = defaults
             else
                 print("|cff00ff00BuffForge:|r Selected existing spell: "..name.." ("..id..")")
             end
             
             addon:UpdateIcon(id)
             
             -- Select the new spell
             Config.selectedSpellID = id

             -- Force UI Refresh (Re-draw spell list)
             print("|cff00ff00BuffForge:|r Icon updated. Refreshing UI...")
             
             -- Use the global Config object reference instead of potentially lost 'self'
             if Config.SelectTab then
                 Config:SelectTab("Spells")
             else
                 -- Fallback if something is very wrong
                 print("|cffff0000BuffForge Error:|r Could not refresh Config UI (SelectTab missing)")
             end
         end
    end)
    searchBox:SetPoint("TOPLEFT", 0, -5)
    searchBox:SetSize(240, 24)
    
    -- Pick Skill Button
    local pickBtn = Skin:CreateButton(p, "Pick Skill", 100, 24)
    pickBtn:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    pickBtn:SetScript("OnClick", function()
        SpellSearchBox:StartPickMode(function(id, name, type)
            if id then
                searchBox:OnSelect({id = id, name = name, isItem = (type == "item")})
            end
        end)
    end)
    
    -- STYLING: Apply ForgeSkin to the search box
    Skin:ApplyBackdrop(searchBox)
    searchBox:SetBackdropColor(0.1, 0.1, 0.1, 1) -- Slightly darker input background
    if searchBox.dropdown then 
        searchBox.dropdown:SetWidth(240)
        Skin:ApplyBackdrop(searchBox.dropdown) -- Optional: Skin the dropdown too if accessible
    end

    -- 2. CURRENT SELECTED SPELL NAME LABEL (Next to Pick Button)
    self.selectedSpellLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.selectedSpellLabel:SetPoint("LEFT", pickBtn, "RIGHT", 15, 0)
    self.selectedSpellLabel:SetTextColor(1, 0.84, 0, 1) -- Gold Color
    self.selectedSpellLabel:SetText("")
    
    -- Separator
    local sep = CreateFrame("Frame", nil, p)
    sep:SetSize(720, 1); sep:SetPoint("TOPLEFT", 0, -45)
    local line = sep:CreateTexture(nil, "OVERLAY"); line:SetColorTexture(unpack(Skin.Colors.accent)); line:SetAllPoints()
    
    -- Scroll Frames
    -- UPDATED: Width increased to 240
    local listFrame, listChild = Skin:CreateScrollFrame(p, 240, 340)
    listFrame:SetPoint("TOPLEFT", 0, -60); listFrame:SetPoint("BOTTOMLEFT", 0, 10)
    listFrame:EnableMouseWheel(false)
    
    local settingsFrame, settingsChild = Skin:CreateScrollFrame(p, 100, 100) 
    settingsFrame:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 20, 0); settingsFrame:SetPoint("BOTTOMRIGHT", -5, 10) 
    self.settingsChild = settingsChild 
    settingsFrame:EnableMouseWheel(true)
    settingsFrame:SetScript("OnMouseWheel", function(sf, delta)
        local cur = sf:GetVerticalScroll(); local max = sf:GetVerticalScrollRange()
        sf:SetVerticalScroll(math.max(0, math.min(max, cur - (delta * 30))))
    end)
    
    local k = GetCharKey()
    local profile = BuffForgeDB.profile[k] or {}
    local sorted = {}
    for id, _ in pairs(profile) do table.insert(sorted, id) end
    table.sort(sorted)
    
    self.spellListButtons = {} 
    local ly = 0; local firstSpell = nil
    
    for _, id in ipairs(sorted) do
        local opts = profile[id]
        local btn = CreateFrame("Button", nil, listChild, "BackdropTemplate")
        btn:SetSize(220, 28); btn:SetPoint("TOPLEFT", 0, ly) -- UPDATED: 220
        local isSelected = (self.selectedSpellID == id)
        if isSelected then Skin:ApplyBackdrop(btn); btn:SetBackdropColor(unpack(Skin.Colors.accent)); btn:SetBackdropBorderColor(unpack(Skin.Colors.accentHover))
        else Skin:ApplyBackdrop(btn, 0); btn:SetBackdropBorderColor(0,0,0,0) end
        self.spellListButtons[id] = btn
        local info = C_Spell.GetSpellInfo(id)
        local name = info and info.name or id
        local icon = info and info.iconID or 134400
        local ico = btn:CreateTexture(nil, "ARTWORK"); ico:SetSize(24, 24); ico:SetPoint("LEFT", 5, 0); ico:SetTexture(icon)
        local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("LEFT", ico, "RIGHT", 8, 0); t:SetWidth(145); t:SetJustifyH("LEFT"); t:SetText(name)
        if isSelected then t:SetTextColor(0,0,0) else t:SetTextColor(1,1,1) end; btn.text = t
        
        btn:SetScript("OnClick", function()
            self.selectedSpellID = id
            for bid, b in pairs(self.spellListButtons) do
                if bid == id then Skin:ApplyBackdrop(b); b:SetBackdropColor(unpack(Skin.Colors.accent)); if b.text then b.text:SetTextColor(0,0,0) end
                else Skin:ApplyBackdrop(b, 0); b:SetBackdropBorderColor(0,0,0,0); if b.text then b.text:SetTextColor(1,1,1) end end
            end
            self:DrawSpellSettings(settingsChild, id, opts)
        end)
        
        local delBtn = CreateFrame("Button", nil, btn, "BackdropTemplate")
        delBtn:SetSize(20, 20); delBtn:SetPoint("RIGHT", -5, 0)
        Skin:ApplyBackdrop(delBtn); delBtn:SetBackdropColor(0.8, 0.2, 0.2, 1)
        local delTxt = delBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); delTxt:SetPoint("CENTER"); delTxt:SetText("-")
        delBtn:SetScript("OnClick", function()
            BuffForgeDB.profile[k][id] = nil; addon:UpdateIcon(id)
            local parent = p
            -- Temizle ve yeniden çiz
            for _, c in ipairs({parent:GetChildren()}) do c:Hide(); c:SetParent(nil) end
            for _, r in ipairs({parent:GetRegions()}) do r:Hide(); r:SetParent(nil) end
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
             if b then Skin:ApplyBackdrop(b); b:SetBackdropColor(unpack(Skin.Colors.accent)); if b.text then b.text:SetTextColor(0,0,0) end end
         end)
    end
end

function Config:DrawSpellSettings(parent, id, opts)
    for _, c in ipairs({parent:GetChildren()}) do c:Hide(); c:SetParent(nil) end
    for _, r in ipairs({parent:GetRegions()}) do r:Hide(); r:SetParent(nil) end
    
    -- SET SELECTED SPELL NAME (Next to Dropdown)
    if self.selectedSpellLabel then
        local info = C_Spell.GetSpellInfo(id)
        local sName = (info and info.name) or ("Spell "..id)
        self.selectedSpellLabel:SetText("|cffffd700Selected: "..sName.." ("..id..")|r")
    end

    if not opts then return end
    
    -- ScrollChild genişliğini ayarla ki dividerlar düzgün hizalansın
    local scrollFrame = parent:GetParent()
    if scrollFrame then parent:SetWidth(scrollFrame:GetWidth()) end
    
    local totalW = parent:GetWidth()
    if totalW < 400 then totalW = 480 end 
    local L = {
        y = -5, 
        col1 = 10, width = totalW - 20,
        sliderW = 140, labelW = 120, rowH = 50, pad = 10,
        parent = parent
    }
    L.col2 = math.floor(L.width * 0.55)
    
    -- === HEADER (KULLANICI İSTEĞİ: Global Settings ile AYNI STİL) ===
    function L:Header(text)
        -- Artık manuel çizim yok, doğrudan Skin fonksiyonunu kullanıyoruz.
        -- Bu fonksiyon Global Settings'deki çizginin aynısını yaratır.
        local h = Skin:CreateSectionHeader(self.parent, text)
        h:SetPoint("TOPLEFT", self.col1, self.y)
        
        -- Skin fonksiyonu standart bir yükseklik kullanır (genelde 30-40px).
        -- Bir sonraki eleman için Y koordinatını aşağı çekiyoruz.
        self.y = self.y - 40 
    end
    
    function L:Slider(label, min, max, val, callback, col, customStep)
        local x = (col == 2) and self.col2 or self.col1
        local yPos = self.y
        local lbl = self.parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", x, yPos)
        lbl:SetText(label)
        lbl:SetWidth(self.labelW); lbl:SetJustifyH("LEFT")
        local slider = Skin:CreateSlider(self.parent, min, max, customStep or 1, val, callback, self.sliderW)
        slider:SetPoint("TOPLEFT", x, yPos - 18) 
        return slider
    end
    
    function L:Checkbox(label, val, callback, col)
        local x = (col == 2) and self.col2 or self.col1
        local cb = Skin:CreateCheckbox(self.parent, label, val, callback)
        cb:SetPoint("TOPLEFT", x, self.y - 15) 
        return cb
    end
    
    function L:Color(label, val, callback, col)
        local x = (col == 2) and self.col2 or self.col1
        local lbl = self.parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", x, self.y)
        lbl:SetText(label)
        lbl:SetWidth(self.sliderW); lbl:SetJustifyH("LEFT")
        local cp = Skin:CreateColorPicker(self.parent, "", val or {1,1,1,1}, callback)
        cp:SetPoint("TOPLEFT", x, self.y - 15) 
        cp:SetSize(self.sliderW, 24) 
        return cp
    end
    
    function L:NextRow() self.y = self.y - self.rowH end
    function L:Space(amount) self.y = self.y - (amount or self.pad) end
    
    -- === UI ÇİZİMİ ===
    L:Header("POSITION & SIZE")
    L:Slider("X Offset", -400, 400, opts.x or 0, function(v) opts.x = v; addon:UpdateIcon(id) end, 1)
    L:Slider("Y Offset", -400, 400, opts.y or 0, function(v) opts.y = v; addon:UpdateIcon(id) end, 2)
    L:NextRow()
    L:Slider("Icon Size", 10, 200, opts.size or 40, function(v) opts.size = v; addon:UpdateIcon(id) end, 1)
    if opts.type == "bar" then L:Slider("Bar Width", 50, 600, opts.width or 200, function(v) opts.width = v; addon:UpdateIcon(id) end, 2) end
    L:NextRow(); L:Space()
    
    L:Header("DISPLAY OPTIONS")
    L:Checkbox("Display as Bar", opts.type == "bar", function(v) opts.type = v and "bar" or "icon"; addon:UpdateIcon(id); self:DrawSpellSettings(parent, id, opts) end, 1)
    L:Checkbox("Always Show", opts.alwaysShow, function(v) opts.alwaysShow = v; addon:UpdateIcon(id) end, 2)
    L:NextRow()
    L:Checkbox("Enabled", opts.enabled, function(v) opts.enabled = v; addon:UpdateIcon(id) end, 1)
    L:Checkbox("Desaturate on CD", opts.desaturate, function(v) opts.desaturate = v; addon:UpdateIcon(id) end, 2)
    L:NextRow(); L:Space()
    
    L:Header("BORDER")
    L:Checkbox("Show Border", opts.showBorder, function(v) 
        opts.showBorder = v; addon:UpdateIcon(id); self:DrawSpellSettings(parent, id, opts) 
    end, 1)
    L:NextRow()
    
    if opts.showBorder then 
        L:Color("Border Color", opts.borderColor, function(c) opts.borderColor = c; addon:UpdateIcon(id) end, 1) 
        L:Slider("Border Thick.", 1, 10, opts.borderThickness or 1, function(v) opts.borderThickness = v; addon:UpdateIcon(id) end, 2)
        L:NextRow()
    end
    if opts.type == "bar" then 
        L:Color("Bar Color", opts.barColor, function(c) opts.barColor = c; addon:UpdateIcon(id) end, 1) 
        L:NextRow()
    end
    L:Space()
    
    -- === DYNAMIC GLOW SETTINGS ===
    local function DrawGlowSection(label, settingKey)
        L:Header(label)
        local gSet = opts[settingKey] or {}
        if not gSet.type then gSet.type = "pixel"; gSet.color = {1,1,0,1} end
        
        L:Checkbox("Enable Glow", gSet.enabled, function(v) 
             gSet.enabled = v; opts[settingKey] = gSet; addon:UpdateIcon(id) 
             self:DrawSpellSettings(parent, id, opts) 
        end, 1)
        L:NextRow()
        
        if gSet.enabled then
            -- 1. Glow Type Dropdown (SOL)
            local types = {{text="Pixel Glow", value="pixel"}, {text="AutoCast Glow", value="autocast"}, {text="Button Glow", value="button"}, {text="Pulse (Alpha)", value="pulse"}}
            local ddLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            ddLabel:SetPoint("TOPLEFT", L.col1, L.y)
            ddLabel:SetText("Glow Type")
            local dd = Skin:CreateDropdown(parent, 140, types, function(v)
                gSet.type = v; addon:UpdateIcon(id); self:DrawSpellSettings(parent, id, opts)
            end)
            dd:SetPoint("TOPLEFT", L.col1, L.y - 15)
            local currT = "Pixel Glow"; for _,t in ipairs(types) do if t.value==gSet.type then currT=t.text end end
            dd.text:SetText(currT)
            
            -- 2. Threshold Slider (SAĞ)
            local threshLabel = (settingKey == "cdGlow") and "Time Left (s)" or "Time Left (s) (0=All)"
            L:Slider(threshLabel, 0, 30, gSet.threshold or 0, function(v) gSet.threshold = v; addon:UpdateIcon(id) end, 2, 0.5)
            
            L:NextRow()
            
            -- Row 2: Color
            L:Color("Glow Color", gSet.color, function(c) gSet.color = c; addon:UpdateIcon(id) end, 1)
            
            -- Column 2: Details
            if gSet.type == "pixel" then
                L:Slider("Lines", 1, 20, gSet.lines or 8, function(v) gSet.lines = v; addon:UpdateIcon(id) end, 2)
                L:NextRow()
                L:Slider("Frequency", 0.1, 2, gSet.freq or 0.25, function(v) gSet.freq = v; addon:UpdateIcon(id) end, 1, 0.05)
                L:Slider("Length", 1, 20, gSet.length or 5, function(v) gSet.length = v; addon:UpdateIcon(id) end, 2)
                L:NextRow()
                L:Slider("Thickness", 1, 10, gSet.thickness or 2, function(v) gSet.thickness = v; addon:UpdateIcon(id) end, 1)
                L:NextRow()
            elseif gSet.type == "autocast" then
                L:Slider("Particles", 1, 20, gSet.lines or 8, function(v) gSet.lines = v; addon:UpdateIcon(id) end, 2)
                L:NextRow()
                L:Slider("Frequency", 0.1, 2, gSet.freq or 0.25, function(v) gSet.freq = v; addon:UpdateIcon(id) end, 1, 0.05)
                L:Slider("Scale", 0.5, 3, gSet.scale or 1, function(v) gSet.scale = v; addon:UpdateIcon(id) end, 2, 0.1)
                L:NextRow()
            elseif gSet.type == "pulse" then
                L:Slider("Speed (Dur)", 0.1, 3, gSet.freq or 1, function(v) gSet.freq = v; addon:UpdateIcon(id) end, 2, 0.1)
                L:NextRow()
            else
                 L:NextRow()
            end
        else
             -- Glow kapalı
        end
        L:Space()
    end
    
    DrawGlowSection("COOLDOWN FINISH EFFECT", "cdGlow")
    DrawGlowSection("ACTIVE BUFF EFFECT", "buffGlow")

    L:Header("SIMULATION")
    local infoTxt = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoTxt:SetPoint("TOPLEFT", L.col1, L.y); infoTxt:SetWidth(L.width); infoTxt:SetJustifyH("LEFT"); infoTxt:SetWordWrap(true)
    infoTxt:SetText("Cooldowns used out of combat are automatically saved.")
    L:Space(20)
    
    L:Checkbox("Enable Simulated Mode", opts.simulatedMode, function(v)
        opts.simulatedMode = v; addon:UpdateIcon(id); self:DrawSpellSettings(parent, id, opts)
    end, 1)
    
    if opts.simulatedMode then
        L:NextRow()
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
        self:DrawSpellSettings(self.settingsChild, spellID, profile[spellID])
    end
end