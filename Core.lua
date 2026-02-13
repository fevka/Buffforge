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
        minimap = { hide = false, minimapPos = 220 },
        showBlizzardCDText = true,
        showBlizzardCDSwipe = true,
        hideBlizzardFrames = true,
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
    
    -- Glow Settings

    
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
    
    -- Sound Settings
    sound = {
        enabled = false,
        soundID = 8960,    -- Ready Check
        channel = "Master" 
    },
    
    -- Manual Simulation
    simulatedMode = false,
    simulatedBuffDuration = 0,
    
    -- New Proc/Popup Features
    trackType = "hybrid", -- "hybrid" (CD+Buff), "cooldown" (Only CD), "buff" (Only Buff/Proc)
    popupAnimation = false, -- Play zoom/bounce animation on proc
}

local icons = {} 
local memory = {} 
local simulated = {} 
local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()
local scratchCooldown = CreateFrame("Cooldown", "BuffForgeScratchCooldown", hiddenFrame, "CooldownFrameTemplate") 
addon.dummyAura = {}

-- === ANIMATION UTILS ===
local function CreatePopupAnimation(frame)
    if frame.popupAnim then return end
    
    local g = frame:CreateAnimationGroup()
    
    -- Pop In (Scale Up)
    local a1 = g:CreateAnimation("Scale")
    a1:SetOrder(1)
    a1:SetDuration(0.1)
    a1:SetScaleFrom(0.5, 0.5)
    a1:SetScaleTo(1.2, 1.2)
    a1:SetSmoothing("OUT")
    
    -- Bounce Back (Scale Down to Normal)
    local a2 = g:CreateAnimation("Scale")
    a2:SetOrder(2)
    a2:SetDuration(0.1)
    a2:SetScaleFrom(1.2, 1.2)
    a2:SetScaleTo(1.0, 1.0)
    a2:SetSmoothing("IN")
    
    frame.popupAnim = g
end 

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
    local data = { buff_duration=0, name="", icon=134400 }
    
    if BuffForge_SpellDB then
        local static = BuffForge_SpellDB:GetSpell(spellID)
        if static then
            data.buff_duration = static.buff_duration or 0

            data.name = static.name
            data.icon = static.icon
            data.talents = static.talents
        end
    end
    
    if BuffForgeDB and BuffForgeDB.global and BuffForgeDB.global.learnedDB then
        local specIndex = GetSpecialization()
        local specID = specIndex and GetSpecializationInfo(specIndex) or 0
        local learned = BuffForgeDB.global.learnedDB[specID] and BuffForgeDB.global.learnedDB[specID][spellID]
        
        if learned then
             if learned.buff and learned.buff > 0 then data.buff_duration = learned.buff end

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

-- === SOUND SYSTEM ===
function addon:PlaySoundAlert(settings)
    if not settings or not settings.enabled then return end
    
    -- Throttling
    local now = GetTime()
    if settings.lastPlayed and (now - settings.lastPlayed < 1.0) then return end
    settings.lastPlayed = now

    local id = settings.soundID
    if not id then id = 8960 end 
    
    local channel = settings.channel or "Master"
    PlaySound(id, channel) 
end

-- === SIMULATED TRACKING ===
local function CheckSimulatedState(spellID, settings)
    local now = GetTime()
    local sim = simulated[spellID]
    if not sim then return nil end
    
    if sim.state == "buff" and now >= sim.buffEnd then
        sim.state = "ready"
    end
    
    local icon = C_Spell.GetSpellTexture(spellID)
    
    if sim.state == "buff" then
        return {
            expirationTime = sim.buffEnd,
            duration = settings.simulatedBuffDuration,
            icon = icon,
            applications = 0,
            isSimBuff = true,
        }
    else
        sim.state = "ready"
        return {
            expirationTime = 0,
            duration = 0,
            icon = icon,
            applications = 0,
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

                
                aura = CheckSimulatedState(spellID, settings)
                
                if aura and not (configOpen or settings.alwaysShow) then
                    local keep = false
                    if aura.isSimBuff then
                        -- Buff glow enabled mı kontrol et
                        if settings.buffGlow and settings.buffGlow.enabled then
                            keep = true
                        else
                            keep = false
                        end
                    elseif aura.isSimReady then
                        keep = false
                    end
                    if not keep then aura = nil end
                end
            end
            
            -- 2. Ask API (Smart Integration: Blizzard Tracker Priority)
            if not aura then
                local foundViaTracker = false

                -- Method A: Direct Instance ID from Blizzard's Tracker
                -- This uses the specific aura instance Blizzard is tracking for this CD.
                -- Solves "secret" errors because we use the valid ID provided by the game.
                if BlizzardAuraTracker and BlizzardAuraTracker.GetAuraInfo then
                    local instanceID, unit = BlizzardAuraTracker:GetAuraInfo(spellID)
                    if instanceID then
                        aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instanceID)
                        if aura then foundViaTracker = true end
                    end
                end

                -- Method B: Linked Aura ID (Fallback if tracker doesn't have it active yet)
                if not foundViaTracker then
                    local targetAuraID = spellID
                    if BlizzardAuraTracker and BlizzardAuraTracker.GetLinkedAuraID then
                        targetAuraID = BlizzardAuraTracker:GetLinkedAuraID(spellID)
                    end
                    
                    aura = C_UnitAuras.GetPlayerAuraBySpellID(targetAuraID)
                    
                    -- Fallback: Try Original Spell ID
                    if not aura and targetAuraID ~= spellID then
                        aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                    end
                    
                    -- Method C: Name Search (ULTIMATE FALLBACK - SAFELY WRAPPED)
                    if not aura then
                        local spellName = C_Spell.GetSpellName(spellID)
                        if spellName then
                            local function SafeNameCheck(aura)
                                local match = false
                                -- pcall prevents "secret string" errors
                                pcall(function()
                                    if aura and aura.name == spellName then match = true end
                                end)
                                return match
                            end
                            
                            -- Use AuraUtil loop safely
                            AuraUtil.ForEachAura("player", "HELPFUL", nil, function(a)
                                if SafeNameCheck(a) then
                                    aura = a
                                    return true
                                end
                            end, true) -- usePackedAura=true
                        end
                    end
                end

            end -- closes 'if not aura then'

            -- Helper to sanitize aura values using the scratch frame
            local function GetSafeAuraValues(instanceID)
                if not instanceID then return nil, nil end
                local start, duration = 0, 0
                
                -- 1. Try to get DurationObject
                local ok, durationObj = pcall(C_UnitAuras.GetAuraDuration, "player", instanceID)
                
                if ok and durationObj then
                    -- 2. Apply to scratch cooldown to sanitize
                    scratchCooldown:SetCooldownFromDurationObject(durationObj)
                    local sMs, dMs = scratchCooldown:GetCooldownTimes()
                    
                    if sMs and dMs then
                        -- Sometimes the returned milliseconds are still tainted
                        local ok2 = pcall(function()
                            start = sMs / 1000
                            duration = dMs / 1000
                        end)
                        if ok2 then
                            return start, duration
                        end
                    end
                end
                return nil, nil
            end

            -- SANITIZE & STORE IN DB (Memory)
            local mem = memory[spellID]
            
            if aura and aura.auraInstanceID then
                local safeStart, safeDur = GetSafeAuraValues(aura.auraInstanceID)
                if safeStart and safeDur then
                    -- Update Memory (The "Database")
                    mem.expirationTime = safeStart + safeDur
                    mem.duration = safeDur
                    mem.texture = aura.icon
                    mem.count = aura.applications or 0
                    mem.lastSeen = now
                    
                    -- Update local aura object to match memory
                    aura.expirationTime = mem.expirationTime
                    aura.duration = mem.duration
                end
            elseif aura then
                -- Fallback for non-instance auras (e.g. name scan)
                mem.expirationTime = aura.expirationTime or 0
                mem.duration = aura.duration or 0
                mem.texture = aura.icon
                mem.count = aura.applications or 0
                mem.lastSeen = now
            elseif pcall(function() return mem.expirationTime > now end) and mem.expirationTime > now then
                -- Dead Reckoning from DB (OPTIMIZED: Reuse dummyAura table)
                local da = addon.dummyAura
                wipe(da)
                da.expirationTime = mem.expirationTime
                da.duration = mem.duration
                da.icon = mem.texture
                da.applications = mem.count
                aura = da
            end
            
            -- 4. CD Logic: ... (rest of function)
            
            -- Filter based on settings (e.g. Glow)
            if aura and not (configOpen or settings.alwaysShow) then
                if not (settings.buffGlow and settings.buffGlow.enabled) then
                     aura = nil
                end
            end
            
            -- 4. CD Logic: If no buff aura but tracker shows a cooldown, keep the icon visible
            -- SKIP if trackType is "buff" (Proc Mode) - we only want to show when there is an actual buff
            if not aura and data.tracker and settings.trackType ~= "buff" then
                -- Read the tracker's own state (already computed safely via scratch frame)
                local isOnCD = data.tracker.state and data.tracker.state.isOnCooldown
                
                if isOnCD or settings.alwaysShow or configOpen then
                    local da = addon.dummyAura
                    wipe(da)
                    da.expirationTime = 0
                    da.duration = 0
                    da.icon = C_Spell.GetSpellTexture(spellID)
                    da.applications = 0
                    da.isCooldownOnly = true
                    aura = da
                end
            elseif not aura and (settings.alwaysShow or configOpen) then
                local da = addon.dummyAura
                wipe(da)
                da.expirationTime = 0
                da.duration = 0
                da.icon = C_Spell.GetSpellTexture(spellID)
                da.applications = 0
                aura = da
            end
            
            -- 5. Update Visuals
            if aura then
                if not data.active then
                    -- Trigger Popup Animation if enabled and frame was hidden
                    if settings.popupAnimation then
                         CreatePopupAnimation(data.frame)
                         if not configOpen then
                             data.frame.popupAnim:Play()
                         end
                    end
                    
                    data.frame:Show()
                    data.active = true
                end
                if configOpen then data.frame:SetAlpha(1) end
                
                local remaining = 0
                -- Safely calculate remaining time
                pcall(function()
                    if aura.expirationTime and aura.expirationTime > now then
                        remaining = aura.expirationTime - now
                    end
                end)
                local isDurationZero = false
                pcall(function()
                    if aura.duration == 0 then isDurationZero = true end
                end)
                if isDurationZero then remaining = 1 end

                local borderR, borderG, borderB = unpack(settings.borderColor)
                
                local isSimBuff = aura and aura.isSimBuff

                if isSimBuff then
                    data.iconTex:SetDesaturated(false)
                    data.iconTex:SetVertexColor(1, 1, 1, 1)
                    if settings.showBorder then borderR, borderG, borderB = 0, 1, 0 end
                
                else
                    data.iconTex:SetDesaturated(false)
                    data.iconTex:SetVertexColor(1, 1, 1, 1)
                end

                if settings.type == "bar" then
                    local safeDuration = 1
                    pcall(function() safeDuration = math.max(aura.duration, 1) end)
                    data.bar:SetMinMaxValues(0, safeDuration)
                    data.bar:SetValue(remaining)
                    
                    local timeDisplay = format("%.1f", remaining)
                    
                    if isDurationZero then
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
                    -- Icon mode: let DynamicCooldownTracker handle cooldown swipe
                    -- Do NOT hide data.cooldown — the tracker manages its own widget.
                    -- If we have a tracker, make sure it's visible.
                    if data.tracker then
                        data.tracker:Show()
                        
                        -- SHOW BUFF DURATION SWIPE
                        -- If we have a valid buff duration, override the tracker's cooldown swipe
                        -- to show the BUFF duration instead of the spell cooldown.
                        -- SHOW BUFF DURATION SWIPE
                        -- Method 1 (Best): Use DurationObject directly (No arithmetic = No taint errors)
                        local swipeSet = false
                        if aura.auraInstanceID then
                             local ok, durationObj = pcall(C_UnitAuras.GetAuraDuration, "player", aura.auraInstanceID)
                             if ok and durationObj then
                                 pcall(function()
                                    data.tracker.cooldown:SetCooldownFromDurationObject(durationObj)
                                    data.tracker.cooldown:Show()
                                    swipeSet = true
                                 end)
                             end
                        end

                        -- Method 2 (Fallback): Manual Math (Only if Method 1 failed)
                        if not swipeSet then
                            -- Safely check duration > 0
                            local isValidDuration = false
                            pcall(function()
                                if aura.duration and aura.duration > 0 and aura.expirationTime then
                                    isValidDuration = true
                                end
                            end)
    
                            if isValidDuration then
                                pcall(function()
                                    local startTime = aura.expirationTime - aura.duration
                                    data.tracker.cooldown:SetCooldown(startTime, aura.duration)
                                    data.tracker.cooldown:Show()
                                    swipeSet = true
                                end)
                            end
                        end
                        
                        -- CRITICAL: Prevent tracker from overwriting our buff swipe
                        if swipeSet then
                            data.tracker:ForceCooldown(true)
                        else
                            data.tracker:ForceCooldown(false)
                        end
                        
                        -- If tracker has a state, desaturate icon when on CD (only if no buff swipe active)
                        if not swipeSet and settings.desaturate and data.tracker.state and data.tracker.state.isOnCooldown then
                             data.iconTex:SetDesaturated(true)
                        elseif settings.desaturate then
                            data.iconTex:SetDesaturated(false)
                        end
                    elseif data.cooldown then
                        data.cooldown:Hide()
                    end
                end
                
                -- Timer Text kontrolü (varsayılan: göster)
                local showTimer = (settings.showTimerText ~= false)
                
                if data.timerText then
                    if showTimer and remaining > 0 then 
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
                
                -- Safe Stack Count Logic
                local stackSetSuccess = pcall(function()
                    if aura.applications and aura.applications > 0 then
                        data.stackText:SetText(aura.applications)
                    else
                        data.stackText:SetText("")
                    end
                end)

                -- Fallback: If comparison failed due to secret value, try to show it anyway
                if not stackSetSuccess then
                    pcall(function()
                        if aura.applications then
                            data.stackText:SetText(aura.applications)
                        else
                            data.stackText:SetText("")
                        end
                    end)
                end
                
                data.iconTex:SetTexture(aura.icon)
                
                local desiredGlow = nil 
                
                -- 1. Check CD Glow REMOVED

                
                -- 2. Check Buff Glow
                if settings.buffGlow and settings.buffGlow.enabled and isSimBuff then
                     local buffRemaining = aura.expirationTime - GetTime()
                     local thresh = settings.buffGlow.threshold or 0
                     if thresh == 0 then
                         desiredGlow = settings.buffGlow
                     elseif buffRemaining > 0 and buffRemaining <= thresh then
                         desiredGlow = settings.buffGlow
                     end
                end
                
                -- Trigger Logic
                if desiredGlow then
                     addon:ToggleGlow(data.frame, true, desiredGlow)
                else
                     addon:ToggleGlow(data.frame, false)
                end
                data.lastGlowRef = desiredGlow
                
                if not desiredGlow and settings.showBorder then
                     data.frame:SetBackdropBorderColor(borderR, borderG, borderB, 1)
                elseif not desiredGlow then
                     data.frame:SetBackdropBorderColor(0,0,0,0)
                end
                
            else
                -- Hidden / Ghost Logic
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
                    -- Don't hide tracker's cooldown in config mode
                    if data.tracker then
                        data.tracker:Show()
                    elseif data.cooldown then
                        data.cooldown:Hide()
                    end
                    
                    addon:ToggleGlow(data.frame, false)
                    data.lastGlowRef = nil 
                else
                    -- Check if tracker has an active cooldown before hiding
                    local trackerActive = false
                    if data.tracker and data.tracker.state then
                        trackerActive = data.tracker.state.isOnCooldown
                    end
                    
                    if trackerActive then
                        -- Cooldown is running — keep icon visible!
                        if not data.active then
                            data.frame:Show()
                            data.active = true
                        end
                        data.tracker:Show()
                        local info = C_Spell.GetSpellInfo(spellID)
                        local icon = info and info.iconID or 134400
                        data.iconTex:SetTexture(icon)
                        if settings.desaturate then
                            data.iconTex:SetDesaturated(true)
                        end
                        if data.timerText then data.timerText:SetText("") end
                        if data.stackText then data.stackText:SetText("") end
                        addon:ToggleGlow(data.frame, false)
                        data.lastGlowRef = nil
                    else
                        if data.active then
                            data.frame:Hide()
                            data.active = false
                            addon:ToggleGlow(data.frame, false)
                            data.lastGlowRef = nil 
                        end
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

function addon:UpdateAllIcons()
    if not BuffForgeDB then return end
    local key = GetCharKey()
    local profile = BuffForgeDB.profile[key] or {}
    for id, _ in pairs(profile) do
        addon:UpdateIcon(id)
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
    
    -- === FIX: USE REAL TABLES FOR NESTED SETTINGS TO FIX SAVING ISSUES ===
    setmetatable(settings, {__index = DEFAULT_SETTINGS})
    
    -- rawget ile kontrol edip, eğer yoksa veritabanına gerçek bir kopya oluşturuyoruz.
    -- Bu sayede değişiklikler artık kalıcı olacak.
    if rawget(settings, "buffGlow") == nil then settings.buffGlow = CopyTable(DEFAULT_SETTINGS.buffGlow) end
    if rawget(settings, "sound") == nil then settings.sound = CopyTable(DEFAULT_SETTINGS.sound) end

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
          simulated[id] = { state="ready", buffEnd=0 }
     else
         f = data.frame
         mover = data.mover
     end
     
     data.settings = settings
     data.moveText:SetText(C_Spell.GetSpellName(id) or id)
     
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
             -- ICON MODE: Integrated DynamicCooldownTracker
             if not data.tracker then
                  -- Create the smart tracker
                  local tracker = DynamicCooldownTracker:CreateTracker(f, id, settings.size)
                  tracker:SetPoint("CENTER")
                  tracker:SetAllPoints(f)
                  
                  -- Extra Texts (Buff Duration & Stacks)
                  -- PARENT TO TRACKER so they appear above the tracker's background/cooldown
                  local stackText = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                  stackText:SetPoint("TOPRIGHT", 0, 0) -- Moved to TOPRIGHT to avoid conflict with CD Charges (BottomRight)
                  
                  local timerText = tracker:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                  timerText:SetPoint("CENTER", 0, 0)
                  
                  data.tracker = tracker
                  data.iconTex = tracker.icon -- Allow ScanAuras to update texture
                  data.stackText = stackText
                  data.timerText = timerText
                  
                  -- Explicitly nil existing manual refs just in case (though we are in 'if not data.tracker')
                  data.cooldown = nil 
             end
             
             -- Apply Global Cooldown Settings (Blizzard Text/Swipe)
             local showText = (BuffForgeDB.global.showBlizzardCDText ~= false)
             local showSwipe = (BuffForgeDB.global.showBlizzardCDSwipe ~= false)
             
             if data.tracker and data.tracker.cooldown then
                  data.tracker.cooldown:SetHideCountdownNumbers(not showText)
                  data.tracker.cooldown:SetDrawSwipe(showSwipe)
                  data.tracker.cooldown:SetDrawEdge(showSwipe) 
             end
             
             data.tracker:Show(); data.stackText:Show(); data.timerText:Show()
             data.tracker:SetSize(settings.size, settings.size)
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
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then return end

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
        local data = icons[spellID]
        if not data then return end
        local settings = data.settings
        C_Timer.After(0.2, function()
            local success, err = pcall(function()
                local targetAuraID = spellID
                if BlizzardAuraTracker and BlizzardAuraTracker.GetLinkedAuraID then
                    targetAuraID = BlizzardAuraTracker:GetLinkedAuraID(spellID)
                end
                
                local aura = C_UnitAuras.GetPlayerAuraBySpellID(targetAuraID)
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
        sim.state = "buff"
        sim.buffEnd = now + settings.simulatedBuffDuration
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