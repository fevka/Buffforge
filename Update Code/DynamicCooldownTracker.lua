--[[
    DynamicCooldownTracker.lua
    
    This script implements "Smart Cooldown Tracking" for World of Warcraft.
    
    What makes it "Smart"?
    1. Event-Driven: Updates primarily on events (SPELL_UPDATE_COOLDOWN, SPELL_UPDATE_CHARGES) 
       rather than polling every frame, saving CPU.
    2. Dynamic Reduction: Automatically detects cooldown reductions (e.g., from talents/procs) 
       and resets instant resets (e.g., Preparation) by re-querying state immediately.
    3. Charge Awareness: Distinguishes between "On Cooldown" and "Recharging". 
       - If a spell has charges, it shows the recharge progress sweep even if the spell is usable.
       - Displays current charge count.
    
    Usage:
    local tracker = DynamicCooldownTracker:CreateTracker(parent, spellID)
]]

local addonName, addonTable = ...
local DynamicCooldownTracker = {}
_G.DynamicCooldownTracker = DynamicCooldownTracker

-- Modern API aliases
local GetTime = GetTime
local C_Spell = C_Spell

--[[
    Creates a frame that tracks the cooldown and charges of a specific spell.
]]
function DynamicCooldownTracker:CreateTracker(parent, spellID, size)
    size = size or 36

    -- Create the main button frame
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    
    -- Icon texture
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    local iconTexture = spellInfo and spellInfo.iconID or 134400 -- Default "question mark"
    
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetAllPoints()
    frame.icon:SetTexture(iconTexture)

    -- Cooldown Frame (swipe animation)
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()
    frame.cooldown:SetHideCountdownNumbers(true) -- Disable Blizzard's built-in countdown numbers to prevent overlap
    frame.cooldown:SetDrawEdge(false)
    
    -- Charge Count Text
    frame.count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    frame.count:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.count:SetJustifyH("RIGHT")

    frame.spellID = spellID

    --[[
        Update Logic:
        Handles both standard cooldowns and charge-based cooldowns.
    ]]
    frame.isForced = false

    function frame:ForceCooldown(enable)
        self.isForced = enable
        if not enable then
            self:UpdateCooldown()
        end
    end

    --[[
        Update Logic:
        Handles both standard cooldowns and charge-based cooldowns.
    ]]
    function frame:UpdateCooldown()
        if self.isForced then return end
        
        local spellID = self.spellID
        
        -- 1. Determine "Usability" (Standard Cooldown)
        local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
        local isOnCooldown = false
        
        if cooldownInfo then
            pcall(function() self.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration) end)
            
            local isGlobal = cooldownInfo.isOnGCD
            local durationActive = false
            
            -- Safe check for duration > 0 (Handling Secret Values)
            -- GetCooldownTimes returns milliseconds.
            local startMs, durMs = self.cooldown:GetCooldownTimes()
            pcall(function() 
                if durMs and durMs > 0 then 
                    durationActive = true 
                end 
            end)
            
            if durationActive and not isGlobal then
                isOnCooldown = true
            end
        end
        
        self.icon:SetDesaturated(isOnCooldown)

        -- 2. Handle Charges (Specific Logic)
        local chargeInfo = C_Spell.GetSpellCharges(spellID)
        
        if chargeInfo then
            -- Spell has charges
            local currentCharges = chargeInfo.currentCharges
            local maxCharges = chargeInfo.maxCharges
            local cooldownStart = chargeInfo.cooldownStartTime
            local cooldownDuration = chargeInfo.cooldownDuration
            
            -- Determine if we should show charges
            local showCharges = false
            -- Try to check if maxCharges > 1
            local success, isMultiStack = pcall(function() return maxCharges and maxCharges > 1 end)
            
            if success then
                showCharges = isMultiStack
            else
                -- If we couldn't check (secret value), default to showing it
                -- BETTER TO SHOW than to hide relevant info
                showCharges = true
            end

            if showCharges then
                 -- Try to set text
                 local textSuccess = pcall(function() self.count:SetText(currentCharges) end)
                 if not textSuccess then
                     self.count:SetText("")
                 end
            else
                 self.count:SetText("")
            end

            -- Update Swipe for Recharge
            pcall(function() self.cooldown:SetCooldown(cooldownStart, cooldownDuration) end)
            
            -- Re-evaluate Desaturation for Charges
            -- Default to FALSE (Colored/Usable) to prevent flickering if checking fails.
            -- We only Grey out if we are 100% sure we have 0 charges.
            local forceDesaturate = false
            
            pcall(function()
                if currentCharges and currentCharges == 0 then
                    forceDesaturate = true
                end
            end)
            
            self.icon:SetDesaturated(forceDesaturate)
        else
             -- Standard Spell (No charges)
             -- self.count:SetText("") -- Already handled if needed, but safe to clear
             if not self.count:GetText() == "" then self.count:SetText("") end
        end
    end

    -- Event Handling
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:RegisterEvent("SPELL_UPDATE_CHARGES")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    frame:SetScript("OnEvent", function(self, event, ...)
        -- We update on any of these events.
        -- SPELL_UPDATE_CHARGES handles charge consumption/regen cases.
        -- SPELL_UPDATE_COOLDOWN handles standard CDs and resets.
        self:UpdateCooldown()
    end)
    
    -- Initial update
    frame:UpdateCooldown()

    return frame
end

