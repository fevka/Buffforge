--[[
    BlizzardAuraTracker.lua
    
    A standalone module that integrates with Blizzard's Cooldown and Buff Manager system (11.1.5+).
    It extracts cooldown and aura (buff/debuff) information directly from the game's internal
    CompactUnitFrame / CooldownViewer frames (EssentialCooldownViewer, etc.), providing
    access to protected or "smart" tracked data without re-implementing the tracking logic.
]]

local BlizzardAuraTracker = {}
_G.BlizzardAuraTracker = BlizzardAuraTracker

-- Modern API aliases
local C_Spell = C_Spell
local GetBaseSpell = C_Spell.GetBaseSpell
local C_UnitAuras = C_UnitAuras

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
    if viewerAuraFrames[spellID] then return viewerAuraFrames[spellID] end
    
    for _, name in ipairs(VIEWER_NAMES) do
        local viewer = _G[name]
        if viewer then
            for _, child in pairs({viewer:GetChildren()}) do
                local info = child.cooldownInfo
                if info and (info.spellID == spellID or 
                   info.overrideSpellID == spellID or 
                   info.overrideTooltipSpellID == spellID) then
                    
                    viewerAuraFrames[spellID] = child
                    return child
                end
            end
        end
    end
    return nil
end

------------------------------------------------------------------------
-- 2. Build / Refresh Map (Logic from aktif_buff_isleyisi.md)
------------------------------------------------------------------------
function BlizzardAuraTracker:ScanViewers()
    wipe(viewerAuraFrames)

    for _, name in ipairs(VIEWER_NAMES) do
        local viewer = _G[name]
        if viewer then
            -- HIJACK BLIZZARD FRAMES (Optional)
            local hideBlizzard = true 
            if BuffForgeDB and BuffForgeDB.global and BuffForgeDB.global.hideBlizzardFrames ~= nil then
                hideBlizzard = BuffForgeDB.global.hideBlizzardFrames
            end
            
            if hideBlizzard then
                if not viewer:IsShown() then viewer:Show() end
                viewer:SetAlpha(0)
                viewer:EnableMouse(false)
            else
                viewer:SetAlpha(1)
                viewer:EnableMouse(true) 
            end

            for _, child in pairs({viewer:GetChildren()}) do
                if child.cooldownInfo then
                    local spellID = child.cooldownInfo.spellID
                    -- Spell ID → Blizzard Frame eşleşmesini kaydeder
                    if spellID then
                        viewerAuraFrames[spellID] = child
                    end
                    
                    -- Varsa override (dönüşmüş büyü) ID'lerini de kaydeder
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

    -- Handle Overrides
    for abilityID, buffStr in pairs(ABILITY_BUFF_OVERRIDES) do
        local child = nil
        for id in buffStr:gmatch("%d+") do
            local buffID = tonumber(id)
            if viewerAuraFrames[buffID] then
                child = viewerAuraFrames[buffID]
                break
            end
            if not child then child = FindChildInViewers(buffID) end
            if child then break end
        end
        if child then viewerAuraFrames[abilityID] = child end
    end
end

------------------------------------------------------------------------
-- 3. Public Accessors
------------------------------------------------------------------------

-- Returns the Blizzard frame responsible for tracking the given spellID.
function BlizzardAuraTracker:GetAuraFrame(spellID)
    local child = viewerAuraFrames[spellID]
    if child then 
        local info = child.cooldownInfo
        local isValid = false
        if info then
             if info.spellID == spellID then isValid = true
             elseif info.overrideSpellID == spellID then isValid = true
             elseif info.overrideTooltipSpellID == spellID then isValid = true
             end
        end
        if isValid then return child else viewerAuraFrames[spellID] = nil end
    end

    local baseSpellID = GetBaseSpell and GetBaseSpell(spellID)
    if baseSpellID and baseSpellID ~= spellID then
        child = self:GetAuraFrame(baseSpellID)
        if child then return child end
    end

    return FindChildInViewers(spellID)
end

-- Returns the actual AuraInstanceID and Unit
function BlizzardAuraTracker:GetAuraInfo(spellID)
    local frame = self:GetAuraFrame(spellID)
    if frame then
        return frame.auraInstanceID, frame.auraDataUnit or "player"
    end
    return nil, nil
end

-- Returns Pandemic Status (Matches logic: viewerFrame.PandemicIcon:IsVisible())
function BlizzardAuraTracker:GetPandemicStatus(spellID)
    local frame = self:GetAuraFrame(spellID)
    if frame and frame.PandemicIcon then
        return frame.PandemicIcon:IsVisible()
    end
    return false
end

-- Refresh automatically on events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:SetScript("OnEvent", function()
    BlizzardAuraTracker:ScanViewers()
end)

-- Initial scan
BlizzardAuraTracker:ScanViewers()

------------------------------------------------------------------------
-- 4. INTEGRATED DEV TOOL: IconPicker
------------------------------------------------------------------------
-- 4. INTEGRATED DEV TOOL: IconPicker
------------------------------------------------------------------------

-- Helper: Identify everything under the mouse
function BlizzardAuraTracker:GetTargetUnderMouse()
    local focus
    if GetMouseFoci then
        local foci = GetMouseFoci()
        focus = foci and foci[1]
    else
        focus = GetMouseFocus and GetMouseFocus()
    end

    if not focus or focus == WorldFrame then return nil, nil, nil end
    
    local targetType, id, name = nil, nil, nil

    -- 1. Action Button (Standard, ElvUI, etc)
    if focus.action then
        -- pcall to avoid potential protected/secret value errors in combat
        local ok, actionType, actionID = pcall(GetActionInfo, focus.action)
        if ok and actionType then
            if actionType == "spell" then
                targetType, id = "spell", actionID
            elseif actionType == "macro" then
                id = GetMacroSpell(actionID)
                if id then targetType = "spell" end
            elseif actionType == "item" then
                targetType, id = "item", actionID
            end
        end
    end
    
    -- 2. Container Item (Bags)
    if not id then
        -- Standard Blizzard & common addons
        local parent = focus:GetParent()
        -- Try to get BagID from parent or self
        local bagID = focus.bagID
        if bagID == nil and focus.GetBagID then 
            local ok, res = pcall(focus.GetBagID, focus)
            if ok then bagID = res end
        end
        if bagID == nil and parent and parent.GetID then
             local ok, res = pcall(parent.GetID, parent)
             if ok then bagID = res end
        end

        -- Try to get SlotID from self
        local slotID = focus.slotID
        if slotID == nil and focus.GetID then
            local ok, res = pcall(focus.GetID, focus)
            if ok then slotID = res end
        end
        
        -- Validate bagID (0-4 are main bags)
        if bagID and slotID and type(bagID) == "number" and bagID >= 0 and bagID <= 4 then
             local info = C_Container.GetContainerItemInfo(bagID, slotID)
             if info then
                 targetType, id = "item", info.itemID
             end
        end
    end

    -- 3. Inventory Item (Character Sheet)
    if not id and focus.GetID then
        local ok, slotID = pcall(focus.GetID, focus)
        if ok and type(slotID) == "number" and slotID >= 1 and slotID <= 23 then
             local itemID = GetInventoryItemID("player", slotID)
             if itemID then
                 targetType, id = "item", itemID
             end
        end
    end
    
    -- 4. Spellbook
    if not id and focus.spellBookItemSlotID and focus.spellBookItemSpellBank then
         local info = C_SpellBook.GetSpellBookItemInfo(focus.spellBookItemSlotID, focus.spellBookItemSpellBank)
         if info and info.spellID then
             targetType, id = "spell", info.spellID
         end
    end

    -- 5. Generic Properties (spellID, itemID)
    if not id then
        if focus.spellID then targetType, id = "spell", focus.spellID
        elseif focus.itemID then targetType, id = "item", focus.itemID end
    end
    
     -- 6. Cooldown Info (Blizzard Viewers)
    if not id and focus.cooldownInfo then
          id = focus.cooldownInfo.spellID or focus.cooldownInfo.overrideSpellID
          if id then targetType = "spell" end
    end
    
    -- 7. Children Search (for anonymous containers)
    if not id and focus.GetChildren then
        local children = {focus:GetChildren()}
        for _, child in ipairs(children) do
            if child:IsMouseOver() then
                if child.cooldownInfo then
                    id = child.cooldownInfo.spellID or child.cooldownInfo.overrideSpellID
                    if id then targetType = "spell"; break end
                end
            end
        end
    end

    -- Resolution and Name
    if id then
         if targetType == "item" then
             name = C_Item.GetItemNameByID(id) or "Item "..id
         else
             local info = C_Spell.GetSpellInfo(id)
             if info then name = info.name else name = "Spell "..id end
             if not targetType then targetType = "spell" end
         end
    end
    
    return id, name, targetType
end

function BlizzardAuraTracker:PickTarget()
    local id, name, targetType = self:GetTargetUnderMouse()
    
    if not id then
        print("|cff00ff00[BuffForge]|r No spell/item detected under mouse.")
        return
    end
    
    print("|cff00ff00[BuffForge Picker]|r Found: " .. name .. " (" .. id .. ") ["..targetType.."]")

    if targetType == "spell" then
        local trackerFrame = self:GetAuraFrame(id)
        if trackerFrame then
            print("   |cff00ff00[Technique Check]|r SUCCESS! Blizzard tracks this internally.")
        else
            print("   |cffaaaaaa[Standard]|r Blizzard does not track this internally.")
        end
    end
    
    if BuffForgeDB and BuffForgeDB.profile then
         local specIndex = GetSpecialization()
         local specID = specIndex and GetSpecializationInfo(specIndex) or 0
         local key = UnitName("player") .. "-" .. GetRealmName() .. "-" .. specID
         
         BuffForgeDB.profile[key] = BuffForgeDB.profile[key] or {}
         BuffForgeDB.profile[key][id] = {
            enabled = true, type = "icon", point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, size = 60, 
            alwaysShow = true, desaturate = true, showBorder = true, borderColor = {0, 1, 0, 1}, trackType = "hybrid",
         }
         
         if BuffForge and BuffForge.UpdateIcon then BuffForge:UpdateIcon(id) end
         print("   |cff00ff00+ Added to BuffForge (Test Mode)|r")
    end
end

SLASH_BUFFFORGEPICK1 = "/bfpick"
SlashCmdList["BUFFFORGEPICK"] = function() BlizzardAuraTracker:PickTarget() end
