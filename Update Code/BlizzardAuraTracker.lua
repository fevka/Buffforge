--[[
    BlizzardAuraTracker.lua
    
    A standalone module that integrates with Blizzard's Cooldown and Buff Manager system (11.1.5+).
    It extracts cooldown and aura (buff/debuff) information directly from the game's internal
    CompactUnitFrame / CooldownViewer frames (EssentialCooldownViewer, etc.), providing
    access to protected or "smart" tracked data without re-implementing the tracking logic.

    Usage:
    BlizzardAuraTracker:ScanViewers() -- Rebuilds the map
    local auraFrame = BlizzardAuraTracker:GetAuraFrame(spellID)
    if auraFrame then
        -- Access internal data like auraInstanceID, overlap counts, etc.
        print("Tracking aura instance:", auraFrame.auraInstanceID)
    end
]]

local BlizzardAuraTracker = {}
_G.BlizzardAuraTracker = BlizzardAuraTracker

-- Modern API aliases
local C_Spell = C_Spell
local GetBaseSpell = C_Spell.GetBaseSpell

-- Known Viewer Frame Names (Added in 11.1.5)
local VIEWER_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
}

-- Map: SpellID -> ViewerChildFrame
local viewerAuraFrames = {}

-- Hardcoded ability -> buff mappings for spells where the ability ID 
-- does not match the buff ID and no API links them (e.g., Eclipse).
local ABILITY_BUFF_OVERRIDES = {
    [1233346] = "48517,48518",  -- Solar Eclipse
    [1233272] = "48517,48518",  -- Lunar Eclipse
    
}

------------------------------------------------------------------------
-- 1. Helper: Find Child in Viewer List
------------------------------------------------------------------------
local function FindChildInViewers(spellID)
    -- OPTIMIZATION: Check if we already found it recently (to avoid excessive loops)
    if viewerAuraFrames[spellID] then return viewerAuraFrames[spellID] end
    
    for _, name in ipairs(VIEWER_NAMES) do
        local viewer = _G[name]
        if viewer then
            for _, child in pairs({viewer:GetChildren()}) do
                local info = child.cooldownInfo
                if info and (info.spellID == spellID or 
                   info.overrideSpellID == spellID or 
                   info.overrideTooltipSpellID == spellID) then
                    
                    -- Cache it immediately!
                    viewerAuraFrames[spellID] = child
                    return child
                end
            end
        end
    end
    return nil
end

------------------------------------------------------------------------
-- 2. Build / Refresh Map
------------------------------------------------------------------------
-- Scans all Blizzard viewer frames and maps SpellIDs to the frames tracking them.
function BlizzardAuraTracker:ScanViewers()
    wipe(viewerAuraFrames)

    -- Step A: Basic Scan
    for _, name in ipairs(VIEWER_NAMES) do
        local viewer = _G[name]
        if viewer then
            -- HIJACK BLIZZARD FRAMES: Control visibility based on settings
            local hideBlizzard = true -- Default behavior
            if BuffForgeDB and BuffForgeDB.global and BuffForgeDB.global.hideBlizzardFrames ~= nil then
                hideBlizzard = BuffForgeDB.global.hideBlizzardFrames
            end
            
            if hideBlizzard then
                -- Force them to be "technically" open but invisible
                if not viewer:IsShown() then
                    viewer:Show()
                end
                viewer:SetAlpha(0)
                viewer:EnableMouse(false)
            else
                -- Restore visibility
                viewer:SetAlpha(1)
                -- We don't force Show/Hide here; let Blizzard UI manage it naturally.
                -- However, we must re-enable mouse if we disabled it.
                viewer:EnableMouse(true) 
            end

            for _, child in pairs({viewer:GetChildren()}) do
                if child.cooldownInfo then
                    local spellID = child.cooldownInfo.spellID
                    if spellID then
                        viewerAuraFrames[spellID] = child
                    end
                    
                    -- Also map override IDs
                    local override = child.cooldownInfo.overrideSpellID
                    if override then
                        viewerAuraFrames[override] = child
                    end
                    
                    local tooltipOverride = child.cooldownInfo.overrideTooltipSpellID
                    if tooltipOverride then
                        viewerAuraFrames[tooltipOverride] = child
                    end
                end
            end
        end
    end

    -- Step B: Handle Hardcoded Overrides (e.g. Eclipse)
    -- This logic handles cases where multiple abilities (Solar/Lunar) 
    -- map to the same set of buffs.
    for abilityID, buffStr in pairs(ABILITY_BUFF_OVERRIDES) do
        local child = nil
        
        -- Try to find a child tracking one of the buff IDs
        for id in buffStr:gmatch("%d+") do
            local buffID = tonumber(id)
            if viewerAuraFrames[buffID] then
                child = viewerAuraFrames[buffID]
                break
            end
            if not child then
                 -- If not in our map yet, try to find it specifically
                child = FindChildInViewers(buffID)
            end
            if child then break end
        end

        -- If found, map the *ability* ID to that buff tracking frame
        if child then
            viewerAuraFrames[abilityID] = child
        end
    end
end

------------------------------------------------------------------------
-- 3. Public Accessor
------------------------------------------------------------------------
-- Returns the Blizzard frame responsible for tracking the given spellID.
-- If not found immediately, attempts to resolve via BaseSpell or overrides.
function BlizzardAuraTracker:GetAuraFrame(spellID)
    -- 1. Direct Lookup & VALIDATION
    local child = viewerAuraFrames[spellID]
    if child then 
        -- Validate: Does this frame still track the requested spell?
        local info = child.cooldownInfo
        local isValid = false
        if info then
             if info.spellID == spellID then isValid = true
             elseif info.overrideSpellID == spellID then isValid = true
             elseif info.overrideTooltipSpellID == spellID then isValid = true
             end
        end
        
        if isValid then
            return child 
        else
            -- Invalid cache: Frame repurposed? Remove it.
            viewerAuraFrames[spellID] = nil
        end
    end

    -- 2. Base Spell Lookup (Handle transforms/overrides)
    local baseSpellID = GetBaseSpell and GetBaseSpell(spellID)
    if baseSpellID and baseSpellID ~= spellID then
        -- Recursively call to get validated base frame
        child = self:GetAuraFrame(baseSpellID)
        if child then return child end
    end

    -- 3. Manual Search (Fallout if map is stale)
    -- This iterates current children to find the new owner
    child = FindChildInViewers(spellID)
    if child then 
        viewerAuraFrames[spellID] = child
        return child 
    end

    return nil
end

------------------------------------------------------------------------
-- 4. Utility: Get Aura Data
------------------------------------------------------------------------
-- Returns the actual AuraInstanceID and Unit being tracked by Blizzard
function BlizzardAuraTracker:GetAuraInfo(spellID)
    local frame = self:GetAuraFrame(spellID)
    if frame then
        return frame.auraInstanceID, frame.auraDataUnit or "player"
    end
    return nil, nil
end

-- Refresh automatically on events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:SetScript("OnEvent", function()
    BlizzardAuraTracker:ScanViewers()
    -- print("BlizzardAuraTracker: Refreshed viewers.") -- Debug
end)

-- Initial scan
BlizzardAuraTracker:ScanViewers()

------------------------------------------------------------------------
-- 4. Data Extraction & Linking (New Structure)
------------------------------------------------------------------------

-- Custom link registry (SpellID -> AuraID)
local CUSTOM_AURA_LINKS = {}

-- Allows external modules to register known CD->Aura links
function BlizzardAuraTracker:RegisterAuraLink(spellID, auraIDs)
    CUSTOM_AURA_LINKS[spellID] = auraIDs
end

-- Returns a list of ALL cooldowns currently detected/tracked by Blizzard's viewers
function BlizzardAuraTracker:GetAllTrackedCooldowns()
    local cooldowns = {}
    for spellID, _ in pairs(viewerAuraFrames) do
        table.insert(cooldowns, spellID)
    end
    return cooldowns
end

-- "We need to link the auras attached to these CDs"
-- Returns the Aura ID(s) associated with a given Spell ID (Cooldown)
function BlizzardAuraTracker:GetLinkedAuraID(spellID)
    -- 1. Custom Links (Highest Priority)
    if CUSTOM_AURA_LINKS[spellID] then
        return CUSTOM_AURA_LINKS[spellID]
    end

    -- 2. Hardcoded Overrides (BlizzardAuraTracker Internal)
    if ABILITY_BUFF_OVERRIDES[spellID] then
        return ABILITY_BUFF_OVERRIDES[spellID]
    end

    -- 3. Check SpellDatabase for explicit 'aura_id' or 'buff_id'
    if BuffForge_SpellDB then
        local spellData = BuffForge_SpellDB:GetSpell(spellID)
        if spellData then
            if spellData.aura_id then return spellData.aura_id end
            -- Sometimes the database ID *is* the aura ID
        end
    end

    -- 4. Blizzard Frame Logic
    -- If Blizzard tracks it, the frame might hold the "real" aura ID in cooldownInfo
    local frame = self:GetAuraFrame(spellID)
    if frame and frame.cooldownInfo then
        -- If the frame is tracking a different ID via override, that might be the aura
        if frame.cooldownInfo.spellID and frame.cooldownInfo.spellID ~= spellID then
            return frame.cooldownInfo.spellID
        end
    end

    -- 5. Default Fallback
    -- For most spells, the Cooldown ID is the same as the Aura ID (e.g., Icy Veins = 12472)
    return spellID
end


------------------------------------------------------------------------
-- 5. INTEGRATED DEV TOOL: Spell Picker & Inspection
------------------------------------------------------------------------
-- This allows the user to hover over any spell (Action Bar, Spellbook, OR Internal Viewer)
-- and automatically detect the ID + Check if it's tracked by this system.

function BlizzardAuraTracker:PickTarget()
    -- 1. Get the frame under the mouse (Safe for 11.0+)
    local focus
    if GetMouseFoci then
        local foci = GetMouseFoci()
        focus = foci and foci[1]
    else
        focus = GetMouseFocus and GetMouseFocus()
    end

    if not focus then 
        print("|cff00ff00[BuffForge]|r No frame detected under mouse. Hover over a spell.")
        return 
    end
    
    local spellID = nil
    
    -- 2. Standard Action Button
    if focus.action then
        local type, id, subType = GetActionInfo(focus.action)
        if type == "spell" then spellID = id
        elseif type == "macro" then spellID = GetMacroSpell(id)
        end
    end
    
    -- 3. Generic spellID field
    if not spellID and focus.spellID then spellID = focus.spellID end

    -- 4. GetSpellId Method
    if not spellID and focus.GetSpellId then
        local valid, result = pcall(focus.GetSpellId, focus)
        if valid and result then spellID = result end
    end
    
    -- 5. BLIZZARD VIEWER FRAME CHECK (Deep Inspection)
    -- If we are hovering a container like 'EssentialCooldownViewer', check its children
    if not spellID and focus.GetChildren then
        local children = {focus:GetChildren()}
        for _, child in ipairs(children) do
            if child.cooldownInfo and child:IsMouseOver() then
                spellID = child.cooldownInfo.spellID
                if not spellID then spellID = child.cooldownInfo.overrideSpellID end
                if spellID then break end
            end
        end
        -- Or check the focus itself if it's a viewer button
        if not spellID and focus.cooldownInfo then
             spellID = focus.cooldownInfo.spellID
             if not spellID then spellID = focus.cooldownInfo.overrideSpellID end
        end
    end
    
    if not spellID then
        print("|cff00ff00[BuffForge]|r No spell ID found on frame: " .. (focus:GetName() or "Anonymous"))
        if focus.GetObjectType then print("   Type: " .. focus:GetObjectType()) end
        return
    end
    
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    local name = spellInfo and spellInfo.name or "Unknown"
    
    print("|cff00ff00[BuffForge Picker]|r Found: " .. name .. " (" .. spellID .. ")")

    -- Check if we track it natively
    local trackerFrame = self:GetAuraFrame(spellID)
    local isOptimized = (trackerFrame ~= nil)
    
    if isOptimized then
        print("   |cff00ff00[Optimized]|r YES! Blizzard tracks this internally.")
    else
        print("   |cffaaaaaa[Standard]|r Blizzard does not track this internally (Standard API will be used).")
    end
    
    -- AUTO-ADD TO BUFFFORGE PROFILE (Integration with Main Addon)
    if BuffForgeDB and BuffForgeDB.profile then
         local specIndex = GetSpecialization()
         local specID = specIndex and GetSpecializationInfo(specIndex) or 0
         local key = UnitName("player") .. "-" .. GetRealmName() .. "-" .. specID
         
         BuffForgeDB.profile[key] = BuffForgeDB.profile[key] or {}
         
         if not BuffForgeDB.profile[key][spellID] then
             print("   |cff00ff00+ Added to BuffForge Profile (Test Mode)|r")
             BuffForgeDB.profile[key][spellID] = {
                enabled = true,
                type = "icon",
                point = "CENTER",
                relativePoint = "CENTER",
                x = 0, y = 0,
                size = 60, 
                width = 60,
                alwaysShow = true,
                desaturate = true,
                showBorder = true,
                borderColor = {0, 1, 0, 1},
                trackType = "hybrid",
             }
         else
             print("   |cffffcc00(Already in profile - refreshing)|r")
         end
         
         -- Trigger update if main addon is loaded
         if BuffForge and BuffForge.UpdateIcon then
             BuffForge:UpdateIcon(spellID)
         end
    end
end

-- Slash command to trigger the picker
SLASH_BUFFFORGEPICK1 = "/bfpick"
SlashCmdList["BUFFFORGEPICK"] = function()
    BlizzardAuraTracker:PickTarget()
end
