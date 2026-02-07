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
        minimap = { hide = false, minimapPos = 220 } -- Default position
    }
}

-- Default settings for a new spell
local DEFAULT_SETTINGS = {
    enabled = true,
    type = "icon", -- "icon" or "bar"
    
    -- Positioning
    point = "CENTER",
    relativeTo = "UIParent",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    
    -- Dimensions
    size = 40,      -- Icon size (or height if bar)
    width = 200,    -- Bar width
    
    -- Visuals
    font = Skin.Constants.FONT_NORMAL,
    fontSize = Skin.Constants.FONT_SIZE_NORMAL,
    showBorder = true,
    borderColor = Skin.Colors.border, -- Use Skin border color default
    
    -- Bar Specific
    barColor = Skin.Colors.normal or {0.2, 0.8, 0.2, 1}, -- Use Skin normal/ready color
    barTexture = "Interface\\Buttons\\WHITE8x8",
    
    -- Behavior
    alwaysShow = false, -- Show when missing (track CD) or ready
    threshold = 0,      -- Glow/Color change time
    thresholdColor = Skin.Colors.cd, -- Use Skin CD color
    glow = false,       -- Glow when active/proc
    desaturate = true,  -- Grey out on CD
    
    -- Manual Simulation
    simulatedMode = false,      -- Use manual tracking instead of API
    simulatedBuffDuration = 0,  -- Manual buff duration (seconds)
    simulatedCooldown = 0,      -- Manual cooldown duration (seconds)
}

local icons = {} -- [spellID] = { frame=..., settings=... }
local memory = {} -- Dead Reckoning support
local simulated = {} -- [spellID] = { state="ready"|"buff"|"cooldown", buffEnd=time, cdEnd=time }

-- === UTILS ===
local function GetCharKey()
    -- Key now includes Spec ID to separate profiles per spec
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or 0
    return UnitName("player") .. "-" .. GetRealmName() .. "-" .. specID
end

-- === DATABASE LEARNED DATA ===
function addon:LearnSpellData(spellID, key, value)
    if not BuffForgeDB then return end
    
    -- Structure: BuffForgeDB.global.learnedDB[specID][spellID] = { buff=x, cd=y }
    
    -- Get Current Spec ID (Clean)
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or 0
    
    BuffForgeDB.global.learnedDB = BuffForgeDB.global.learnedDB or {}
    BuffForgeDB.global.learnedDB[specID] = BuffForgeDB.global.learnedDB[specID] or {}
    local db = BuffForgeDB.global.learnedDB[specID]
    
    db[spellID] = db[spellID] or {}
    
    -- Only update if value is valid and different
    if value and value > 0 then
        if db[spellID][key] ~= value then
            db[spellID][key] = value
            -- print(format("BuffForge Learned: %s for %s = %.1fs", key, (C_Spell.GetSpellName(spellID) or spellID), value))
        end
    end
end

function addon:GetSpellData(spellID)
    local data = { buff_duration=0, cooldown=0, name="", icon=134400, charges=1 }
    
    -- 1. Static DB (Base)
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
    
    -- 2. Learned DB (Override)
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
    -- Refactored to use GetSpellData
    local data = addon:GetSpellData(spellID)
    local duration = data.buff_duration
    
    -- Check Talents (Only applies if we are using Static/Base data or if we want to add talents ON TOP of learned? 
    -- Learned duration usually comes from Aura duration which INCLUDES talents.
    -- So if we have learned data, we might not need to add talents again.
    -- Logic: If we learned 'buff', trust it. If not, calculate from Base + Talents.
    
    -- Check if we have learned data
    local isLearned = false
    if BuffForgeDB and BuffForgeDB.global and BuffForgeDB.global.learnedDB then
        local specIndex = GetSpecialization()
        local specID = specIndex and GetSpecializationInfo(specIndex) or 0
        local learned = BuffForgeDB.global.learnedDB[specID] and BuffForgeDB.global.learnedDB[specID][spellID]
        if learned and learned.buff and learned.buff > 0 then isLearned = true end
    end
    
    if isLearned then return duration end -- Return learned (which includes talents)
    
    -- Else calculate from Static + Talents
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
    
    -- 1. Recharge Logic
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
    
    -- 2. State Logic
    if sim.state == "buff" and now >= sim.buffEnd then
        sim.state = "ready"
    end
    
    -- 3. Return Data
    local icon = C_Spell.GetSpellTexture(spellID)
    
    if sim.state == "buff" then
        return {
            expirationTime = sim.buffEnd,
            duration = settings.simulatedBuffDuration,
            icon = icon,
            applications = sim.charges,
            isSimBuff = true,
            -- Pass recharge info if needed
            nextChargeTime = sim.nextChargeTime,
            chargeDuration = settings.simulatedCooldown
        }
    elseif sim.charges == 0 then
        -- No charges = Cooldown
        sim.state = "cooldown"
        return {
            expirationTime = sim.nextChargeTime or 0,
            duration = settings.simulatedCooldown,
            icon = icon,
            applications = 0,
            isSimCD = true
        }
    elseif sim.charges < maxCharges then
        -- Has charges but recharging = Ready with Swipe
        sim.state = "ready"
        return {
            expirationTime = sim.nextChargeTime or 0,
            duration = settings.simulatedCooldown,
            icon = icon,
            applications = sim.charges,
            isSimReady = true,
            isChargeCooldown = true -- Flag to show swipe
        }
    else
        -- Full charges
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
local function ScanAuras()
    local now = GetTime()
    local configOpen = addon.Config and addon.Config.f and addon.Config.f:IsShown()
    
    for spellID, data in pairs(icons) do
        local settings = data.settings
        if not settings.enabled then 
            data.frame:Hide() 
        else
            -- 1. Check Simulated Mode First
            local aura = nil
            if settings.simulatedMode then
                -- RECHARGE UPDATE LOGIC
                local sim = simulated[spellID]
                if sim and sim.nextChargeTime then
                    local now = GetTime()
                    if now >= sim.nextChargeTime then
                        sim.charges = (sim.charges or 0) + 1
                        
                        -- Max Charges Check
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
                
                -- Visibility Filtering for Simulated Mode
                if aura and not (configOpen or settings.alwaysShow) then
                    local keep = false
                    if aura.isSimBuff then
                        keep = true
                    elseif aura.isSimCD then
                        -- Only show if within threshold
                        local rem = aura.expirationTime - GetTime()
                        if settings.threshold and settings.threshold > 0 and rem <= settings.threshold then
                            keep = true
                        end
                    elseif aura.isSimReady then
                        -- Hide ready state if not alwaysShow
                        keep = false
                    end
                    if not keep then aura = nil end
                end
            end
            
            -- 2. Ask API (if not simulated or as fallback)
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
                 -- Simulating active buff (latency/update gap)
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
            local isSimReady = aura and aura.isSimReady
            
            -- CRITICAL: Check simulated cooldown even when buff is active!
            local simCooldownInfo = nil
            if settings.simulatedMode then
                local sim = simulated[spellID]
                if sim and sim.cdEnd then
                    local now = GetTime()
                    if now < sim.cdEnd then
                        -- Cooldown is running!
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
            
            -- Check for CD if: No Aura AND (AlwaysShow OR ConfigOpen OR Threshold set)
            local checkCD = settings.alwaysShow or configOpen
            if not checkCD and settings.threshold and settings.threshold > 0 then checkCD = true end
            
            if not aura and checkCD then
                local start, dur = 0, 0
                local cdInfoSuccess = false
                
                -- Function to safely check CD
                local function CheckCD()
                    local info = C_Spell.GetSpellCooldown(spellID)
                    if info then
                        start = info.startTime
                        dur = info.duration
                        -- Trigger comparison to catch secret values here
                        if start > 0 and dur > 1.5 then
                            return true -- It IS on cooldown
                        end
                    end
                    return false
                end
                
                -- Run in pcall
                local ok, isCD = pcall(CheckCD)
                
                if ok and isCD then
                     -- ON CD
                     local exp = start + dur
                     local rem = exp - now
                     
                     -- Visibility Check for CD
                     local showCD = true
                     if not (settings.alwaysShow or configOpen) then
                        -- Only show if within threshold
                        if not (settings.threshold and settings.threshold > 0 and rem <= settings.threshold) then
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
                    -- READY or Error
                    -- Only show "Ready" if AlwaysShow/Config
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
                
                local remaining = aura.expirationTime - now
                if remaining < 0 then remaining = 0 end
                if aura.duration == 0 then remaining = 1 end -- infinite

                -- Desaturation & Color
                -- Desaturation & Color (White icons, colored borders instead)
                local borderR, borderG, borderB = unpack(settings.borderColor)
                
                if isSimCD or (isOnCooldown and settings.desaturate) then
                    data.iconTex:SetDesaturated(true)
                    data.iconTex:SetVertexColor(0.5, 0.5, 0.5, 1) -- Darker grey for CD
                    if settings.showBorder then borderR, borderG, borderB = 1, 0, 0 end -- Red Border
                elseif isSimBuff then
                    data.iconTex:SetDesaturated(false)
                    data.iconTex:SetVertexColor(1, 1, 1, 1) -- White (Clean)
                    if settings.showBorder then borderR, borderG, borderB = 0, 1, 0 end -- Green Border
                elseif isSimReady then
                    data.iconTex:SetDesaturated(false)
                    data.iconTex:SetVertexColor(1, 1, 1, 1) -- White (Clean)
                    -- Default border for ready
                else
                    data.iconTex:SetDesaturated(false)
                    data.iconTex:SetVertexColor(1, 1, 1, 1)
                end

                -- Visualize
                if settings.type == "bar" then
                    data.bar:SetMinMaxValues(0, math.max(aura.duration, 1))
                    data.bar:SetValue(remaining)
                    
                    -- Show cooldown timer even when buff is active
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
                
                else -- ICON
                -- Update Cooldown Swipe
                    if aura.isCD or aura.isSimCD then
                        data.cooldown:Show()
                        data.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                    else
                        -- Active Buff: Hide swipe to prevent overlap with text
                        data.cooldown:Hide()
                    end
                end
                
                -- Reliable Timer Text Logic
                if data.timerText then
                    if remaining > 0 then 
                        if remaining < 60 then
                            -- Seconds
                            if remaining < 10 then
                                data.timerText:SetText(format("%.1f", remaining))
                            else
                                data.timerText:SetText(format("%.0f", remaining))
                            end
                        else
                            -- Minutes:Seconds
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
                
                -- GLOW THRESHOLD: Alert player when CD is almost ready OR buff is active
                local shouldGlow = false
                
                -- Check cooldown glow
                if settings.threshold and settings.threshold > 0 then
                    if isOnCooldown or isSimCD then
                        local cdRemaining = aura.expirationTime - GetTime()
                        if cdRemaining > 0 and cdRemaining <= settings.threshold then
                            shouldGlow = true
                        end
                    end
                end
                
                -- Check buff glow (only if buffThreshold is set AND > 0)
                if settings.buffThreshold and settings.buffThreshold > 0 and isSimBuff then
                    local buffRemaining = aura.expirationTime - GetTime()
                    if buffRemaining > 0 and buffRemaining <= settings.buffThreshold then
                        -- Glow only when buff is about to expire
                        shouldGlow = true
                    end
                end
                
                -- Apply/remove glow (custom implementation)
                -- Apply/remove glow (Visual Effect Engine)
                -- Apply/remove glow (Visual Effect Engine)
                addon:ToggleGlow(data.frame, shouldGlow, settings.visualEffect, settings.effectColor)
                
                if not shouldGlow then
                    -- Fallback cleanup for old glow system if data persists
                    if data.isGlowing then
                        if data.glowAnimation then data.glowAnimation:Stop() end
                        data.isGlowing = false
                    end
                    
                    -- Always update dynamic border when not glowing
                    if settings.showBorder then
                        data.frame:SetBackdropBorderColor(borderR, borderG, borderB, 1)
                    else
                        data.frame:SetBackdropBorderColor(0,0,0,0)
                    end
                end
                
            else
                -- Hidden
                if data.active then
                    data.frame:Hide()
                    data.active = false
                    -- Clean up glow
                    if data.isGlowing then
                        if data.glowAnimation then
                            data.glowAnimation:Stop()
                        end
                        data.isGlowing = false
                    end
                end
            end
            
            -- Anchor Check (Mover) should always be shown if unlocked
            if BuffForgeDB.global.anchorsUnlocked then
                data.frame:Show()
                data.mover:Show()
            else
                data.mover:Hide()
                if not aura then data.frame:Hide() end
            end
        end
    end
end

-- === BUILDER ===
-- === DATABASE HELPER (BUFF DURATION & TALENTS) ===
function addon:GetDurationFromDB(spellID)
    if not BuffForge_SpellDB then return 0 end
    local data = BuffForge_SpellDB:GetSpell(spellID)
    if not data or not data.buff_duration then return 0 end
    
    local duration = data.buff_duration
    
    -- Check Talents
    if data.talents then
        for _, talent in ipairs(data.talents) do
            -- Check for duration_bonus and if player has the talent (IsPlayerSpell checks if spell is learned)
            if talent.duration_bonus and talent.spell_id and IsPlayerSpell(talent.spell_id) then
                duration = duration + talent.duration_bonus
                -- print("BuffForge Debug: Talent detected ("..talent.name.."), + " .. talent.duration_bonus .. "s")
            end
        end
    end
    
    return duration
end

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
    
    -- Apply defaults
    setmetatable(settings, {__index = DEFAULT_SETTINGS})
     
     local data = icons[id]
     local f, mover
     
     -- === PHASE 1: INITIALIZATION (Only Once) ===
     if not data then
         -- Create Main Frame
         f = CreateFrame("Frame", "BuffForgeFrame_"..id, UIParent, "BackdropTemplate")
         f:SetFrameStrata("LOW")
         f:SetMovable(true)
         f:SetClampedToScreen(true)
         
         Skin:ApplyBackdrop(f) -- Base skin
         
         -- Create Mover
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
            -- Refresh config if open to update slider values
            if addon.Config and addon.Config.RefreshCurrentSpell then
                addon.Config:RefreshCurrentSpell(id)
            end
         end)
         
         local moveText = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
         moveText:SetPoint("CENTER")
         
         data = { frame=f, mover=mover, moveText=moveText, vizType=nil }
         icons[id] = data
         
          -- Init memory
          memory[id] = { expirationTime=0, duration=0, count=0, texture=134400, lastSeen=0 }
          simulated[id] = { state="ready", buffEnd=0, cdEnd=0 }
     else
         f = data.frame
         mover = data.mover
     end
     
     data.settings = settings
     data.moveText:SetText(C_Spell.GetSpellName(id) or id)
     
     -- === PHASE 2: VISUAL STRUCTURE (Rebuild only if Type changes) ===
     local needRebuild = (data.vizType ~= settings.type)
     
     if needRebuild then
         if data.iconTex then data.iconTex:Hide() end
         if data.bar then data.bar:Hide() end
         if data.cooldown then data.cooldown:Hide() end
         
         if settings.type == "bar" then
             -- BUILD BAR MODE
             if not data.bar then
                 local iconTex = f:CreateTexture(nil, "ARTWORK")
                 iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                 
                 local bar = CreateFrame("StatusBar", nil, f)
                 bar:SetStatusBarTexture(settings.barTexture or "Interface\\Buttons\\WHITE8x8") -- Fallback if nil
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
             
             data.iconTex:Show()
             data.bar:Show()
             data.nameText:Show()
             data.timeText:Show()
             data.stackText:Show()
             
             -- Static Anchor Setup for Bar
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
             -- BUILD ICON MODE
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
             
             data.iconTex:Show()
             data.cooldown:Show()
             data.stackText:Show()
             data.timerText:Show()
         end
         
         data.vizType = settings.type
     end
     
     -- === PHASE 3: LIGHTWEIGHT UPDATE (Position, Size, Colors) ===
     -- This runs every time a slider moves
     
     -- 1. Position
     f:ClearAllPoints()
     f:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
     
     -- 2. Size
     if settings.type == "bar" then
         f:SetSize(settings.width, settings.size)
         if data.iconTex then data.iconTex:SetWidth(settings.size - 2) end -- Adjust icon width matches height
         if data.bar then data.bar:SetStatusBarColor(unpack(settings.barColor)) end
     else
         f:SetSize(settings.size, settings.size)
     end
     
     -- 3. Visuals
     if settings.showBorder then 
         Skin:SetBorder(f, settings.borderThickness, settings.borderColor)
     else 
         Skin:HideBorder(f)
     end
     
     f:SetBackdropColor(unpack(Skin.Colors.bg))
     
     -- 4. Visual Effects Cleanup (Reset on Config Change)
     if addon.GlowEngine then addon.GlowEngine.Stop(f) end

    -- Show movers if unlocked 
    if BuffForgeDB.global.anchorsUnlocked then
        f:Show()
        mover:Show()
    else
        mover:Hide()
    end
end

-- === VISUAL EFFECTS ENGINE ===
-- Wrapper for GlowEngine (LibButtonGlow / Custom)
function addon:ToggleGlow(frame, show, type, color)
    if not frame or not addon.GlowEngine then return end
    
    -- Color standardization (LibButtonGlow ignores color usually, but we pass it anyway)
    local c = {r=1, g=1, b=0, a=1}
    if color then
        if color.r then c = color 
        elseif #color >= 3 then c = {r=color[1], g=color[2], b=color[3], a=color[4] or 1} end
    end
    
    local showType = "button" -- Default
    
    if type == "glow" then showType = "button"
    elseif type == "pixel" then showType = "pixel"
    elseif type == "ants" then showType = "autocast"
    elseif type == "autocast" then showType = "autocast"
    elseif type == "sparkle" then showType = "pixel" -- Map Sparkle to Pixel
    elseif type == "pulse" then showType = "pulse"
    else showType = "button" end 
    
    if show then
        addon.GlowEngine:Show(frame, showType, c)
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
        if numID then
            activeIDs[numID] = true
            addon:UpdateIcon(numID)
        else
            -- Fallback for string keys if any
            activeIDs[id] = true
            addon:UpdateIcon(id)
        end
    end
    
    -- Cleanup removed
    -- Iterate safely: Mark for removal first
    local toRemove = {}
    for id, data in pairs(icons) do
        local numID = tonumber(id)
        -- Check both number and exact key match
        if not (activeIDs[numID] or activeIDs[id]) then
             table.insert(toRemove, id)
        end
    end
    
    for _, id in ipairs(toRemove) do
        local data = icons[id]
        if data then
            data.frame:Hide()
            if data.mover then data.mover:Hide() end -- Explicitly hide mover
            icons[id] = nil
        end
    end
end

function addon:ToggleAnchors()
    BuffForgeDB.global.anchorsUnlocked = not BuffForgeDB.global.anchorsUnlocked
    addon:RebuildIcons() -- Simplest way to refresh visibility state
    if BuffForgeDB.global.anchorsUnlocked then
        print("|cff00ff00BuffForge:|r Anchors Unlocked.")
    else
        print("|cff00ff00BuffForge:|r Anchors Locked.")
    end
end

-- === SPELL CAST DETECTION ===
-- === SPELL CAST DETECTION ===
-- SYNC LOGIC (Shared)
function addon:SyncCooldowns(reason)
    if not icons then return end
    local count = 0
    for id, data in pairs(icons) do
        local settings = data.settings
        if settings and settings.simulatedMode then
            local info = C_Spell.GetSpellCooldown(id)
            if info and info.duration > 1.5 then
                 -- Sync CD
                 if not simulated[id] then simulated[id] = {} end
                 simulated[id].cdEnd = info.startTime + info.duration
                 simulated[id].state = "cooldown"
                 count = count + 1
                 
                 -- Catch-up logic
                 if settings and info.duration > 2 and math.abs((settings.simulatedCooldown or 0) - info.duration) > 0.5 then
                     settings.simulatedCooldown = info.duration
                     if addon.Config then addon.Config:RefreshCurrentSpell(id) end
                 end

                 -- Check Charges
                 local chargeInfo = C_Spell.GetSpellCharges(id)
                 if chargeInfo then
                     simulated[id].charges = chargeInfo.currentCharges
                     simulated[id].nextChargeTime = chargeInfo.cooldownStartTime + chargeInfo.cooldownDuration
                 else
                     simulated[id].charges = 0
                 end
            elseif simulated[id] then
                 -- Ready
                 simulated[id].cdEnd = 0
                 simulated[id].state = "ready"
                 local db = BuffForge_SpellDB and BuffForge_SpellDB:GetSpell(id)
                 simulated[id].charges = db and db.charges or 1
                 simulated[id].nextChargeTime = nil
            end
        end
    end
    if count > 0 then
        -- print("|cff00ff00BuffForge:|r Synced "..count.." Cooldowns ("..reason..").")
    end
end

-- === SPELL CAST DETECTION ===
local castEv = CreateFrame("Frame")
castEv:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castEv:RegisterEvent("UNIT_SPELLCAST_SENT")
castEv:RegisterEvent("PLAYER_REGEN_ENABLED")
castEv:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
castEv:RegisterEvent("PLAYER_ENTERING_WORLD") -- Ensure checking on load

-- Rime Tracking Cache
local rimeState = { active = false, lastRemove = 0 }

castEv:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    -- SYNC ON LOGIN / RELOAD
    if event == "PLAYER_ENTERING_WORLD" then
        -- Delay to ensure spell info is ready
        C_Timer.After(2, function() addon:SyncCooldowns("Reload/Login") end)
        return
    end

    -- SYNC ON COMBAT EXIT
    if event == "PLAYER_REGEN_ENABLED" then
        addon:SyncCooldowns("Combat Exit")
        return
    end

    -- TRACK RIME (Method: Rune Cost)
    -- Technical Detection: If HB costs 0 runes, it is powered by Rime.

    -- Cost Check
    if event == "UNIT_SPELLCAST_SENT" and arg1 == "player" then
        local spellID = arg4 -- arg4 is spellID for SENT
        if spellID == 49184 then

             -- Check Rune Cost
             local costs = C_Spell.GetSpellPowerCost(spellID)
             local runeCost = 0
             if costs then
                 for _, c in ipairs(costs) do
                     if c.type == 5 then -- 5 = Runes
                         runeCost = runeCost + c.cost
                     end
                 end
             end
             -- If Rune Cost is 0, it is Rime!
             rimeState.active = (runeCost == 0)
             if rimeState.active then
                 -- print("BuffForge Debug: HB Sent with 0 Runes (Rime Detected!)")
             end
        end
        return
    end

    -- SPEC SWITCH
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        addon:RebuildIcons()
        if addon.Config and addon.Config.Toggle and addon.Config.f and addon.Config.f:IsShown() then
             addon.Config:SelectTab("Spells")
             print("|cff00ff00BuffForge:|r Profile Swapped (Spec Changed).")
        end
        return
    end

    -- SYNC LOGIC (Shared)
    function addon:SyncCooldowns(reason)
        if not icons then return end
        local count = 0
        for id, data in pairs(icons) do
            local settings = data.settings
            if settings and settings.simulatedMode then
                local info = C_Spell.GetSpellCooldown(id)
                if info and info.duration > 1.5 then
                     -- Sync CD
                     if not simulated[id] then simulated[id] = {} end
                     simulated[id].cdEnd = info.startTime + info.duration
                     simulated[id].state = "cooldown"
                     count = count + 1
                     
                     -- CRITICAL: Update Settings if missing/wrong (Catch-up)
                     -- Only update if Duration > 0 and difference is significant and we are tracking it
                     if settings and info.duration > 2 and math.abs((settings.simulatedCooldown or 0) - info.duration) > 0.5 then
                         -- Safety: Don't overwrite if not in manual mode logic
                         settings.simulatedCooldown = info.duration
                         -- print(format("|cff00ff00BuffForge:|r Auto-detected CD [%s] for %s: %.1fs", reason, C_Spell.GetSpellName(id) or id, info.duration))
                         if addon.Config then addon.Config:RefreshCurrentSpell(id) end
                     end

                     -- Check Charges
                     local chargeInfo = C_Spell.GetSpellCharges(id)
                     if chargeInfo then
                         simulated[id].charges = chargeInfo.currentCharges
                         simulated[id].nextChargeTime = chargeInfo.cooldownStartTime + chargeInfo.cooldownDuration
                     else
                         simulated[id].charges = 0
                     end
                elseif simulated[id] then
                     -- Ready
                     simulated[id].cdEnd = 0
                     simulated[id].state = "ready"
                     local db = BuffForge_SpellDB and BuffForge_SpellDB:GetSpell(id)
                     simulated[id].charges = db and db.charges or 1
                     simulated[id].nextChargeTime = nil
                end
            end
        end
        if count > 0 then
            print("|cff00ff00BuffForge:|r Synced "..count.." Cooldowns ("..reason..").")
        end
    end

    -- SYNC ON COMBAT EXIT
    if event == "PLAYER_REGEN_ENABLED" then
        addon:SyncCooldowns("Combat Exit")
        return
    end
    
    -- SYNC ON LOGIN / RELOAD
    if event == "PLAYER_ENTERING_WORLD" then
        -- Delay to ensure spell info is ready
        C_Timer.After(2, function() addon:SyncCooldowns("Reload/Login") end)
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
        local spellID = arg3 -- arg3 is spellID for UNIT_SPELLCAST_SUCCEEDED
        
        -- DEBUG: Print ALL casts to verify Spell IDs
        print("BuffForge Cast: "..(C_Spell.GetSpellName(spellID) or "Unknown").." ("..spellID..")")
        
        -- MECHANIC: Howling Blast (49184) + Rime (59052) -> Reduce ERW (47568) CD by 6s
        if spellID == 49184 then
            -- Use the state detected in SENT (0 Rune Cost)
            local hadRime = rimeState.active
            local now = GetTime()
            
            -- Debug Rime Status
            -- print("BuffForge Debug: HB Cast. Rime Check (0 Cost): "..(hadRime and "YES" or "NO"))
            
            if hadRime then
                local erwID = 47568
                local sim = simulated[erwID]
                if sim and sim.nextChargeTime and (sim.charges or 0) < 2 then
                   sim.nextChargeTime = sim.nextChargeTime - 6
                   if sim.nextChargeTime < now then sim.nextChargeTime = now end
                   sim.cdEnd = sim.nextChargeTime
                   -- print("BuffForge: Rime proc used! ERW CDR applied. Charges: "..(sim.charges or 0))
                else
                   -- print("BuffForge Debug: CDR failed. Sim exists: "..(sim and "YES" or "NO").." Charges: "..(sim and sim.charges or "nil"))
                end
            end
        end

        local data = icons[spellID]
        if not data then return end
        
        local settings = data.settings
        if not settings then return end -- settings required
        
        -- Auto-detect Cooldown (Simulated Mode Helper & Adaptive Learning)
        -- DELAY CHECK: API often returns 0 immediately on cast event. Wait for update.
        C_Timer.After(0.2, function()
            local success, err = pcall(function()
                local cdInfo = C_Spell.GetSpellCooldown(spellID)
                
                if cdInfo then
                    local dur = cdInfo.duration
                    
                    if dur and type(dur) == "number" and dur > 1.5 then
                         -- ADAPTIVE LEARNING: Save to DB if Out of Combat
                         -- User Request: "Record CDs used out of combat to eliminate errors"
                         if not InCombatLockdown() then
                             addon:LearnSpellData(spellID, "cd", dur)
                             -- print(format("|cff00ff00BuffForge:|r Learned CD for %s: %.1fs (OOC)", C_Spell.GetSpellName(spellID) or spellID, dur))
                         end
                    
                         -- If detected CD is different from saved, update it
                         if settings.simulatedMode and math.abs((settings.simulatedCooldown or 0) - dur) > 0.1 then
                             print(format("|cff00ff00BuffForge:|r Auto-detected CD for %s: %.1fs (Old: %.1fs)", C_Spell.GetSpellName(spellID) or spellID, dur, (settings.simulatedCooldown or 0)))
                             settings.simulatedCooldown = dur
                             if addon.Config then addon.Config:RefreshCurrentSpell(spellID) end
                         end
                    end
                end
                
                -- Auto-detect Buff Duration
                local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                if aura then
                    local buffDur = aura.duration
                    if buffDur and buffDur > 0 then
                        -- LEARN IT (Save to DB)
                         if not InCombatLockdown() then
                             addon:LearnSpellData(spellID, "buff", buffDur)
                         end
                        
                        if settings.simulatedMode and math.abs((settings.simulatedBuffDuration or 0) - buffDur) > 0.1 then
                             print(format("|cff00ff00BuffForge:|r Auto-detected Buff for %s: %.1fs", C_Spell.GetSpellName(spellID) or spellID, buffDur))
                             settings.simulatedBuffDuration = buffDur
                             if addon.Config then addon.Config:RefreshCurrentSpell(spellID) end
                        end
                    end
                else
                     -- DB Logic (Primary/Fallback for Duration)
                     if settings.simulatedMode and (not settings.simulatedBuffDuration or settings.simulatedBuffDuration == 0) then
                         local dbDuration = addon:GetDurationFromDB(spellID)
                         if dbDuration > 0 then
                             settings.simulatedBuffDuration = dbDuration
                         end
                     end
                end
            end)
        end)
        
        if not settings.simulatedMode then return end -- Stop here if not simulating visual logic
        
        local sim = simulated[spellID]
        if not sim then 
            sim = {}
            simulated[spellID] = sim
        end
        
        -- Spell was cast! Start simulated buff AND cooldown immediately
        local now = GetTime()
        
        -- Get Max Charges from DB
        local dbInfo = BuffForge_SpellDB and BuffForge_SpellDB:GetSpell(spellID)
        local maxCharges = dbInfo and dbInfo.charges or 1
        
        -- Init sim logic if fresh
        sim.charges = sim.charges or maxCharges
        
        -- Debug
        -- print(string.format("BuffForge Debug: Cast %s. Charges: %d/%d", spellID, sim.charges, maxCharges))
        
        -- Consume charge
        if sim.charges > 0 then
            sim.charges = sim.charges - 1
        end
        
        -- Buff Logic: Always apply buff on cast
        sim.state = "buff"
        sim.buffEnd = now + settings.simulatedBuffDuration
        
        -- Cooldown / Recharge Logic
        if sim.charges < maxCharges then
            -- Note: In WoW, charges recharge one by one. 
            -- If recharge is not already running, start it.
            if not sim.nextChargeTime or sim.nextChargeTime < now then
                sim.nextChargeTime = now + settings.simulatedCooldown
                -- print("BuffForge Debug: Starting new recharge timer.")
            else
                -- print("BuffForge Debug: Recharge already running. Continuing.")
            end
            -- Provide cooldown end time for UI
            sim.cdEnd = sim.nextChargeTime
        end
        
        print(string.format("|cff00ff00BuffForge:|r %s used! Buff: %ds, Charges: %d/%d", 
            C_Spell.GetSpellName(spellID) or spellID,
            settings.simulatedBuffDuration,
            sim.charges, maxCharges))
    end
end)

-- === INIT ===
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        BuffForgeDB = BuffForgeDB or CopyTable(defaults)
        BuffForgeDB.profile = BuffForgeDB.profile or {}
        BuffForgeDB.global = BuffForgeDB.global or {}
        BuffForgeDB.global.learnedDB = BuffForgeDB.global.learnedDB or {} -- Initialize Learned DB
        
        -- MIGRATION: Spec Split
        local oldKey = UnitName("player") .. "-" .. GetRealmName()
        if BuffForgeDB.profile[oldKey] then
            -- Found legacy profile (shared). Migrate it to current spec.
            local newKey = GetCharKey()
            if not BuffForgeDB.profile[newKey] then
                BuffForgeDB.profile[newKey] = CopyTable(BuffForgeDB.profile[oldKey])
                print("|cff00ff00BuffForge:|r Migrated Settings to Current Spec.")
            end
            -- Optional: Remove old key or keep as backup? Keeping for now, or for other specs to copy from?
            -- Better: Don't delete immediately so if they swap to Spec B, we can copy from OldKey again.
            -- Logic: If NewKey is empty, look at OldKey. 
            -- But we just did that above.
        end

        -- Migrate singular position
        if BuffForgeDB.global.x and not BuffForgeDB.global.migrated then
             -- This logic is old, safe to keep but standardizing key usage
             BuffForgeDB.global.migrated = true
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
        local ok, err = pcall(ScanAuras)
        if not ok then
            -- Throttle error usage to avoid spam
            if not timer.hasErrored then
                print("|cffff0000BuffForge Error (OnUpdate):|r " .. tostring(err))
                timer.hasErrored = true
            end
        end
    end
end)

-- === MINIMAP BUTTON ===
function addon:CreateMinimapButton()
    local libDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    -- Custom implementation to avoid LibDBIcon dependency if not present, keeping it simple
    
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
    icon:SetTexture("Interface\\Icons\\Inv_hammer_20") -- Hammer icon
    icon:SetPoint("CENTER", 0, 1)
    
    local function UpdatePos()
        local angle = math.rad(BuffForgeDB.global.minimap.minimapPos or 225)
        local cos = math.cos(angle)
        local sin = math.sin(angle)
        local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
        
        local round = true
        if minimapShape == "SQUARE" then round = false end
        
        local radius = 80
        if round then
            b:SetPoint("CENTER", "Minimap", "CENTER", cos * radius, sin * radius)
        else
            -- Simple square logic
            local x, y = cos * radius, sin * radius
            x = math.max(-radius, math.min(radius, x))
            y = math.max(-radius, math.min(radius, y))
            b:SetPoint("CENTER", "Minimap", "CENTER", x, y)
        end
    end
    
    b:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self.isDragging = true
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            
            local angle = math.atan2(cy - my, cx - mx)
            local deg = math.deg(angle)
            if deg < 0 then deg = deg + 360 end
            
            BuffForgeDB.global.minimap.minimapPos = deg
            UpdatePos()
        end)
    end)
    
    b:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
        self.isDragging = false
    end)
    
    b:SetScript("OnClick", function(self, button)
        if addon.Config then addon.Config:Toggle() end
    end)
    
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("BuffForge 5G")
        GameTooltip:AddLine("Left Click: Open Settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move Icon", 1, 1, 1)
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
    if show then
        addon.MinimapButton:Show()
    else
        addon.MinimapButton:Hide()
    end
end

-- === INIT ===
-- We hook the previous ADDON_LOADED logic to add these calls
-- Since we are replacing the end of file, we need to ensure we call CreateMinimapButton after DB load.
-- Retaining the original init logic structure...
local initFrame = CreateFrame("Frame") -- Renamed to avoid local conflict if 'ev' persists
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- RELIABLE INIT: Delay slightly to ensure SpellInfo is ready
        C_Timer.After(1.5, function()
             if addon.RebuildIcons then addon:RebuildIcons() end
        end)

        -- Initialize Minimap Button
        if BuffForgeDB then
            BuffForgeDB.global.minimap = BuffForgeDB.global.minimap or { hide = false, minimapPos = 220 }
            addon:CreateMinimapButton()
            
            -- Register Options Panel
            local category, layout = Settings.RegisterCanvasLayoutCategory(addon.Config and addon.Config.f, "BuffForge")
            -- Since Config.f might be nil (lazy load), we register a proxy func
            Settings.RegisterAddOnCategory(category)
            
            -- Simple Options Panel registration (Classic/Retail compat)
            if InterfaceOptions_AddCategory then
                local panel = CreateFrame("Frame", "BuffForgeOptions", UIParent)
                panel.name = "BuffForge"
                local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
                title:SetPoint("TOPLEFT", 16, -16)
                title:SetText("BuffForge 5G")
                
                local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
                btn:SetSize(150, 30)
                btn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
                btn:SetText("Open Configuration")
                btn:SetScript("OnClick", function() 
                   if addon.Config then addon.Config:Toggle() end
                   HideUIPanel(InterfaceOptionsFrame)
                   HideUIPanel(SettingsPanel) 
                end)
                
                InterfaceOptions_AddCategory(panel)
            end
        end
    end
end)


-- Slash
SLASH_BUFFFORGE1 = "/bf5g"
SlashCmdList["BUFFFORGE"] = function()
    if addon.Config then addon.Config:Toggle() end
end