local addonName, addon = ...
BuffForge = addon

-- Access the Skin Library
local Skin = ForgeSkin
local SpellDB = BuffForge_SpellDB

-- === DATABASE DEFAULTS ===
local defaults = {
    profile = {}, 
    global = {
        anchorsUnlocked = false,
        minimap = { hide = false, minimapPos = 220 } 
    }
}

-- Default settings for a new spell
local DEFAULT_SETTINGS = {
    enabled = true,
    type = "icon",
    
    -- Positioning
    point = "CENTER",
    relativeTo = "UIParent",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    
    -- Dimensions
    size = 40,
    width = 200,
    
    -- Visuals
    showBorder = true,
    borderColor = Skin.Colors.border,
    barColor = Skin.Colors.normal or {0.2, 0.8, 0.2, 1},
    barTexture = "Interface\\Buttons\\WHITE8x8",
    
    -- Behavior
    alwaysShow = false,
    desaturate = true,
    
    -- NEW: Separate Glow Settings
    cdGlow = {
        enabled = false,
        threshold = 0,
        type = "pixel",
        color = {0.8, 0.6, 0, 1},
        lines = 8,
        freq = 0.25,
        length = 5,
        thickness = 2,
        scale = 1,
    },
    
    buffGlow = {
        enabled = false,
        threshold = 0,
        type = "button",
        color = {0, 1, 0, 1},
        lines = 8,
        freq = 0.25,
        length = 5,
        thickness = 2,
        scale = 1,
    },
    
    -- Manual Simulation
    simulatedMode = false,
    simulatedBuffDuration = 0,
    simulatedCooldown = 0,
}

local icons = {} 
local memory = {} 
local simulated = {} 

-- === UTILS ===
local function GetCharKey()
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or 0
    return UnitName("player") .. "-" .. GetRealmName() .. "-" .. specID
end

-- === DATABASE METHODS ===
function addon:LearnSpellData(spellID, key, value)
    if not BuffForgeDB then return end
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or 0
    
    BuffForgeDB.global.learnedDB = BuffForgeDB.global.learnedDB or {}
    BuffForgeDB.global.learnedDB[specID] = BuffForgeDB.global.learnedDB[specID] or {}
    local db = BuffForgeDB.global.learnedDB[specID]
    
    db[spellID] = db[spellID] or {}
    if value and value > 0 then
        if db[spellID][key] ~= value then
            db[spellID][key] = value
        end
    end
end

function addon:GetSpellData(spellID)
    local data = { buff_duration=0, cooldown=0, name="", icon=134400, charges=1 }
    
    if BuffForge_SpellDB then
        local static = BuffForge_SpellDB:GetSpell(spellID)
        if static then
            data.buff_duration = static.buff_duration or 0
            data.cooldown = static.cooldown or 0
            data.name = static.name
            data.icon = static.icon
            data.charges = static.charges or 1
            data.talents = static.talents
        end
    end
    
    if BuffForgeDB and BuffForgeDB.global and BuffForgeDB.global.learnedDB then
        local specIndex = GetSpecialization()
        local specID = specIndex and GetSpecializationInfo(specIndex) or 0
        local learned = BuffForgeDB.global.learnedDB[specID] and BuffForgeDB.global.learnedDB[specID][spellID]
        
        if learned then
             if learned.buff and learned.buff > 0 then data.buff_duration = learned.buff end
             if learned.cd and learned.cd > 0 then data.cooldown = learned.cd end
        end
    end
    return data
end

function addon:GetDurationFromDB(spellID)
    local data = addon:GetSpellData(spellID)
    local duration = data.buff_duration
    
    local isLearned = false
    if BuffForgeDB and BuffForgeDB.global and BuffForgeDB.global.learnedDB then
        local specIndex = GetSpecialization()
        local specID = specIndex and GetSpecializationInfo(specIndex) or 0
        local learned = BuffForgeDB.global.learnedDB[specID] and BuffForgeDB.global.learnedDB[specID][spellID]
        if learned and learned.buff and learned.buff > 0 then isLearned = true end
    end
    
    if isLearned then return duration end 
    
    if data.talents then
        for _, talent in ipairs(data.talents) do
            if talent.duration_bonus and talent.spell_id and IsPlayerSpell(talent.spell_id) then
                duration = duration + talent.duration_bonus
            end
        end
    end
    return duration
end

-- === SIMULATED TRACKING ===
local function CheckSimulatedState(spellID, settings)
    local now = GetTime()
    local sim = simulated[spellID]
    if not sim then return nil end
    
    local dbInfo = BuffForge_SpellDB and BuffForge_SpellDB:GetSpell(spellID)
    local maxCharges = dbInfo and dbInfo.charges or 1
    sim.charges = sim.charges or maxCharges
    
    if sim.nextChargeTime and now >= sim.nextChargeTime then
        sim.charges = math.min(maxCharges, sim.charges + 1)
        if sim.charges < maxCharges then
            sim.nextChargeTime = sim.nextChargeTime + settings.simulatedCooldown
            sim.cdEnd = sim.nextChargeTime
        else
            sim.nextChargeTime = nil
            sim.cdEnd = nil
        end
    end
    
    if sim.state == "buff" and now >= sim.buffEnd then
        sim.state = "ready"
    end
    
    local icon = C_Spell.GetSpellTexture(spellID)
    
    if sim.state == "buff" then
        return {
            expirationTime = sim.buffEnd,
            duration = settings.simulatedBuffDuration,
            icon = icon,
            applications = sim.charges,
            isSimBuff = true,
            nextChargeTime = sim.nextChargeTime,
            chargeDuration = settings.simulatedCooldown
        }
    elseif sim.charges == 0 then
        sim.state = "cooldown"
        return {
            expirationTime = sim.nextChargeTime or 0,
            duration = settings.simulatedCooldown,
            icon = icon,
            applications = 0,
            isSimCD = true
        }
    elseif sim.charges < maxCharges then
        sim.state = "ready"
        return {
            expirationTime = sim.nextChargeTime or 0,
            duration = settings.simulatedCooldown,
            icon = icon,
            applications = sim.charges,
            isSimReady = true,
            isChargeCooldown = true
        }
    else
        sim.state = "ready"
        return {
            expirationTime = 0,
            duration = 0,
            icon = icon,
            applications = sim.charges,
            isSimReady = true
        }
    end
end

-- === SYSTEM LOOP ===
function addon:ScanAuras()
    local now = GetTime()
    local configOpen = addon.ConfigMode or (addon.Config and addon.Config.f and addon.Config.f:IsShown())
    
    for spellID, data in pairs(icons) do
        local settings = data.settings
        if not settings.enabled then 
            data.frame:Hide() 
        else
            -- 1. Check Simulated Mode
            local aura = nil
            if settings.simulatedMode then
                local sim = simulated[spellID]
                if sim and sim.nextChargeTime then
                    local now = GetTime()
                    if now >= sim.nextChargeTime then
                        sim.charges = (sim.charges or 0) + 1
                        local db = BuffForge_SpellDB and BuffForge_SpellDB:GetSpell(spellID)
                        local max = db and db.charges or 1
                        if sim.charges < max then
                            sim.nextChargeTime = sim.nextChargeTime + settings.simulatedCooldown
                            if sim.nextChargeTime < now then sim.nextChargeTime = now + settings.simulatedCooldown end
                            sim.cdEnd = sim.nextChargeTime
                        else
                            sim.nextChargeTime = nil
                            sim.cdEnd = nil
                        end
                    end
                end
                
                aura = CheckSimulatedState(spellID, settings)
                
                if aura and not (configOpen or settings.alwaysShow) then
                    local keep = false
                    if aura.isSimBuff then
                        keep = true
                    elseif aura.isSimCD then
                        local rem = aura.expirationTime - GetTime()
                        local cdThresh = settings.cdGlow and settings.cdGlow.threshold or 0
                        if settings.cdGlow and settings.cdGlow.enabled and cdThresh > 0 and rem <= cdThresh then
                             keep = true
                        end
                    elseif aura.isSimReady then
                        keep = false
                    end
                    if not keep then aura = nil end
                end
            end
            
            -- 2. Ask API
            if not aura then
                aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
            end
            
            local mem = memory[spellID]
            
            -- 3. Dead Reckoning
            if aura then
                mem.expirationTime = aura.expirationTime or 0
                mem.duration = aura.duration or 0
                mem.texture = aura.icon
                mem.count = aura.applications or 0
                mem.lastSeen = now
            elseif mem.expirationTime > now then
                 aura = {
                    expirationTime = mem.expirationTime,
                    duration = mem.duration,
                    icon = mem.texture,
                    applications = mem.count
                }
            end
            
            -- 4. CD / Always Show Logic
            local isOnCooldown = false
            local isSimBuff = aura and aura.isSimBuff
            local isSimCD = aura and aura.isSimCD
            
            local simCooldownInfo = nil
            if settings.simulatedMode then
                local sim = simulated[spellID]
                if sim and sim.cdEnd then
                    local now = GetTime()
                    if now < sim.cdEnd then
                        simCooldownInfo = {
                            expirationTime = sim.cdEnd,
                            duration = settings.simulatedCooldown,
                            startTime = now - (settings.simulatedCooldown - (sim.cdEnd - now))
                        }
                        if not sim.charges or sim.charges == 0 then
                            isOnCooldown = true
                        end
                    end
                end
            end
            
            local checkCD = settings.alwaysShow or configOpen
            local cdThresh = settings.cdGlow and settings.cdGlow.threshold or 0
            if not checkCD and settings.cdGlow and settings.cdGlow.enabled and cdThresh > 0 then checkCD = true end
            
            if not aura and checkCD then
                local start, dur = 0, 0
                local function CheckCD()
                    local info = C_Spell.GetSpellCooldown(spellID)
                    if info then
                        start = info.startTime
                        dur = info.duration
                        if start > 0 and dur > 1.5 then return true end
                    end
                    return false
                end
                
                local ok, isCD = pcall(CheckCD)
                
                if ok and isCD then
                     local exp = start + dur
                     local rem = exp - now
                     
                     local showCD = true
                     if not (settings.alwaysShow or configOpen) then
                        if not (settings.cdGlow and settings.cdGlow.enabled and cdThresh > 0 and rem <= cdThresh) then
                            showCD = false
                        end
                     end
                     
                     if showCD then
                         aura = {
                            expirationTime = exp,
                            duration = dur,
                            icon = C_Spell.GetSpellTexture(spellID),
                            applications = 0,
                            isCD = true
                        }
                        isOnCooldown = true
                     end
                else
                    if settings.alwaysShow or configOpen then
                        aura = {
                            expirationTime = 0,
                            duration = 0,
                            icon = C_Spell.GetSpellTexture(spellID),
                            applications = 0,
                            isCD = false
                        }
                    end
                end
            end
            
            -- 5. Update Visuals
            if aura then
                if not data.active then
                    data.frame:Show()
                    data.active = true
                end
                if configOpen then data.frame:SetAlpha(1) end
                
                local remaining = aura.expirationTime - now
                if remaining < 0 then remaining = 0 end
                if aura.duration == 0 then remaining = 1 end

                local borderR, borderG, borderB = unpack(settings.borderColor)
                
                -- === PRIORITY LOGIC FIX: BUFF > COOLDOWN ===
                if isSimBuff then
                    data.iconTex:SetDesaturated(false)
                    data.iconTex:SetVertexColor(1, 1, 1, 1)
                    if settings.showBorder then borderR, borderG, borderB = 0, 1, 0 end
                
                elseif isSimCD or (isOnCooldown and settings.desaturate) then
                    data.iconTex:SetDesaturated(true)
                    data.iconTex:SetVertexColor(0.5, 0.5, 0.5, 1)
                    if settings.showBorder then borderR, borderG, borderB = 1, 0, 0 end
                
                else
                    data.iconTex:SetDesaturated(false)
                    data.iconTex:SetVertexColor(1, 1, 1, 1)
                end
                -- ===========================================

                if settings.type == "bar" then
                    data.bar:SetMinMaxValues(0, math.max(aura.duration, 1))
                    data.bar:SetValue(remaining)
                    
                    local timeDisplay = format("%.1f", remaining)
                    if simCooldownInfo and isSimBuff then
                        local cdRemaining = simCooldownInfo.expirationTime - GetTime()
                        timeDisplay = format("%.1f (CD: %.0f)", remaining, cdRemaining)
                    end
                    
                    if isOnCooldown and (not isSimBuff) then
                        data.timeText:SetText(timeDisplay)
                        local r,g,b = unpack(Skin.Colors.textDim)
                        data.bar:SetStatusBarColor(r,g,b)
                    elseif aura.duration == 0 then
                        data.timeText:SetText("Active")
                        local r,g,b = unpack(settings.barColor)
                        data.bar:SetStatusBarColor(r,g,b)
                    else
                        data.timeText:SetText(timeDisplay)
                        local r,g,b = unpack(settings.barColor)
                        data.bar:SetStatusBarColor(r,g,b)
                    end
                    data.nameText:SetText(C_Spell.GetSpellName(spellID) or "")
                else 
                    if (aura.isCD or aura.isSimCD) and not isSimBuff then
                        data.cooldown:Show()
                        data.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                    else
                        data.cooldown:Hide()
                    end
                end
                
                if data.timerText then
                    if remaining > 0 then 
                        if remaining < 60 then
                            if remaining < 10 then data.timerText:SetText(format("%.1f", remaining))
                            else data.timerText:SetText(format("%.0f", remaining)) end
                        else
                            local m = math.floor(remaining / 60)
                            local s = remaining % 60
                            data.timerText:SetText(format("%d:%02d", m, s))
                        end
                    else
                        data.timerText:SetText("")
                    end
                end
                
                if aura.applications and aura.applications > 0 then
                    data.stackText:SetText(aura.applications)
                else
                    data.stackText:SetText("")
                end
                
                data.iconTex:SetTexture(aura.icon)
                
                -- NEW GLOW LOGIC (Signature Checked in GlowEngine)
                local desiredGlow = nil 
                
                -- 1. Check CD Glow
                if settings.cdGlow and settings.cdGlow.enabled then
                    if isOnCooldown or isSimCD then
                        local cdRemaining = aura.expirationTime - GetTime()
                        local thresh = settings.cdGlow.threshold or 0
                        if cdRemaining > 0 and cdRemaining <= thresh then
                            desiredGlow = settings.cdGlow
                        end
                    end
                end
                
                -- 2. Check Buff Glow (Prioritize Buff over CD)
                if settings.buffGlow and settings.buffGlow.enabled and isSimBuff then
                     local buffRemaining = aura.expirationTime - GetTime()
                     local thresh = settings.buffGlow.threshold or 0
                     if thresh == 0 then
                         desiredGlow = settings.buffGlow
                     elseif buffRemaining > 0 and buffRemaining <= thresh then
                         desiredGlow = settings.buffGlow
                     end
                end
                
                -- Update Visuals (GlowEngine will filter duplicates intelligently now)
                if desiredGlow then
                     addon:ToggleGlow(data.frame, true, desiredGlow)
                else
                     addon:ToggleGlow(data.frame, false)
                end
                
                if not desiredGlow and settings.showBorder then
                     data.frame:SetBackdropBorderColor(borderR, borderG, borderB, 1)
                elseif not desiredGlow then
                     data.frame:SetBackdropBorderColor(0,0,0,0)
                end
                
            else
                -- Hidden / Ghost
                if configOpen then
                    if not data.active then
                        data.frame:Show()
                        data.active = true
                    end
                    local info = C_Spell.GetSpellInfo(spellID)
                    local icon = info and info.iconID or 134400
                    data.iconTex:SetTexture(icon)
                    data.iconTex:SetDesaturated(false)
                    data.frame:SetAlpha(1)
                    if data.timerText then data.timerText:SetText("") end
                    if data.stackText then data.stackText:SetText("") end
                    if data.cooldown then data.cooldown:Hide() end
                    
                    addon:ToggleGlow(data.frame, false)
                else
                    if data.active then
                        data.frame:Hide()
                        data.active = false
                        addon:ToggleGlow(data.frame, false)
                    end
                end
            end
            
            if BuffForgeDB.global.anchorsUnlocked then
                data.frame:Show()
                data.mover:Show()
            else
                data.mover:Hide()
                if not aura and not configOpen then data.frame:Hide() end
            end
        end
    end
end

-- === BUILDER & REST OF CORE ===
function addon:UpdateIcon(id)
    if not BuffForgeDB then return end
    
    local key = GetCharKey()
    local profile = BuffForgeDB.profile[key] or {}
    local settings = profile[id]
    
    if not settings then 
        if icons[id] then
            icons[id].frame:Hide()
            icons[id] = nil
        end
        return 
    end
    
    setmetatable(settings, {__index = DEFAULT_SETTINGS})
    if not settings.cdGlow then settings.cdGlow = CopyTable(DEFAULT_SETTINGS.cdGlow) end
    if not settings.buffGlow then settings.buffGlow = CopyTable(DEFAULT_SETTINGS.buffGlow) end

     local data = icons[id]
     local f, mover
     
     if not data then
         f = CreateFrame("Frame", "BuffForgeFrame_"..id, UIParent, "BackdropTemplate")
         f:SetFrameStrata("LOW")
         f:SetMovable(true)
         f:SetClampedToScreen(true)
         Skin:ApplyBackdrop(f) 
         
         mover = CreateFrame("Frame", nil, f, "BackdropTemplate")
         mover:SetAllPoints()
         Skin:ApplyBackdrop(mover)
         mover:SetBackdropColor(0, 1, 0, 0.4) 
         mover:SetBackdropBorderColor(0, 1, 0, 1)
         
         mover:EnableMouse(true)
         mover:RegisterForDrag("LeftButton")
         mover:SetScript("OnDragStart", function(self) f:StartMoving() end)
         mover:SetScript("OnDragStop", function(self)
            f:StopMovingOrSizing()
            local point, _, relPoint, x, y = f:GetPoint()
            settings.point = point
            settings.relativePoint = relPoint
            settings.x = x
            settings.y = y
            if addon.Config and addon.Config.RefreshCurrentSpell then
                addon.Config:RefreshCurrentSpell(id)
            end
         end)
         
         local moveText = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
         moveText:SetPoint("CENTER")
         
         data = { frame=f, mover=mover, moveText=moveText, vizType=nil }
         icons[id] = data
          memory[id] = { expirationTime=0, duration=0, count=0, texture=134400, lastSeen=0 }
          simulated[id] = { state="ready", buffEnd=0, cdEnd=0 }
     else
         f = data.frame
         mover = data.mover
     end
     
     data.settings = settings
     data.moveText:SetText(C_Spell.GetSpellName(id) or id)
     
     -- Glow'u sıfırlamaya gerek yok, GlowEngine imza kontrolü yapacak.
     -- data.activeGlow silindi.
     
     local needRebuild = (data.vizType ~= settings.type)
     if needRebuild then
         if data.iconTex then data.iconTex:Hide() end
         if data.bar then data.bar:Hide() end
         if data.cooldown then data.cooldown:Hide() end
         
         if settings.type == "bar" then
             if not data.bar then
                 local iconTex = f:CreateTexture(nil, "ARTWORK")
                 iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                 local bar = CreateFrame("StatusBar", nil, f)
                 bar:SetStatusBarTexture(settings.barTexture or "Interface\\Buttons\\WHITE8x8")
                 local bg = bar:CreateTexture(nil, "BACKGROUND")
                 bg:SetAllPoints()
                 bg:SetColorTexture(unpack(Skin.Colors.bg)) 
                 Skin:ApplyBackdrop(bar)
                 local nameText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                 local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                 local stackText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                 data.iconTex = iconTex
                 data.bar = bar
                 data.nameText = nameText
                 data.timeText = timeText
                 data.stackText = stackText
             end
             data.iconTex:Show(); data.bar:Show(); data.nameText:Show(); data.timeText:Show(); data.stackText:Show()
             data.iconTex:ClearAllPoints()
             data.iconTex:SetPoint("TOPLEFT", 1, -1)
             data.iconTex:SetPoint("BOTTOMLEFT", 1, 1)
             data.bar:ClearAllPoints()
             data.bar:SetPoint("LEFT", data.iconTex, "RIGHT", 5, 0)
             data.bar:SetPoint("RIGHT", -1, 0) 
             data.bar:SetPoint("TOP", 0, -1)
             data.bar:SetPoint("BOTTOM", 0, 1)
             data.nameText:SetPoint("LEFT", 5, 0)
             data.timeText:SetPoint("RIGHT", -5, 0)
             data.stackText:SetPoint("CENTER", data.iconTex, "CENTER")
         else 
             if not data.cooldown then
                  local iconTex = f:CreateTexture(nil, "ARTWORK")
                  iconTex:SetPoint("TOPLEFT", 1, -1)
                  iconTex:SetPoint("BOTTOMRIGHT", -1, 1)
                  iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                  local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
                  cd:SetAllPoints(iconTex)
                  cd:SetHideCountdownNumbers(true) 
                  local stackText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                  stackText:SetPoint("BOTTOMRIGHT", -2, 2)
                  local timerText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                  timerText:SetPoint("CENTER", 0, 0)
                  data.iconTex = iconTex
                  data.cooldown = cd
                  data.stackText = stackText
                  data.timerText = timerText
             end
             data.iconTex:Show(); data.cooldown:Show(); data.stackText:Show(); data.timerText:Show()
         end
         data.vizType = settings.type
     end
     
     f:ClearAllPoints()
     f:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
     
     if settings.type == "bar" then
         f:SetSize(settings.width, settings.size)
         if data.iconTex then data.iconTex:SetWidth(settings.size - 2) end
         if data.bar then data.bar:SetStatusBarColor(unpack(settings.barColor)) end
     else
         f:SetSize(settings.size, settings.size)
     end
     
     if settings.showBorder then Skin:SetBorder(f, settings.borderThickness, settings.borderColor)
     else Skin:HideBorder(f) end
     f:SetBackdropColor(unpack(Skin.Colors.bg))
     
     if addon.GlowEngine then addon.GlowEngine.Stop(f) end
    if BuffForgeDB.global.anchorsUnlocked then f:Show(); mover:Show() else mover:Hide() end
end

-- === VISUAL EFFECTS ENGINE (UPDATED) ===
function addon:ToggleGlow(frame, show, settings)
    if not frame or not addon.GlowEngine then return end
    
    if show and settings then
        addon.GlowEngine:Show(frame, settings.type, settings) 
    else
        addon.GlowEngine:Stop(frame)
    end
end

function addon:RebuildIcons()
    if not BuffForgeDB then return end
    local key = GetCharKey()
    local profile = BuffForgeDB.profile[key] or {}
    local activeIDs = {}
    for id, _ in pairs(profile) do
        local numID = tonumber(id)
        if numID then activeIDs[numID] = true; addon:UpdateIcon(numID)
        else activeIDs[id] = true; addon:UpdateIcon(id) end
    end
    local toRemove = {}
    for id, data in pairs(icons) do
        local numID = tonumber(id)
        if not (activeIDs[numID] or activeIDs[id]) then table.insert(toRemove, id) end
    end
    for _, id in ipairs(toRemove) do
        local data = icons[id]
        if data then data.frame:Hide(); if data.mover then data.mover:Hide() end; icons[id] = nil end
    end
end

function addon:ToggleAnchors()
    BuffForgeDB.global.anchorsUnlocked = not BuffForgeDB.global.anchorsUnlocked
    addon:RebuildIcons()
    if BuffForgeDB.global.anchorsUnlocked then print("|cff00ff00BuffForge:|r Anchors Unlocked.")
    else print("|cff00ff00BuffForge:|r Anchors Locked.") end
end

-- === SYNC COOLDOWNS (MOVED OUT OF EVENT LOOP - FIX) ===
function addon:SyncCooldowns(reason)
    if not icons then return end
    for id, data in pairs(icons) do
        local settings = data.settings
        if settings and settings.simulatedMode then
            local info = C_Spell.GetSpellCooldown(id)
            if info and info.duration > 1.5 then
                 if not simulated[id] then simulated[id] = {} end
                 simulated[id].cdEnd = info.startTime + info.duration
                 simulated[id].state = "cooldown"
                 if settings and info.duration > 2 and math.abs((settings.simulatedCooldown or 0) - info.duration) > 0.5 then
                     settings.simulatedCooldown = info.duration
                     if addon.Config then addon.Config:RefreshCurrentSpell(id) end
                 end
                 local chargeInfo = C_Spell.GetSpellCharges(id)
                 if chargeInfo then
                     simulated[id].charges = chargeInfo.currentCharges
                     simulated[id].nextChargeTime = chargeInfo.cooldownStartTime + chargeInfo.cooldownDuration
                 else simulated[id].charges = 0 end
            elseif simulated[id] then
                 simulated[id].cdEnd = 0
                 simulated[id].state = "ready"
                 local db = BuffForge_SpellDB and BuffForge_SpellDB:GetSpell(id)
                 simulated[id].charges = db and db.charges or 1
                 simulated[id].nextChargeTime = nil
            end
        end
    end
end

-- === EVENTS ===
local castEv = CreateFrame("Frame")
castEv:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castEv:RegisterEvent("UNIT_SPELLCAST_SENT")
castEv:RegisterEvent("PLAYER_REGEN_ENABLED")
castEv:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
castEv:RegisterEvent("PLAYER_ENTERING_WORLD")
local rimeState = { active = false, lastRemove = 0 }

castEv:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function() addon:SyncCooldowns("Reload/Login") end)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then addon:SyncCooldowns("Combat Exit"); return end

    if event == "UNIT_SPELLCAST_SENT" and arg1 == "player" then
        if arg4 == 49184 then
             local costs = C_Spell.GetSpellPowerCost(arg4)
             local runeCost = 0
             if costs then for _, c in ipairs(costs) do if c.type == 5 then runeCost = runeCost + c.cost end end end
             rimeState.active = (runeCost == 0)
        end
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        addon:RebuildIcons()
        if addon.Config and addon.Config.f and addon.Config.f:IsShown() then
             addon.Config:SelectTab("Spells")
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        local spellID = arg3
        if spellID == 49184 and rimeState.active then
            local erwID = 47568
            local sim = simulated[erwID]
            if sim and sim.nextChargeTime and (sim.charges or 0) < 2 then
               sim.nextChargeTime = sim.nextChargeTime - 6
               if sim.nextChargeTime < GetTime() then sim.nextChargeTime = GetTime() end
               sim.cdEnd = sim.nextChargeTime
            end
        end
        local data = icons[spellID]
        if not data then return end
        local settings = data.settings
        C_Timer.After(0.2, function()
            local success, err = pcall(function()
                local cdInfo = C_Spell.GetSpellCooldown(spellID)
                if cdInfo then
                    local dur = cdInfo.duration
                    if dur and type(dur) == "number" and dur > 1.5 then
                         if not InCombatLockdown() then addon:LearnSpellData(spellID, "cd", dur) end
                         if settings.simulatedMode and math.abs((settings.simulatedCooldown or 0) - dur) > 0.1 then
                             settings.simulatedCooldown = dur
                             if addon.Config then addon.Config:RefreshCurrentSpell(spellID) end
                         end
                    end
                end
                local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                if aura then
                    local buffDur = aura.duration
                    if buffDur and buffDur > 0 then
                         if not InCombatLockdown() then addon:LearnSpellData(spellID, "buff", buffDur) end
                        if settings.simulatedMode and math.abs((settings.simulatedBuffDuration or 0) - buffDur) > 0.1 then
                             settings.simulatedBuffDuration = buffDur
                             if addon.Config then addon.Config:RefreshCurrentSpell(spellID) end
                        end
                    end
                else
                     if settings.simulatedMode and (not settings.simulatedBuffDuration or settings.simulatedBuffDuration == 0) then
                         local dbDuration = addon:GetDurationFromDB(spellID)
                         if dbDuration > 0 then settings.simulatedBuffDuration = dbDuration end
                     end
                end
            end)
        end)
        if not settings.simulatedMode then return end
        local sim = simulated[spellID]
        if not sim then sim = {}; simulated[spellID] = sim end
        local now = GetTime()
        local dbInfo = BuffForge_SpellDB and BuffForge_SpellDB:GetSpell(spellID)
        local maxCharges = dbInfo and dbInfo.charges or 1
        sim.charges = sim.charges or maxCharges
        if sim.charges > 0 then sim.charges = sim.charges - 1 end
        sim.state = "buff"
        sim.buffEnd = now + settings.simulatedBuffDuration
        if sim.charges < maxCharges then
            if not sim.nextChargeTime or sim.nextChargeTime < now then sim.nextChargeTime = now + settings.simulatedCooldown end
            sim.cdEnd = sim.nextChargeTime
        end
    end
end)

-- === INIT ===
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        BuffForgeDB = BuffForgeDB or CopyTable(defaults)
        BuffForgeDB.profile = BuffForgeDB.profile or {}
        BuffForgeDB.global = BuffForgeDB.global or {}
        BuffForgeDB.global.learnedDB = BuffForgeDB.global.learnedDB or {}
        
        local oldKey = UnitName("player") .. "-" .. GetRealmName()
        if BuffForgeDB.profile[oldKey] then
            local newKey = GetCharKey()
            if not BuffForgeDB.profile[newKey] then
                BuffForgeDB.profile[newKey] = CopyTable(BuffForgeDB.profile[oldKey])
            end
        end
        addon:RebuildIcons()
        print("|cff00ff00BuffForge:|r Loaded. /bf5g to config.")
    end
end)

local timer = CreateFrame("Frame")
local elapsed = 0
timer:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed > 0.1 then
        elapsed = 0
        local ok, err = pcall(addon.ScanAuras, addon) 
        if not ok and not timer.hasErrored then
            print("|cffff0000BuffForge Error (OnUpdate):|r " .. tostring(err))
            timer.hasErrored = true
        end
    end
end)

function addon:CreateMinimapButton()
    local b = CreateFrame("Button", "BuffForgeMinimapButton", Minimap)
    b:SetSize(32, 32)
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local overlay = b:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\Inv_hammer_20")
    icon:SetPoint("CENTER", 0, 1)
    
    local function UpdatePos()
        local angle = math.rad(BuffForgeDB.global.minimap.minimapPos or 225)
        local cos, sin = math.cos(angle), math.sin(angle)
        local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
        local radius = 80
        if minimapShape == "SQUARE" then
            local x, y = cos * radius, sin * radius
            x = math.max(-radius, math.min(radius, x))
            y = math.max(-radius, math.min(radius, y))
            b:SetPoint("CENTER", "Minimap", "CENTER", x, y)
        else
            b:SetPoint("CENTER", "Minimap", "CENTER", cos * radius, sin * radius)
        end
    end
    b:SetScript("OnDragStart", function(self)
        self:LockHighlight(); self.isDragging = true
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local deg = math.deg(math.atan2(cy - my, cx - mx))
            if deg < 0 then deg = deg + 360 end
            BuffForgeDB.global.minimap.minimapPos = deg
            UpdatePos()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:UnlockHighlight(); self:SetScript("OnUpdate", nil); self.isDragging = false end)
    b:SetScript("OnClick", function(self) if addon.Config then addon.Config:Toggle() end end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("BuffForge 5G")
        GameTooltip:AddLine("Click: Settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    addon.MinimapButton = b
    UpdatePos()
    addon:ToggleMinimapButton(not BuffForgeDB.global.minimap.hide)
end

function addon:ToggleMinimapButton(show)
    if not addon.MinimapButton then addon:CreateMinimapButton() end
    BuffForgeDB.global.minimap.hide = not show
    if show then addon.MinimapButton:Show() else addon.MinimapButton:Hide() end
end

local loginEv = CreateFrame("Frame")
loginEv:RegisterEvent("PLAYER_LOGIN")
loginEv:SetScript("OnEvent", function()
    C_Timer.After(1.5, function() if addon.RebuildIcons then addon:RebuildIcons() end end)
    if BuffForgeDB then
        BuffForgeDB.global.minimap = BuffForgeDB.global.minimap or { hide = false, minimapPos = 220 }
        addon:CreateMinimapButton()
    end
end)

SLASH_BUFFFORGE1 = "/bf5g"
SlashCmdList["BUFFFORGE"] = function() if addon.Config then addon.Config:Toggle() end end